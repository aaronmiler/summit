class CreateTrainingSessions < ActiveRecord::Migration[8.1]
  def change
    # Groups a day's Log events — the routine `Workout` plus any health-import
    # workouts (warmup cardio, watch strength) — into one training session.
    # Membership is *assigned at the write boundary* (import ingest / routine
    # finish) off recorded times, not recomputed on every read, so it's stable.
    # It's a stored row rather than a derived query because the grouping is a
    # decision (and, later, a manually merged one) that isn't re-derivable — the
    # same reason `HealthImport.workout_id` is stored at ingest.
    create_table :training_sessions do |t|
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    # Nullify (not cascade): dropping a session must never delete the Log events
    # inside it. An orphaned workout just falls back to a standalone History row.
    add_reference :workouts, :training_session, null: true, foreign_key: { on_delete: :nullify }
  end
end
