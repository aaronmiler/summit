require "rails_helper"

RSpec.describe "Api::V1::Health", type: :request do
  describe "GET /api/v1/health" do
    it "returns ok with the build version" do
      get "/api/v1/health"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("status" => "ok", "version" => "dev")
    end

    it "reports BUILD_SHA as the version when set" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("BUILD_SHA", "dev").and_return("abc123")

      get "/api/v1/health"

      expect(response.parsed_body["version"]).to eq("abc123")
    end
  end
end
