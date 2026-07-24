require "rails_helper"

# Apple Health push (Health Auto Export). Headless Bearer-token auth; each
# workout materializes an off-script Workout and is idempotent on its HealthKit id.
RSpec.describe "Api::V1::HealthImports", type: :request do
  let!(:aaron) { create(:user, name: "Aaron") }

  # A trimmed Health Auto Export payload (the real shape, one workout).
  def payload(id: "ABC-123")
    {
      data: {
        workouts: [
          {
            id: id,
            name: "Outdoor Walk",
            start: "2026-07-15T09:12:00 Z",
            end: "2026-07-15T09:45:00 Z",
            duration: 1980,
            activeEnergyBurned: { qty: 233, units: "kcal" },
            totalEnergy: { qty: 261, units: "kcal" },
            distance: { qty: 1.95, units: "mi" },
            avgHeartRate: { qty: 118, units: "bpm" },
            maxHeartRate: { qty: 142, units: "bpm" }
          }
        ],
        metrics: []
      }
    }
  end

  def post_import(body, token:)
    post "/api/v1/health_imports",
      params: body.to_json,
      headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  it "rejects a missing or bad token" do
    post "/api/v1/health_imports", params: payload.to_json, headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:unauthorized)

    post_import(payload, token: "nope")
    expect(response).to have_http_status(:unauthorized)
  end

  describe "integration event logging" do
    it "records one event per push, capturing per-workout outcomes" do
      expect { post_import(payload(id: "E1"), token: aaron.api_token) }
        .to change { IntegrationEvent.count }.by(1)

      event = IntegrationEvent.last
      expect(event).to have_attributes(kind: "health.push", status: "ok", user: aaron, direction: "inbound")
      expect(event.metadata).to include("received" => 1, "created" => 1, "skipped" => 0)
      expect(event.metadata["items"].first).to include("name" => "Outdoor Walk", "outcome" => "created")
    end

    it "fingerprints the (un-ingested) metrics stream so we can size it later" do
      body = payload(id: "M1")
      body[:data][:metrics] = [
        { name: "resting_heart_rate", units: "bpm", data: [] },
        { name: "heart_rate_variability", units: "ms", data: [] },
      ]
      post_import(body, token: aaron.api_token)

      expect(IntegrationEvent.last.metadata["metrics"]).to include(
        "count" => 2, "names" => %w[resting_heart_rate heart_rate_variability],
      )
    end

    it "logs an unauthorized push (no user)" do
      expect { post_import(payload, token: "nope") }.to change { IntegrationEvent.count }.by(1)
      expect(IntegrationEvent.last).to have_attributes(status: "unauthorized", user: nil)
    end

    it "logs a malformed-JSON push" do
      post "/api/v1/health_imports",
        params: "{not json",
        headers: { "Authorization" => "Bearer #{aaron.api_token}", "Content-Type" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(IntegrationEvent.last).to have_attributes(kind: "health.push", status: "bad_request", user: aaron)
    end
  end

  it "materializes a workout from a pushed session" do
    expect {
      post_import(payload, token: aaron.api_token)
    }.to change { aaron.health_imports.count }.by(1).and change { aaron.workouts.count }.by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include("workouts_received" => 1, "created" => 1, "skipped" => 0)

    import = aaron.health_imports.last
    expect(import).to have_attributes(
      source: "health_auto_export", external_id: "ABC-123",
      activity_type: "Outdoor Walk", calories: 233, total_calories: 261, avg_hr: 118, max_hr: 142,
    )
    expect(import.distance).to eq(1.95)
    expect(import.raw["name"]).to eq("Outdoor Walk") # verbatim payload kept

    workout = import.workout
    expect(workout).to be_present
    expect(workout.finished?).to be true # historical, never the active workout
    expect(workout.notes).to eq("Outdoor Walk · 1.95 mi · 233 cal")
  end

  it "is idempotent on the HealthKit id (re-sends are no-ops)" do
    post_import(payload(id: "SAME"), token: aaron.api_token)
    expect {
      post_import(payload(id: "SAME"), token: aaron.api_token)
    }.not_to change { aaron.workouts.count }

    expect(response.parsed_body).to include("created" => 0, "skipped" => 1)
  end

  it "the materialized workout shows up in history" do
    post_import(payload, token: aaron.api_token)

    post "/api/v1/session", params: { user_id: aaron.id } # become Aaron for the cookie API
    get "/api/v1/workouts"
    expect(response.parsed_body.size).to eq(1)
    expect(response.parsed_body.first["routine"]).to be_nil # off-script
  end

  describe "GET /api/v1/health_imports/setup" do
    it "needs a picked user (session), not the token" do
      get "/api/v1/health_imports/setup"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns this user's ingest URL and auth header" do
      post "/api/v1/session", params: { user_id: aaron.id }
      get "/api/v1/health_imports/setup"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "url" => end_with("/api/v1/health_imports"),
        "header_key" => "Authorization",
        "header_value" => "Bearer #{aaron.api_token}",
      )
    end
  end
end
