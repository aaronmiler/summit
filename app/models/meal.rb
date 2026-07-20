class Meal < ApplicationRecord
  belongs_to :user
  has_many :food_entries, dependent: :destroy

  validates :raw_text, presence: true

  # Parse status is derived, not stored — it's the status of this meal's most
  # recent nutrition-parse IntegrationEvent (see MealParser). "pending" means
  # never parsed (or the job hasn't landed yet); a meal is valid without it.
  def parse_status = last_parse_event&.status || "pending"
  def parsed_at = last_parse_event&.created_at

  private

  def last_parse_event
    @last_parse_event ||= IntegrationEvent.of_kind(MealParser::KIND)
      .where("metadata->>'meal_id' = ?", id.to_s).recent.first
  end
end
