class HealthImport < ApplicationRecord
  belongs_to :workout
  # raw artifact (screenshot / export) kept next to the parsed summary columns.
  has_one_attached :artifact
end
