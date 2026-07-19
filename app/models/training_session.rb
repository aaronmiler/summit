class TrainingSession < ApplicationRecord
  belongs_to :user
  # Nullify, not destroy: the Log is immutable — losing a session must not take
  # its workouts with it.
  has_many :workouts, dependent: :nullify

  # Single-linkage gap. A Log event joins a session while it sits within this of
  # the session's span, so a broken-up day (bike → snack → bike) still chains as
  # long as no single break exceeds it. 1h is deliberately conservative — wider
  # merges are a manual action (later), not a looser threshold.
  GAP = 1.hour

  # Place `workout` in a session. Called at the write boundary — health-import
  # ingest and routine finish — never on read. Joins the user's session holding
  # the nearest neighbor within GAP of this workout's recorded window; otherwise
  # opens a new one. Idempotent: safe to re-run (backfill), and it drops a
  # session it leaves empty by moving the workout out.
  def self.absorb(workout)
    previous = workout.training_session
    finish = workout.finished_at || workout.started_at

    # A sibling Log event of the same user whose window touches this one within
    # GAP. Two intervals are within GAP when each starts before the other's
    # (padded) end. Earliest neighbor wins, so a workout bridging two sessions
    # joins the older — merging the pair is a manual concern, not handled here.
    neighbor = workout.user.workouts
      .where.not(id: workout.id)
      .where.not(training_session_id: nil)
      .where("started_at <= ? AND COALESCE(finished_at, started_at) >= ?",
             finish + GAP, workout.started_at - GAP)
      .order(:started_at)
      .first

    session = neighbor&.training_session || create!(user_id: workout.user_id)
    workout.update!(training_session: session)
    previous.destroy if previous && previous != session && !previous.workouts.exists?
    session
  end
end
