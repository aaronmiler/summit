class Workout < ApplicationRecord
  belongs_to :user
  belongs_to :routine, optional: true # off-script / ad-hoc workouts have no routine
  has_many :set_logs, dependent: :destroy
  has_many :health_imports, dependent: :destroy

  validates :started_at, presence: true

  # "In progress" is derived, not a stored flag: a workout is active until it's
  # finished. The user's active workout is their most recent unfinished one.
  scope :in_progress, -> { where(finished_at: nil) }

  def finished?
    finished_at.present?
  end
end
