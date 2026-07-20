class Routine < ApplicationRecord
  belongs_to :program, optional: true # ungrouped routines are fine (Today "Other").
  has_many :routine_exercises, -> { order(:position) }, dependent: :destroy
  has_many :workouts, dependent: :nullify

  # The hand editor writes the whole slot list in one PATCH: new slots (no id),
  # edits/swaps/reorders (id + changed fields), removals (id + _destroy). Removing
  # a logged slot nullifies the SetLog breadcrumb via the FK — actuals are safe.
  accepts_nested_attributes_for :routine_exercises, allow_destroy: true

  validates :name, presence: true
end
