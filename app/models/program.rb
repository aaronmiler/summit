class Program < ApplicationRecord
  # A named grouping of routines ("Winter Strength", "Climbing Base"). Deleting a
  # program never deletes its routines — the FK nullifies, so they fall back to
  # ungrouped. No "current program" column: like current routine, it's derived
  # from the Log (the program of your most recent workout's routine).
  has_many :routines, dependent: :nullify

  validates :name, presence: true
end
