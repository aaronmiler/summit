require "rails_helper"

# Index-only: the list that backs the routine editor's slot picker. Just id +
# name — enough to pick a progression to drop into a routine.
RSpec.describe "Api::V1::Progressions", type: :request do
  describe "GET /api/v1/progressions" do
    it "lists progressions ordered by name" do
      create(:progression, name: "Pull-ups")
      create(:progression, name: "Dips")

      get "/api/v1/progressions"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |p| p["name"] }).to eq(%w[Dips Pull-ups])
      expect(response.parsed_body.first.keys).to contain_exactly("id", "name")
    end
  end
end
