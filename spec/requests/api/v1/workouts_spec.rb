require "rails_helper"

# The live logging loop: start a workout, log sets into it, finish. Pins the
# derived-state the model turns on — active workout, last-used prefill, and
# progression-phase advancement — end to end over the session cookie.
RSpec.describe "Api::V1::Workouts", type: :request do
  let!(:aaron) { create(:user, name: "Aaron") }
  let(:row) { create(:exercise, name: "Barbell Row", modality: "barbell", muscle_group: "Back") }
  let(:routine) { create(:routine, name: "Pull") }
  let!(:slot) { create(:routine_exercise, routine:, exercise: row, position: 0, target: "4 × 8") }

  def sign_in(user) = post("/api/v1/session", params: { user_id: user.id })

  describe "GET /api/v1/workouts/current" do
    it "is unauthorized with no user picked" do
      get "/api/v1/workouts/current"
      expect(response).to have_http_status(:unauthorized)
    end

    it "is null before a workout starts" do
      sign_in(aaron)
      get "/api/v1/workouts/current"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_nil
    end
  end

  describe "starting and logging" do
    before { sign_in(aaron) }

    it "starts a workout and returns the routine's slots" do
      post "/api/v1/workouts", params: { routine_id: routine.id }

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["routine"]).to eq("id" => routine.id, "name" => "Pull")
      expect(body["slots"].sole).to include("id" => slot.id, "target" => "4 × 8")
      expect(body["slots"].sole["exercise"]).to include("name" => "Barbell Row")
    end

    it "does not orphan a second workout (double-start returns the live one)" do
      post "/api/v1/workouts", params: { routine_id: routine.id }
      first_id = response.parsed_body["id"]
      post "/api/v1/workouts", params: { routine_id: routine.id }

      expect(response.parsed_body["id"]).to eq(first_id)
      expect(aaron.workouts.count).to eq(1)
    end

    it "logs sets into the active workout, auto-numbering per exercise" do
      post "/api/v1/workouts", params: { routine_id: routine.id }
      workout_id = response.parsed_body["id"]

      post "/api/v1/workouts/#{workout_id}/set_logs", params: { exercise_id: row.id, routine_exercise_id: slot.id, reps: 8, weight: 135 }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("set_number" => 1, "reps" => 8, "weight" => 135.0)

      post "/api/v1/workouts/#{workout_id}/set_logs", params: { exercise_id: row.id, routine_exercise_id: slot.id, reps: 8, weight: 135 }
      expect(response.parsed_body["set_number"]).to eq(2)

      get "/api/v1/workouts/current"
      expect(response.parsed_body["slots"].sole["sets"].size).to eq(2)
    end

    it "prefills the next workout from the last-used set" do
      post "/api/v1/workouts", params: { routine_id: routine.id }
      w1 = response.parsed_body["id"]
      post "/api/v1/workouts/#{w1}/set_logs", params: { exercise_id: row.id, routine_exercise_id: slot.id, reps: 8, weight: 145 }
      patch "/api/v1/workouts/#{w1}", params: { finished_at: Time.current.iso8601 }

      post "/api/v1/workouts", params: { routine_id: routine.id }
      expect(response.parsed_body["slots"].sole["prefill"]).to include("reps" => 8, "weight" => 145.0)
    end

    it "clears current when the workout is finished" do
      post "/api/v1/workouts", params: { routine_id: routine.id }
      workout_id = response.parsed_body["id"]

      patch "/api/v1/workouts/#{workout_id}", params: { finished_at: Time.current.iso8601 }
      expect(response).to have_http_status(:ok)

      get "/api/v1/workouts/current"
      expect(response.parsed_body).to be_nil
    end
  end

  describe "progression slots" do
    let(:progression) { create(:progression, name: "Pull-ups") }
    let(:scap) { create(:exercise, name: "Scapular Pull-up", modality: "bodyweight") }
    let(:full) { create(:exercise, name: "Pull-up", modality: "bodyweight") }
    let!(:phase0) { create(:progression_phase, progression:, exercise: scap, position: 0) }
    let!(:phase1) { create(:progression_phase, progression:, exercise: full, position: 1) }
    let!(:prog_slot) { create(:routine_exercise, :progression_slot, routine:, progression:, position: 1) }

    before { sign_in(aaron) }

    it "derives the current phase, and logging a higher phase advances it" do
      post "/api/v1/workouts", params: { routine_id: routine.id }
      workout_id = response.parsed_body["id"]
      slot_payload = response.parsed_body["slots"].find { |s| s["progression"] }

      # Never logged -> current phase is the first (position 0).
      expect(slot_payload["progression"]["current_phase_position"]).to eq(0)
      expect(slot_payload["progression"]["phases"].map { |p| p["id"] }).to eq([phase0.id, phase1.id])

      # Log against phase 1 -> advancement is just the Log, no state row.
      post "/api/v1/workouts/#{workout_id}/set_logs",
        params: { exercise_id: full.id, routine_exercise_id: prog_slot.id, progression_phase_id: phase1.id, reps: 5 }
      patch "/api/v1/workouts/#{workout_id}", params: { finished_at: Time.current.iso8601 }

      post "/api/v1/workouts", params: { routine_id: routine.id }
      next_slot = response.parsed_body["slots"].find { |s| s["progression"] }
      expect(next_slot["progression"]["current_phase_position"]).to eq(1)
    end
  end

  describe "GET /api/v1/workouts (history)" do
    before { sign_in(aaron) }

    it "lists this user's finished workouts, newest first, with set counts" do
      old = create(:workout, user: aaron, routine:, started_at: 3.days.ago, finished_at: 3.days.ago)
      recent = create(:workout, user: aaron, routine:, started_at: 1.hour.ago, finished_at: 30.minutes.ago)
      create(:set_log, workout: recent, exercise: row, set_number: 1)
      create(:set_log, workout: recent, exercise: row, set_number: 2)

      get "/api/v1/workouts"

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.map { |w| w["id"] }
      expect(ids).to eq([recent.id, old.id]) # newest first
      expect(response.parsed_body.first).to include(
        "id" => recent.id, "set_count" => 2, "routine" => { "id" => routine.id, "name" => "Pull" },
      )
    end

    it "excludes the active (unfinished) workout and other users' workouts" do
      create(:workout, user: aaron, routine:, started_at: 1.hour.ago, finished_at: nil) # active
      create(:workout, user: create(:user, name: "Bree"), routine:, started_at: 1.hour.ago, finished_at: 1.hour.ago)

      get "/api/v1/workouts"
      expect(response.parsed_body).to be_empty
    end
  end

  describe "GET /api/v1/workouts/:id (detail)" do
    before { sign_in(aaron) }

    it "groups the logged sets by exercise, off the Log" do
      curl = create(:exercise, name: "Curl", modality: "dumbbell")
      workout = create(:workout, user: aaron, routine:, started_at: 1.hour.ago, finished_at: 30.minutes.ago)
      create(:set_log, workout:, exercise: row, set_number: 1, reps: 8, weight: 135)
      create(:set_log, workout:, exercise: row, set_number: 2, reps: 6, weight: 145)
      create(:set_log, workout:, exercise: curl, set_number: 1, reps: 10, weight: 25)

      get "/api/v1/workouts/#{workout.id}"

      expect(response).to have_http_status(:ok)
      groups = response.parsed_body["exercises"]
      expect(groups.map { |g| g["exercise"]["name"] }).to eq(["Barbell Row", "Curl"])
      expect(groups.first["sets"].map { |s| s["set_number"] }).to eq([1, 2])
      expect(groups.first["sets"].first).to include("reps" => 8, "weight" => 135.0)
    end

    it "won't show another user's workout (scoped to the picked user)" do
      others = create(:workout, user: create(:user, name: "Bree"), routine:, started_at: 1.hour.ago, finished_at: 1.hour.ago)
      get "/api/v1/workouts/#{others.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/set_logs/:id" do
    before { sign_in(aaron) }

    it "removes a mislogged set" do
      post "/api/v1/workouts", params: { routine_id: routine.id }
      workout_id = response.parsed_body["id"]
      post "/api/v1/workouts/#{workout_id}/set_logs", params: { exercise_id: row.id, routine_exercise_id: slot.id, reps: 8 }
      set_id = response.parsed_body["id"]

      delete "/api/v1/set_logs/#{set_id}"
      expect(response).to have_http_status(:no_content)

      get "/api/v1/workouts/current"
      expect(response.parsed_body["slots"].sole["sets"]).to be_empty
    end
  end
end
