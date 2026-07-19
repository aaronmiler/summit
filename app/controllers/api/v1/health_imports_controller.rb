module Api
  module V1
    # Apple Health / Fitness ingestion (Health Auto Export). Headless push, so it
    # authenticates by **Bearer token** (per-user `api_token`), not the session
    # cookie. Each workout in the payload materializes an off-script `Workout`
    # (per the decided direction: the import is primary, the session inferred).
    # The verbatim payload is stored on `raw` so nothing is lost to parsing.
    class HealthImportsController < BaseController
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_token!, only: :create
      before_action :require_current_user!, only: :setup

      # GET /api/v1/health_imports/setup -> the values to paste into Health Auto
      # Export for *this* user. The URL is built from the request host, so it's
      # correct whether you're on aaron-macbook.local now or the homelab later.
      def setup
        render json: {
          "url" => "#{request.base_url}/api/v1/health_imports",
          "header_key" => "Authorization",
          "header_value" => "Bearer #{current_user.api_token}"
        }
      end

      # POST /api/v1/health_imports
      # Body: { "data": { "workouts": [...], "metrics": [...] } } (HAE shape).
      def create
        body = JSON.parse(request.raw_post)
        workouts = Array(body.dig("data", "workouts"))
        items = workouts.map { |w| ingest_workout(w) }
        created = items.count { |i| i[:outcome] == :created }
        skipped = items.count { |i| i[:outcome] == :skipped } # already imported (dedupe)

        log_push(
          status: IntegrationEvent::OK,
          summary: "#{workouts.size} workout(s): #{created} created, #{skipped} skipped",
          metadata: { received: workouts.size, created: created, skipped: skipped, items: items }
        )

        render json: {
          workouts_received: workouts.size, created: created, skipped: skipped
        }, status: :created
      rescue JSON::ParserError => e
        log_push(status: "bad_request", summary: "invalid JSON", error: e.message)
        render json: { error: "invalid JSON" }, status: :bad_request
      end

      private

      def authenticate_token!
        @token_user = authenticate_with_http_token { |token, _| User.find_by(api_token: token) }
        return if @token_user

        log_push(status: "unauthorized", summary: "bad or missing token")
        head :unauthorized
      end

      # Record one row per inbound push so the integration is monitorable after
      # the fact — which sessions arrived and whether each was created or deduped.
      def log_push(status:, summary: nil, metadata: {}, error: nil)
        IntegrationEvent.record!(
          kind: "health.push", source: "health_auto_export", direction: "inbound",
          user: @token_user, status: status, summary: summary, metadata: metadata,
          error: error, remote_ip: request.remote_ip
        )
      end

      # One workout -> a HealthImport + the Workout it materializes. Idempotent on
      # (user, external_id) so HAE re-sending overlapping windows is a no-op.
      # Returns a per-item detail hash (its `outcome` drives the push counts).
      def ingest_workout(workout)
        external_id = workout["id"].presence
        detail = { name: workout["name"], start: workout["start"], external_id: external_id }
        return detail.merge(outcome: :skipped) if external_id && @token_user.health_imports.exists?(external_id: external_id)

        started = parse_time(workout["start"]) || Time.current
        # Imports are historical: always finished, so they never become the
        # *active* workout.
        finished = parse_time(workout["end"]) || started

        import = @token_user.health_imports.create!(
          source: "health_auto_export",
          external_id: external_id,
          activity_type: workout["name"],
          recorded_at: started,
          duration_seconds: workout["duration"]&.to_i,
          calories: qty(workout["activeEnergyBurned"])&.round,
          distance: qty(workout["distance"]),
          avg_hr: (qty(workout["avgHeartRate"]) || workout.dig("heartRate", "avg", "qty"))&.round,
          raw: workout
        )
        workout_record = @token_user.workouts.create!(
          routine_id: nil, started_at: started, finished_at: finished, notes: import.summary
        )
        import.update!(workout: workout_record)
        # Boundary 1: an inbound activity joins (or opens) the training session it
        # falls in — the warmup + the routine + the watch strength become one.
        TrainingSession.absorb(workout_record)
        detail.merge(outcome: :created)
      rescue ActiveRecord::RecordNotUnique
        detail.merge(outcome: :skipped) # lost a race on the dedupe index
      end

      # HAE quantities are { "qty": Number, "units": "..." }; pull the number.
      def qty(value)
        value["qty"] if value.is_a?(Hash)
      end

      # HAE stamps timestamps like "2026-07-15T09:12:00 Z" (note the space).
      def parse_time(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
