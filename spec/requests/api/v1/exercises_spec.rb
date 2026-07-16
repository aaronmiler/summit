require "rails_helper"

# The read-only movement library. Ordered by (muscle_group, name) so the browser
# can group with a simple fold; modality rides along (it drives the future
# logging widget).
RSpec.describe "Api::V1::Exercises", type: :request do
  describe "GET /api/v1/exercises" do
    it "lists exercises ordered by muscle group then name" do
      create(:exercise, name: "Zercher Squat", muscle_group: "Legs")
      create(:exercise, name: "Dumbbell Row", muscle_group: "Back", modality: "dumbbell")
      create(:exercise, name: "Pull-up", muscle_group: "Back", modality: "bodyweight")

      get "/api/v1/exercises"

      expect(response).to have_http_status(:ok)
      names = response.parsed_body.map { |e| e["name"] }
      expect(names).to eq(["Dumbbell Row", "Pull-up", "Zercher Squat"])
      expect(response.parsed_body.first).to eq(
        "id" => Exercise.find_by(name: "Dumbbell Row").id,
        "name" => "Dumbbell Row",
        "modality" => "dumbbell",
        "muscle_group" => "Back",
      )
    end
  end
end
