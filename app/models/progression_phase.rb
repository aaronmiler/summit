class ProgressionPhase < ApplicationRecord
  belongs_to :progression
  belongs_to :exercise
  has_many :set_logs, dependent: :nullify

  validates :position, presence: true, uniqueness: { scope: :progression_id }
end
