class Workout < ApplicationRecord
  belongs_to :user
  belongs_to :routine, optional: true # off-script / ad-hoc workouts have no routine
  has_many :set_logs, dependent: :destroy
  has_many :health_imports, dependent: :destroy

  validates :started_at, presence: true
end
