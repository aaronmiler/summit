require "rails_helper"

# Read-only monitoring feed over the integration audit log. Session-authed, shows
# all events (both users + user-less system/unauth rows).
RSpec.describe "Api::V1::IntegrationEvents", type: :request do
  let!(:aaron) { create(:user, name: "Aaron") }

  it "needs a picked user (session)" do
    get "/api/v1/integration_events"
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns events newest first, including user-less rows" do
    create(:integration_event, kind: "health.push", status: "ok", user: aaron,
                               summary: "1 workout: 1 created", created_at: 2.hours.ago)
    create(:integration_event, kind: "health.push", status: "unauthorized", user: nil,
                               summary: "bad or missing token", created_at: 1.minute.ago)

    post "/api/v1/session", params: { user_id: aaron.id } # become Aaron for the cookie API
    get "/api/v1/integration_events"

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body.size).to eq(2)
    expect(body.first).to include("status" => "unauthorized", "user" => nil)
    expect(body.last).to include("status" => "ok", "user" => "Aaron", "summary" => "1 workout: 1 created")
  end
end
