class SetLog < ApplicationRecord
  belongs_to :workout
  belongs_to :exercise
  belongs_to :routine_exercise, optional: true
  belongs_to :progression_phase, optional: true

  validates :set_number, presence: true
end
