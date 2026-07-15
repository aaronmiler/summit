class Routine < ApplicationRecord
  has_many :routine_exercises, -> { order(:position) }, dependent: :destroy
  has_many :workouts, dependent: :nullify

  validates :name, presence: true
end
