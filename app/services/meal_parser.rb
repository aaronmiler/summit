# Turns a Meal's freeform `raw_text` into structured FoodEntry rows via one
# totals-mode LLM call (the approach settled in docs/nutrition_parsing.md).
#
# `raw_text` is the truth and is never touched; the entries are derived and
# replaceable — re-parsing a meal drops its prior entries and rebuilds them. The
# exchange is logged as an `llm.nutrition_parse` IntegrationEvent so parse status
# is a query over the audit log (no status column on Meal).
class MealParser < ApplicationService
  KIND = "llm.nutrition_parse".freeze

  # Model pointer lives in ENV so it can be repointed without a deploy; the eval
  # winner is the default.
  def self.model = ENV.fetch("SUMMIT_NUTRITION_MODEL", "local-primary")

  def initialize(meal)
    @meal = meal
  end

  # Returns the meal's new FoodEntry rows (possibly empty for non-food text).
  def call
    t0 = Time.now
    content = LitellmClient.chat(NutritionPrompt.messages(@meal.raw_text), model: self.class.model)
    duration_ms = ((Time.now - t0) * 1000).round

    parsed = LitellmClient.extract_json(content)
    items = coerce_items(parsed)

    if items.nil?
      record(status: "parse_error", summary: "unparseable model output",
             duration_ms: duration_ms, metadata: { raw: content.to_s[0, 500] })
      return []
    end

    entries = replace_entries(items)
    record(status: IntegrationEvent::OK, summary: "#{entries.size} item(s)",
           duration_ms: duration_ms, metadata: { item_count: entries.size })
    entries
  rescue LitellmClient::Error, StandardError => e
    record(status: "error", summary: e.message, error: e.message)
    raise
  end

  private

  # Swap the meal's derived entries atomically — old ones go, new ones land.
  def replace_entries(items)
    @meal.transaction do
      @meal.food_entries.destroy_all
      items.map { |attrs| @meal.food_entries.create!(attrs) }
    end
  end

  # Coerce the model's parsed JSON into FoodEntry attribute hashes. Accepts the
  # {items:[...]} shape (or a bare array); returns nil only when the shape is
  # unrecognizable, [] for legitimately-empty (non-food) parses.
  def coerce_items(parsed)
    list =
      if parsed.is_a?(Hash) && parsed["items"].is_a?(Array) then parsed["items"]
      elsif parsed.is_a?(Array) then parsed
      end
    return nil if list.nil?

    list.filter_map { |it| entry_attrs(it) }
  end

  def entry_attrs(item)
    return nil unless item.is_a?(Hash)
    name = item["name"].to_s.strip
    return nil if name.empty?

    {
      name: name,
      amount: num(item["amount"]),
      unit: item["unit"].to_s.presence,
      calories: num(item["calories"])&.round,
      protein: num(item["protein"]),
      carbs: num(item["carbs"]),
      fat: num(item["fat"]),
      confidence: num(item["confidence"]),
      parse_notes: item["parse_notes"].to_s.presence
    }
  end

  # Lenient number coercion — tolerates "12g" style strays from the model.
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
      user: @meal.user, status: status, summary: summary,
      metadata: metadata.merge(meal_id: @meal.id, model: self.class.model),
      duration_ms: duration_ms, error: error
    )
  end
end
