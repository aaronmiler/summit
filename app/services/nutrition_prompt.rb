# The proven napkin-nutrition prompt — the `checklist` totals-mode style that won
# the eval (script/nutrition_eval/prompts.rb; verdict in docs/nutrition_parsing.md).
#
# Load-bearing choices, don't re-litigate without new eval data:
# - Totals mode: each item's calories/macros are the TOTAL for its portion, not
#   per-unit. Per-unit was tested and tanked real-meal accuracy (63% vs 87%).
# - Enumerated-imperative checklist (this 9B ignores prose judgment rules).
# - Anti-flatten rule + a component few-shot (else it collapses a listed dish
#   into one low-anchored blob).
# - Portion (amount + unit) is a first-class output so the total is rescalable.
module NutritionPrompt
  SCHEMA = <<~S.strip
    Return ONLY a JSON object of exactly this shape, nothing else:
    {"items":[{"name":"string","amount":number,"unit":"string","calories":number,"protein":number,"carbs":number,"fat":number,"confidence":number,"parse_notes":"string"}]}
    - amount + unit are the PORTION you assumed: amount is a number, unit is a short word (e.g. 2 "slice", 300 "g", 1 "cup", 4 "oz", 1 "serving").
    - calories/protein/carbs/fat are the TOTAL for that portion (protein/carbs/fat in GRAMS, calories in kcal; numbers only).
    - confidence is 0.0-1.0: how sure you are of that item's macros.
    - parse_notes: any other assumption, under 12 words.
    - If the text names no food or drink, return {"items":[]}.
  S

  SYSTEM = <<~P.strip
    You are a nutrition estimator for a food-logging app. Follow every step:
    1. Split the meal into distinct food/drink items, one object per item. If the description lists components (e.g. "sub: roll, salami, provolone"), make ONE item per listed component — do NOT collapse a named dish into a single item.
    2. For each item set amount + unit to the portion — use the stated amount, else assume a typical serving.
    3. Estimate calories, protein, carbs, fat for that exact portion.
    4. For named brands/restaurant items, use their known values.
    5. Set confidence lower (<=0.5) when the portion or item is vague.
    6. Put any other assumption in parse_notes.
    7. If the text names no food or drink, output {"items":[]}.
    #{SCHEMA}
    Output JSON only. No prose, no markdown fences.
  P

  # Few-shot: per-item portion, decomposition of a listed-component dish
  # (anti-flatten), and empty-on-non-food.
  FEWSHOT = [
    { role: "user", content: "2 slices of whole wheat toast with peanut butter" },
    { role: "assistant", content: '{"items":[{"name":"whole wheat toast","amount":2,"unit":"slice","calories":140,"protein":6,"carbs":24,"fat":2,"confidence":0.8,"parse_notes":"standard slices"},{"name":"peanut butter","amount":2,"unit":"tbsp","calories":190,"protein":8,"carbs":6,"fat":16,"confidence":0.6,"parse_notes":"assumed 2 tbsp"}]}' },
    { role: "user", content: "turkey club: 3 slices bread, turkey, bacon, lettuce, tomato, mayo" },
    { role: "assistant", content: '{"items":[{"name":"bread","amount":3,"unit":"slice","calories":210,"protein":9,"carbs":39,"fat":3,"confidence":0.7,"parse_notes":"3 sandwich slices"},{"name":"turkey","amount":4,"unit":"oz","calories":150,"protein":30,"carbs":1,"fat":3,"confidence":0.6,"parse_notes":"deli turkey"},{"name":"bacon","amount":3,"unit":"strip","calories":130,"protein":9,"carbs":0,"fat":10,"confidence":0.7,"parse_notes":"3 strips"},{"name":"mayo","amount":1,"unit":"tbsp","calories":90,"protein":0,"carbs":0,"fat":10,"confidence":0.6,"parse_notes":"assumed 1 tbsp"},{"name":"lettuce & tomato","amount":1,"unit":"serving","calories":15,"protein":1,"carbs":3,"fat":0,"confidence":0.7,"parse_notes":"garnish"}]}' },
    { role: "user", content: "took the dog for a walk" },
    { role: "assistant", content: '{"items":[]}' }
  ].freeze

  # Full message list for one totals-mode parse of `raw_text`.
  def self.messages(raw_text)
    [ { role: "system", content: SYSTEM }, *FEWSHOT, { role: "user", content: raw_text } ]
  end

  # Single-item estimate: macros for ONE named item at a stated portion. Used when
  # a user adds an item the parse missed and asks the model to fill it in. Pointed
  # (one known item, no decomposition), so the two-pass accuracy caveat that sank
  # whole-meal decomposition doesn't apply. Totals mode, same output shape.
  ITEM_SYSTEM = <<~P.strip
    You estimate the nutrition for exactly ONE food or drink item at a stated portion. Follow every step:
    1. Estimate calories, protein, carbs, fat for that exact portion (TOTALS for the whole portion, not per-unit).
    2. For named brands/restaurant items, use their known values.
    3. Set confidence lower (<=0.5) when the item or portion is vague.
    4. Do NOT add any other foods. One item only.
    Return ONLY a JSON object of exactly this shape:
    {"calories":number,"protein":number,"carbs":number,"fat":number,"confidence":number,"parse_notes":"string"}
    protein/carbs/fat in GRAMS, calories in kcal, numbers only; confidence 0.0-1.0; parse_notes under 12 words.
    Output JSON only. No prose, no markdown fences.
  P

  def self.item_messages(name, amount, unit)
    portion = [ amount, unit ].compact.join(" ").strip
    user = portion.empty? ? name.to_s : "#{name} (#{portion})"
    [ { role: "system", content: ITEM_SYSTEM }, { role: "user", content: user } ]
  end
end
