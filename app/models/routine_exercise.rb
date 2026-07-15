class RoutineExercise < ApplicationRecord
  belongs_to :routine
  # exercise XOR progression — exactly one, enforced below and by a DB check constraint.
  belongs_to :exercise, optional: true
  belongs_to :progression, optional: true

  validates :position, presence: true
  validate :exactly_one_target

  private

  def exactly_one_target
    return if exercise.present? ^ progression.present?

    errors.add(:base, "must reference exactly one of exercise or progression")
  end
end
