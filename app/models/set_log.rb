class SetLog < ApplicationRecord
  belongs_to :workout
  belongs_to :exercise
  belongs_to :routine_exercise, optional: true
  belongs_to :progression_phase, optional: true

  validates :set_number, presence: true

  # The API shape for a logged set. Lives here because both the workout payload
  # and the set-log create response render it. Decimals -> numbers so the widget
  # gets clean values.
  def as_log_json
    {
      "id" => id,
      "set_number" => set_number,
      "exercise_id" => exercise_id,
      "routine_exercise_id" => routine_exercise_id,
      "progression_phase_id" => progression_phase_id,
      "reps" => reps,
      "weight" => weight&.to_f,
      "duration_seconds" => duration_seconds,
      "rpe" => rpe&.to_f,
      "notes" => notes
    }
  end
end
