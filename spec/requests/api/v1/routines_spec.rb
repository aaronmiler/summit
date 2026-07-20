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

    it "includes each routine's program (id + name), or null when ungrouped" do
      program = create(:program, name: "Winter Strength")
      create(:routine, name: "Pull/Core", program:)
      create(:routine, name: "Zone 2 Cardio")

      get "/api/v1/routines"

      by_name = response.parsed_body.index_by { |r| r["name"] }
      expect(by_name["Pull/Core"]["program"]).to eq("id" => program.id, "name" => "Winter Strength")
      expect(by_name["Zone 2 Cardio"]["program"]).to be_nil
    end
  end

  describe "program assignment" do
    it "assigns and clears a routine's program via program_id" do
      program = create(:program, name: "Winter Strength")
      routine = create(:routine, name: "Pull/Core")

      patch "/api/v1/routines/#{routine.id}", params: { program_id: program.id }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["program"]).to eq("id" => program.id, "name" => "Winter Strength")
      expect(routine.reload.program_id).to eq(program.id)

      patch "/api/v1/routines/#{routine.id}", params: { program_id: nil }, as: :json
      expect(routine.reload.program_id).to be_nil
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

  describe "POST /api/v1/routines" do
    it "creates a routine with inline exercise slots, returning the nested shape" do
      row = create(:exercise, name: "Barbell Row")
      curl = create(:exercise, name: "Barbell Curl")

      expect {
        post "/api/v1/routines", params: {
          name: "Pull/Core", notes: "Flat back.", tags: %w[pull],
          preferred_frequency: "2×/week",
          routine_exercises_attributes: [
            { exercise_id: row.id, position: 0, target: "4 × 8", rest_seconds: 120 },
            { exercise_id: curl.id, position: 1, target: "3 × 12" }
          ]
        }, as: :json
      }.to change(Routine, :count).by(1).and change(RoutineExercise, :count).by(2)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body).to include("name" => "Pull/Core", "tags" => %w[pull])
      names = body["routine_exercises"].map { |s| s.dig("exercise", "name") }
      expect(names).to eq(%w[Barbell\ Row Barbell\ Curl])
    end
  end

  describe "PATCH /api/v1/routines/:id" do
    it "swaps a slot's exercise in place, adds a slot, and removes another" do
      routine = create(:routine, name: "Pull/Core")
      row = create(:exercise, name: "Barbell Row")
      curl = create(:exercise, name: "Barbell Curl")
      pushup = create(:exercise, name: "Push-up")
      keep = create(:routine_exercise, routine:, exercise: row, position: 0, target: "4 × 8")
      drop = create(:routine_exercise, routine:, exercise: curl, position: 1)

      patch "/api/v1/routines/#{routine.id}", params: {
        name: "Pull/Core",
        routine_exercises_attributes: [
          # swap the kept slot's movement (id preserved, exercise_id changes)
          { id: keep.id, exercise_id: pushup.id, progression_id: nil, position: 0 },
          # remove the other slot
          { id: drop.id, _destroy: true },
          # add a brand-new slot
          { exercise_id: curl.id, position: 1, target: "3 × 12" }
        ]
      }, as: :json

      expect(response).to have_http_status(:ok)
      slots = response.parsed_body["routine_exercises"]
      expect(slots.map { |s| s.dig("exercise", "name") }).to eq(%w[Push-up Barbell\ Curl])
      expect(keep.reload.exercise).to eq(pushup)
      expect(RoutineExercise.exists?(drop.id)).to be(false)
    end

    it "swaps a slot from an exercise to a progression" do
      routine = create(:routine)
      row = create(:exercise, name: "Barbell Row")
      prog = create(:progression, name: "Pull-ups")
      slot = create(:routine_exercise, routine:, exercise: row, position: 0)

      patch "/api/v1/routines/#{routine.id}", params: {
        routine_exercises_attributes: [
          { id: slot.id, exercise_id: nil, progression_id: prog.id, position: 0 }
        ]
      }, as: :json

      expect(response).to have_http_status(:ok)
      slot.reload
      expect(slot.exercise).to be_nil
      expect(slot.progression).to eq(prog)
    end
  end

  describe "DELETE /api/v1/routines/:id" do
    it "deletes the routine and its slots" do
      routine = create(:routine)
      create(:routine_exercise, routine:)

      expect {
        delete "/api/v1/routines/#{routine.id}"
      }.to change(Routine, :count).by(-1).and change(RoutineExercise, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
