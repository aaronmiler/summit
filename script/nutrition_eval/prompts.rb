# Prompt text for the nutrition eval. Kept separate so wording is easy to tune
# between runs. Three single-shot styles (minimal / prose / checklist) plus the
# two decompose+estimate prompts used by the two-pass strategy.
#
# Checklist style is deliberately enumerated-imperative: Delta's router notes the
# same 9B "ignores prose judgment rules" on meeting_tasks and needs a checklist —
# we test whether that holds for nutrition here.
#
# Portion is a FIRST-CLASS output (amount + unit), not prose: portion is the
# dominant error term in nutrition estimation and the one lever a user corrects,
# so it must be a structured, rescalable value. Forcing per-item amount/unit also
# discourages the "flatten a named dish into one blob" failure seen on complex meals.
module NutritionEval
  module Prompts
    SCHEMA = <<~S.strip
      Return ONLY a JSON object of exactly this shape, nothing else:
      {"items":[{"name":"string","amount":number,"unit":"string","calories":number,"protein":number,"carbs":number,"fat":number,"confidence":number,"parse_notes":"string"}]}
      - amount + unit are the PORTION you assumed: amount is a number, unit is a short word (e.g. 2 "slice", 300 "g", 1 "cup", 4 "oz", 1 "serving").
      - protein/carbs/fat are GRAMS; calories are kcal; numbers only (no units inside the number values).
      - confidence is 0.0-1.0: how sure you are of that item's macros.
      - parse_notes: any other assumption, under 12 words.
      - If the text names no food or drink, return {"items":[]}.
    S

    # Few-shot pairs shared by prose + checklist styles: teaches per-item portion,
    # decomposition of a listed-component dish (anti-flatten), and empty-on-non-food.
    FEWSHOT = [
      { role: "user", content: "2 slices of whole wheat toast with peanut butter" },
      { role: "assistant", content: '{"items":[{"name":"whole wheat toast","amount":2,"unit":"slice","calories":140,"protein":6,"carbs":24,"fat":2,"confidence":0.8,"parse_notes":"standard slices"},{"name":"peanut butter","amount":2,"unit":"tbsp","calories":190,"protein":8,"carbs":6,"fat":16,"confidence":0.6,"parse_notes":"assumed 2 tbsp"}]}' },
      { role: "user", content: "turkey club: 3 slices bread, turkey, bacon, lettuce, tomato, mayo" },
      { role: "assistant", content: '{"items":[{"name":"bread","amount":3,"unit":"slice","calories":210,"protein":9,"carbs":39,"fat":3,"confidence":0.7,"parse_notes":"3 sandwich slices"},{"name":"turkey","amount":4,"unit":"oz","calories":150,"protein":30,"carbs":1,"fat":3,"confidence":0.6,"parse_notes":"deli turkey"},{"name":"bacon","amount":3,"unit":"strip","calories":130,"protein":9,"carbs":0,"fat":10,"confidence":0.7,"parse_notes":"3 strips"},{"name":"mayo","amount":1,"unit":"tbsp","calories":90,"protein":0,"carbs":0,"fat":10,"confidence":0.6,"parse_notes":"assumed 1 tbsp"},{"name":"lettuce & tomato","amount":1,"unit":"serving","calories":15,"protein":1,"carbs":3,"fat":0,"confidence":0.7,"parse_notes":"garnish"}]}' },
      { role: "user", content: "took the dog for a walk" },
      { role: "assistant", content: '{"items":[]}' }
    ].freeze

    # Per-unit few-shot: macros are for ONE unit; the app multiplies by amount.
    # The pizza example directly drills the failure mode (amount=3, per-slice macros).
    FEWSHOT_PERUNIT = [
      { role: "user", content: "2 slices of whole wheat toast with peanut butter" },
      { role: "assistant", content: '{"items":[{"name":"whole wheat toast","amount":2,"unit":"slice","calories":70,"protein":3,"carbs":12,"fat":1,"confidence":0.8,"parse_notes":"per slice"},{"name":"peanut butter","amount":2,"unit":"tbsp","calories":95,"protein":4,"carbs":3,"fat":8,"confidence":0.6,"parse_notes":"per tbsp"}]}' },
      { role: "user", content: "3 slices of cheese pizza" },
      { role: "assistant", content: '{"items":[{"name":"cheese pizza","amount":3,"unit":"slice","calories":285,"protein":12,"carbs":36,"fat":10,"confidence":0.6,"parse_notes":"per slice"}]}' },
      { role: "user", content: "took the dog for a walk" },
      { role: "assistant", content: '{"items":[]}' }
    ].freeze

    SINGLE = {
      min: <<~P.strip,
        You are a nutrition estimator. Estimate macros for the meal description.
        #{SCHEMA}
        Output JSON only. No prose, no markdown fences.
      P

      prose: <<~P.strip,
        You are a careful nutrition estimator for a food-logging app. Read the meal
        description and estimate its macros. Break a composite meal into its distinct
        foods — if the text lists components, give one item per component rather than
        one lumped dish. For each item state the portion you assumed as amount + unit.
        Use well-known values for named brands and restaurant items. Lower your
        confidence when the portion or preparation is vague. This is a napkin
        estimate — reasonable ballpark figures, not lab-precise.
        #{SCHEMA}
        Output JSON only. No prose, no markdown fences.
      P

      checklist: <<~P.strip,
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

      # Per-unit variant: the model estimates macros for ONE unit and the app
      # multiplies by amount. Moves the unreliable multiply-by-quantity step out of
      # the 9B (which captures amount but forgets to scale calories) into code.
      checklist_perunit: <<~P.strip
        You are a nutrition estimator for a food-logging app. Follow every step:
        1. Split the meal into distinct food/drink items, one object per item. If the description lists components (e.g. "sub: roll, salami, provolone"), make ONE item per listed component — do NOT collapse a named dish into a single item.
        2. For each item set amount + unit: amount is the quantity from the text (else a typical count like 1), unit is what one unit is (slice, oz, cup, egg, serving...).
        3. Estimate calories, protein, carbs, fat for ONE single unit — NOT the whole amount. The app multiplies by amount, so never pre-multiply.
        4. For named brands/restaurant items, use their known per-unit values.
        5. Set confidence lower (<=0.5) when the item is vague.
        6. Put any other assumption in parse_notes.
        7. If the text names no food or drink, output {"items":[]}.
        Return ONLY: {"items":[{"name":"string","amount":number,"unit":"string","calories":number,"protein":number,"carbs":number,"fat":number,"confidence":number,"parse_notes":"string"}]}
        calories/protein/carbs/fat are PER ONE unit (grams for macros, kcal for calories). confidence 0.0-1.0.
        Output JSON only. No prose, no markdown fences.
      P
    }.freeze

    # ---- Two-pass strategy prompts ----
    DECOMPOSE = <<~P.strip
      You split a meal description into its distinct food and drink components.
      Follow every step:
      1. List each distinct food or drink as one component.
      2. Give the portion — the stated amount, else a typical serving.
      3. Do NOT estimate calories or macros here. Components only.
      4. If the text names no food or drink, return {"components":[]}.
      Return ONLY this JSON: {"components":[{"name":"string","portion":"string"}]}
      Output JSON only. No prose, no markdown fences.
    P

    # Filled per component by the two-pass strategy.
    def self.estimate_item(name, portion)
      <<~P.strip
        Estimate the nutrition for exactly this one item. Do not add other foods.
        Item: #{name}
        Portion: #{portion}
        Give a napkin estimate (reasonable ballpark). Use known values for brands.
        Return ONLY this JSON: {"name":"string","amount":number,"unit":"string","calories":number,"protein":number,"carbs":number,"fat":number,"confidence":number,"parse_notes":"string"}
        amount + unit are the portion; protein/carbs/fat in grams; calories in kcal; confidence 0.0-1.0.
        Output JSON only. No prose, no markdown fences.
      P
    end
  end
end
