class Progression < ApplicationRecord
  has_many :progression_phases, -> { order(:position) }, dependent: :destroy
  has_many :routine_exercises, dependent: :restrict_with_exception

  validates :name, presence: true

  # Current phase is derived, not stored: the phase of this user's most recent
  # logged set against this progression. Falls back to the first phase if the
  # user has never logged one. Same pattern as last-used weight.
  def current_phase_for(user)
    logged = progression_phases
      .joins(set_logs: :workout)
      .where(workouts: { user_id: user.id })
      .order("set_logs.created_at DESC")
      .first
    logged || progression_phases.first
  end
end
