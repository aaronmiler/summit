class User < ApplicationRecord
  has_many :workouts, dependent: :destroy
  has_many :meals, dependent: :destroy

  validates :name, presence: true

  # Current routine is emergent, not stored: the routine on the most recent workout.
  def current_routine
    workouts.order(started_at: :desc).first&.routine
  end
end
