class User < ApplicationRecord
  has_many :workouts, dependent: :destroy
  has_many :meals, dependent: :destroy
  has_many :health_imports, dependent: :destroy

  # Bearer token for headless ingestion (Apple Health push) — no session cookie.
  # Generated on create; existing users were backfilled in the migration.
  has_secure_token :api_token

  validates :name, presence: true

  # Current routine is emergent, not stored: the routine on the most recent workout.
  def current_routine
    workouts.order(started_at: :desc).first&.routine
  end

  # The active workout is the most recent unfinished one (nil if none). This is
  # how the app knows a session is in progress — no `active` flag.
  def active_workout
    workouts.in_progress.order(started_at: :desc).first
  end

  # Last-used prefill: this user's most recent logged set for an exercise, across
  # any workout. Personalized loads fall out of history, not per-user prescription.
  def last_set_for(exercise)
    SetLog.joins(:workout)
      .where(workouts: { user_id: id }, exercise_id: exercise.id)
      .order("set_logs.created_at DESC")
      .first
  end
end
