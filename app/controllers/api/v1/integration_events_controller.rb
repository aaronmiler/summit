module Api
  module V1
    # Read-only monitoring feed for the integration audit log — every inbound
    # push and (later) outbound LLM call, newest first. Session-authed like the
    # rest of the cookie API, but *not* user-scoped: it shows all events (both
    # users + system/unauth rows) so failures with no user still surface.
    class IntegrationEventsController < BaseController
      before_action :require_current_user!

      # GET /api/v1/integration_events -> the last 100 events, newest first.
      def index
        events = IntegrationEvent.includes(:user).recent.limit(100)
        render json: events.map { |e|
          {
            "id" => e.id,
            "kind" => e.kind,
            "source" => e.source,
            "direction" => e.direction,
            "status" => e.status,
            "summary" => e.summary,
            "metadata" => e.metadata,
            "duration_ms" => e.duration_ms,
            "error" => e.error,
            "user" => e.user&.name,
            "created_at" => e.created_at
          }
        }
      end
    end
  end
end
