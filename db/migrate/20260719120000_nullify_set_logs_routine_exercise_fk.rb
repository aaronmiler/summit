class NullifySetLogsRoutineExerciseFk < ActiveRecord::Migration[8.1]
  def change
    # A SetLog's `routine_exercise_id` is *nullable context* — a breadcrumb to the
    # routine slot it was logged against, not the source of truth for what was
    # done (that's `exercise_id`, NOT NULL, denormalized onto the set). So editing
    # a routine must be able to remove a slot even after it's been logged against:
    # nullify the breadcrumb, leave the actuals (exercise/reps/weight) untouched.
    # The default FK was restrict, which blocked that. See docs/data_model.md #6.
    remove_foreign_key :set_logs, :routine_exercises
    add_foreign_key :set_logs, :routine_exercises, on_delete: :nullify
  end
end
