require "rails_helper"

# The user-editable movement library. Ordered by (muscle_group, name) so the
# browser can group with a simple fold; modality rides along (it drives the
# logging widget). Renames are safe; deletion is guarded by restrict FKs.
RSpec.describe "Api::V1::Exercises", type: :request do
  describe "GET /api/v1/exercises" do
    it "lists exercises ordered by muscle group then name" do
      create(:exercise, name: "Zercher Squat", muscle_group: "Legs")
      create(:exercise, name: "Dumbbell Row", muscle_group: "Back", modality: "dumbbell")
      create(:exercise, name: "Pull-up", muscle_group: "Back", modality: "bodyweight")

      get "/api/v1/exercises"

      expect(response).to have_http_status(:ok)
      names = response.parsed_body.map { |e| e["name"] }
      expect(names).to eq([ "Dumbbell Row", "Pull-up", "Zercher Squat" ])
      expect(response.parsed_body.first).to eq(
        "id" => Exercise.find_by(name: "Dumbbell Row").id,
        "name" => "Dumbbell Row",
        "modality" => "dumbbell",
        "muscle_group" => "Back",
      )
    end
  end

  describe "POST /api/v1/exercises" do
    it "creates a movement" do
      expect {
        post "/api/v1/exercises", params: {
          name: "Barbell Row", modality: "barbell", muscle_group: "Back"
        }, as: :json
      }.to change(Exercise, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("name" => "Barbell Row", "modality" => "barbell")
    end

    it "rejects a duplicate name with 422" do
      create(:exercise, name: "Barbell Row")

      post "/api/v1/exercises", params: { name: "Barbell Row", modality: "barbell" }, as: :json

      expect(response).to have_http_status(422)
      expect(response.parsed_body["errors"].join).to match(/name/i)
    end
  end

  describe "PATCH /api/v1/exercises/:id" do
    it "renames a movement (safe even with logged sets — FK is by id)" do
      set_log = create(:set_log)
      exercise = set_log.exercise

      patch "/api/v1/exercises/#{exercise.id}", params: { name: "Renamed Movement" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(exercise.reload.name).to eq("Renamed Movement")
      expect(set_log.reload.exercise).to eq(exercise)
    end
  end

  describe "DELETE /api/v1/exercises/:id" do
    it "deletes an unreferenced movement" do
      exercise = create(:exercise)

      expect {
        delete "/api/v1/exercises/#{exercise.id}"
      }.to change(Exercise, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "refuses to delete a movement with logged sets (422, not 500)" do
      exercise = create(:set_log).exercise

      expect {
        delete "/api/v1/exercises/#{exercise.id}"
      }.not_to change(Exercise, :count)

      expect(response).to have_http_status(422)
      expect(response.parsed_body["error"]).to match(/can't be deleted/i)
    end

    it "refuses to delete a movement used by a routine slot" do
      exercise = create(:routine_exercise).exercise

      delete "/api/v1/exercises/#{exercise.id}"

      expect(response).to have_http_status(422)
    end
  end
end
