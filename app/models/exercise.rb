class Exercise < ApplicationRecord
  # modality is load-bearing: it drives the logging widget and which fields a set has.
  enum :modality, {
    barbell: "barbell",
    dumbbell: "dumbbell",
    machine: "machine",
    bodyweight: "bodyweight",
    band: "band",
    hangboard: "hangboard",
    cardio: "cardio",
    climbing: "climbing"
  }

  has_many :routine_exercises, dependent: :restrict_with_exception
  has_many :progression_phases, dependent: :restrict_with_exception
  has_many :set_logs, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
  validates :modality, presence: true
end
