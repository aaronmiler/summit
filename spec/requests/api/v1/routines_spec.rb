require "rails_helper"

# The read-only routine library. `show` nests the ordered slots, each of which
# references an exercise XOR a progression (see data_model.md) — this spec pins
# that both branches serialize correctly.
RSpec.describe "Api::V1::Routines", type: :request do
  describe "GET /api/v1/routines" do
    it "lists routines (no slots) ordered by name" do
      create(:routine, name: "Zone 2 Cardio")
      create(:routine, name: "Pull/Core", tags: %w[pull core], preferred_frequency: "2×/week")

      get "/api/v1/routines"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |r| r["name"] }).to eq([ "Pull/Core", "Zone 2 Cardio" ])
      expect(response.parsed_body.first).to include(
        "name" => "Pull/Core",
        "tags" => %w[pull core],
        "preferred_frequency" => "2×/week",
      )
      expect(response.parsed_body.first).not_to have_key("routine_exercises")
    end
  end

  describe "GET /api/v1/routines/:id" do
    it "nests slots in position order, resolving the exercise branch" do
      routine = create(:routine, name: "Pull/Core")
      row = create(:exercise, name: "Dumbbell Row", modality: "dumbbell", muscle_group: "Back")
      create(:routine_exercise, routine:, exercise: row, position: 0,
                                target: "4 × 8", rest_seconds: 120, notes: "Flat back.")

      get "/api/v1/routines/#{routine.id}"

      expect(response).to have_http_status(:ok)
      slot = response.parsed_body.fetch("routine_exercises").sole
      expect(slot).to include(
        "position" => 0,
        "target" => "4 × 8",
        "rest_seconds" => 120,
        "notes" => "Flat back.",
        "progression" => nil,
      )
      expect(slot["exercise"]).to eq(
        "id" => row.id, "name" => "Dumbbell Row",
        "modality" => "dumbbell", "muscle_group" => "Back",
      )
    end

    it "resolves the progression branch with its phase ladder" do
      routine = create(:routine)
      progression = create(:progression, name: "Pull-ups")
      scap = create(:exercise, name: "Scapular Pull-up", modality: "bodyweight")
      create(:progression_phase, progression:, exercise: scap, position: 0,
                                 target: "3 × 8", graduation_criteria: "3 × 8 clean")
      create(:routine_exercise, :progression_slot, routine:, progression:, position: 0)

      get "/api/v1/routines/#{routine.id}"

      slot = response.parsed_body.fetch("routine_exercises").sole
      expect(slot["exercise"]).to be_nil
      expect(slot["progression"]).to include("id" => progression.id, "name" => "Pull-ups")
      expect(slot["progression"]["phases"].sole).to eq(
        "position" => 0, "target" => "3 × 8",
        "graduation_criteria" => "3 × 8 clean", "exercise_name" => "Scapular Pull-up",
      )
    end
  end
end
