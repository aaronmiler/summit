class HealthImport < ApplicationRecord
  belongs_to :user
  # Optional: a health import can stand alone (a pushed Apple Health session) or
  # attach to the Workout it materialized.
  belongs_to :workout, optional: true
  # raw artifact (screenshot) kept next to the parsed summary columns; `raw`
  # holds the verbatim export payload (lossless — parse off it).
  has_one_attached :artifact

  # Dedupe key for pushed events (HealthKit UUID); re-sends are no-ops.
  validates :external_id, uniqueness: { scope: :user_id }, allow_nil: true
end
