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

  # One-line summary used as the materialized workout's notes (activity ·
  # distance · calories). Built off the parsed columns so ingest and any
  # backfill produce it identically. Distance is decimal(6,2)-clean already;
  # its units aren't a column, so read them off `raw`, defaulting to miles.
  def summary
    bits = [ activity_type ]
    bits << "#{distance.to_f} #{distance_units}" if distance
    bits << "#{calories} cal" if calories
    bits.compact.join(" · ")
  end

  private

  def distance_units
    (raw.is_a?(Hash) && raw.dig("distance", "units")) || "mi"
  end
end
