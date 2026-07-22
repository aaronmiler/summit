# Fills in the macros for a single FoodEntry via one pointed LLM call — used when
# a user adds an item the meal parse missed (or wants a fresh estimate for one).
# The human owns name/amount/unit; only the macros (calories/protein/carbs/fat +
# confidence/parse_notes) come from the model, keeping the "macros are the LLM's
# job, portion is the human's" split from docs/nutrition_parsing.md.
#
# Synchronous by design: this is a foreground "estimate this one" action, unlike
# the async on-log meal parse.
class FoodEntryEstimator < ApplicationService
  KIND = "llm.nutrition_estimate".freeze

  def self.model = MealParser.model

  # `known_calories`: the human's measured calorie total. When given, the model fills
  # only the macro split and we keep this number instead of the model's calories.
  def initialize(entry, known_calories: nil)
    @entry = entry
    @known_calories = known_calories
  end

  # Returns the updated entry (macros filled), or the entry untouched on a parse
  # miss. Raises on client failure (surfaced to the caller/UI).
  def call
    t0 = Time.now
    content = LitellmClient.chat(
      NutritionPrompt.item_messages(@entry.name, @entry.amount, @entry.unit, known_calories: @known_calories),
      model: self.class.model
    )
    duration_ms = ((Time.now - t0) * 1000).round

    macros = LitellmClient.extract_json(content)
    unless macros.is_a?(Hash)
      record(status: "parse_error", summary: "unparseable model output",
             duration_ms: duration_ms, metadata: { raw: content.to_s[0, 500] })
      return @entry
    end

    @entry.update!(
      calories: @known_calories&.round || num(macros["calories"])&.round,
      protein: num(macros["protein"]),
      carbs: num(macros["carbs"]),
      fat: num(macros["fat"]),
      confidence: num(macros["confidence"]),
      parse_notes: macros["parse_notes"].to_s.presence
    )
    record(status: IntegrationEvent::OK, summary: @entry.name, duration_ms: duration_ms)
    @entry
  rescue LitellmClient::Error, StandardError => e
    record(status: "error", summary: e.message, error: e.message)
    raise
  end

  private

  def num(value)
    return nil if value.nil? || value == ""

    Float(value)
  rescue ArgumentError, TypeError
    s = value.to_s[/-?\d+(\.\d+)?/]
    s&.to_f
  end

  def record(status:, summary: nil, metadata: {}, duration_ms: nil, error: nil)
    IntegrationEvent.record!(
      kind: KIND, source: "litellm", direction: "outbound",
      user: @entry.meal.user, status: status, summary: summary,
      metadata: metadata.merge(meal_id: @entry.meal_id, food_entry_id: @entry.id, model: self.class.model),
      duration_ms: duration_ms, error: error
    )
  end
end
