require "rails_helper"

# Proves the load-bearing decisions in docs/data_model.md hold at the DB/model
# layer: the exercise-XOR-progression slot, derived per-user state (no state
# tables), and log integrity via a restrict FK.
RSpec.describe "Summit data model" do
  describe "RoutineExercise: exercise XOR progression" do
    it "accepts a plain exercise slot" do
      expect(build(:routine_exercise)).to be_valid
    end

    it "accepts a progression slot" do
      expect(build(:routine_exercise, :progression_slot)).to be_valid
    end

    it "rejects both at the model layer" do
      re = build(:routine_exercise, :progression_slot, exercise: build(:exercise))
      expect(re).not_to be_valid
    end

    it "rejects neither at the model layer" do
      expect(build(:routine_exercise, exercise: nil)).not_to be_valid
    end

    it "rejects both at the DB layer (check constraint)" do
      routine = create(:routine)
      ex = create(:exercise)
      prog = create(:progression)
      expect {
        ActiveRecord::Base.connection.execute(<<~SQL)
          INSERT INTO routine_exercises (routine_id, exercise_id, progression_id, position, created_at, updated_at)
          VALUES (#{routine.id}, #{ex.id}, #{prog.id}, 1, now(), now())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid, /check constraint/)
    end
  end

  describe "derived per-user state (no state tables)" do
    it "User#current_routine is the routine on the most recent workout" do
      user = create(:user)
      pull = create(:routine, name: "Pull/Core")
      boulder = create(:routine, name: "Bouldering")
      create(:workout, user: user, routine: pull, started_at: 2.days.ago)
      create(:workout, user: user, routine: boulder, started_at: 1.hour.ago)

      expect(user.current_routine).to eq(boulder)
    end

    it "is per-user: two users derive different current routines from one shared library" do
      her = create(:user)
      him = create(:user)
      boulder = create(:routine, name: "Bouldering")
      pull = create(:routine, name: "Pull/Core")
      create(:workout, user: her, routine: boulder, started_at: 1.hour.ago)
      create(:workout, user: him, routine: pull, started_at: 1.hour.ago)

      expect(her.current_routine).to eq(boulder)
      expect(him.current_routine).to eq(pull)
    end

    it "Progression#current_phase_for derives from the last logged set, else phase 1" do
      user = create(:user)
      prog = create(:progression, name: "Pull-ups")
      scap = create(:progression_phase, progression: prog, position: 0)
      negatives = create(:progression_phase, progression: prog, position: 1)

      # never logged -> first phase
      expect(prog.current_phase_for(user)).to eq(scap)

      workout = create(:workout, user: user)
      create(:set_log, workout: workout, exercise: negatives.exercise,
                       progression_phase: negatives)

      expect(prog.current_phase_for(user)).to eq(negatives)
    end
  end

  describe "log integrity" do
    it "blocks hard-deleting an exercise that has logged sets (restrict FK)" do
      set_log = create(:set_log)
      expect { set_log.exercise.destroy }
        .to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end
end
