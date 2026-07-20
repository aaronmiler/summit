# Napkin-nutrition eval dataset. Reference macro *bands* (not exact values) —
# "napkin" means ballpark, so a case passes when totals land inside the band a
# reasonable human estimator would accept. Bands authored by the capable model
# (Claude) as ground truth. Grams for macros, kcal for calories.
#
# expect keys:
#   items      Range   acceptable # of decomposed food items
#   calories   Range   acceptable TOTAL kcal across items
#   protein/carbs/fat  Range   acceptable TOTAL grams
#   conf       :high|:med|:low   expected confidence direction
#   adversarial  true    non-food/garbage: correct answer is items == []
#   soft         true    too-vague: empty OR low-confidence guess both OK
module NutritionEval
  CASES = [
    # ---- T1: single food ----
    { id: "t1_banana", tier: 1, text: "a medium banana",
      expect: { items: 1..1, calories: 90..125, protein: 0.5..2.0, carbs: 23..32, fat: 0.0..0.8, conf: :high } },
    { id: "t1_eggs", tier: 1, text: "2 large eggs scrambled in a little butter",
      expect: { items: 1..2, calories: 175..265, protein: 11..16, carbs: 0..4, fat: 13..22, conf: :high } },
    { id: "t1_coffee", tier: 1, text: "16 oz black coffee",
      expect: { items: 1..1, calories: 0..12, protein: 0..1, carbs: 0..3, fat: 0.0..0.5, conf: :high } },

    # ---- T2: everyday composed ----
    { id: "t2_sandwich", tier: 2, text: "turkey sandwich on wheat with mayo, a handful of chips, and an apple",
      expect: { items: 3..4, calories: 520..780, protein: 22..40, carbs: 60..90, fat: 18..38, conf: :med } },
    { id: "t2_oatmeal", tier: 2, text: "bowl of oatmeal with blueberries and a drizzle of honey",
      expect: { items: 1..3, calories: 240..390, protein: 6..12, carbs: 44..68, fat: 3..9, conf: :med } },
    { id: "t2_chickenrice", tier: 2, text: "grilled chicken breast, cup of white rice, steamed broccoli",
      expect: { items: 3..3, calories: 390..560, protein: 38..56, carbs: 42..62, fat: 5..15, conf: :med } },

    # ---- T3: vague quantity ----
    { id: "t3_almonds", tier: 3, text: "a handful of almonds",
      expect: { items: 1..1, calories: 125..220, protein: 4..8, carbs: 4..9, fat: 10..19, conf: :low } },
    { id: "t3_spaghetti", tier: 3, text: "big plate of spaghetti with marinara",
      expect: { items: 1..2, calories: 480..820, protein: 14..26, carbs: 85..145, fat: 7..22, conf: :low } },
    # "some" is genuinely 1-3 slices — band spans the reasonable readings.
    { id: "t3_pizza", tier: 3, text: "some leftover pizza",
      expect: { items: 1..1, calories: 270..820, protein: 12..40, carbs: 32..92, fat: 10..38, conf: :low } },

    # ---- T4: restaurant / brand ----
    { id: "t4_chipotle", tier: 4, text: "Chipotle chicken burrito bowl with rice, black beans, cheese, and salsa",
      expect: { items: 1..6, calories: 580..880, protein: 38..58, carbs: 58..88, fat: 18..36, conf: :med } },
    { id: "t4_bigmac", tier: 4, text: "Big Mac and a medium fries",
      expect: { items: 2..2, calories: 870..1120, protein: 25..37, carbs: 92..122, fat: 42..60, conf: :med } },
    { id: "t4_latte", tier: 4, text: "grande oat milk latte from Starbucks",
      expect: { items: 1..1, calories: 170..290, protein: 5..13, carbs: 24..40, fat: 5..13, conf: :med } },

    # ---- T5: compound / tricky ----
    { id: "t5_shake", tier: 5, text: "protein shake: 2 scoops whey, a banana, a spoon of peanut butter, oat milk",
      expect: { items: 3..4, calories: 430..640, protein: 44..62, carbs: 42..68, fat: 11..24, conf: :med } },
    { id: "t5_brunch", tier: 5, text: "PNW brunch — smoked salmon bagel with cream cheese, side of hashbrowns, oat milk latte",
      expect: { items: 3..4, calories: 680..1020, protein: 24..42, carbs: 88..132, fat: 24..46, conf: :med } },
    { id: "t5_stirfry", tier: 5, text: "beef stir fry with veggies over rice, homemade",
      expect: { items: 1..4, calories: 480..780, protein: 28..46, carbs: 52..84, fat: 14..32, conf: :low } },

    # ---- T6: adversarial ----
    { id: "t6_garbage", tier: 6, text: "asdf jkl; random keyboard mash",
      expect: { items: 0..0, adversarial: true } },
    { id: "t6_nonfood", tier: 6, text: "went for a 5 mile run this morning",
      expect: { items: 0..0, adversarial: true } },
    { id: "t6_snacked", tier: 6, text: "idk just snacked on random stuff all day",
      expect: { items: 0..3, conf: :low, soft: true } },

    # ---- T7: component-heavy / compound plated meals ----
    # The stress test: one "dish" that is really many sub-components. Does single-shot
    # decompose deeply enough AND keep the summed totals in band (vs. two-pass, which
    # tends to inflate when it estimates each part in isolation)?
    { id: "c7_italian_sub", tier: 7, text: "Italian sub: hoagie roll, salami, capicola, provolone, lettuce, tomato, onion, oil and vinegar",
      expect: { items: 5..9, calories: 780..1120, protein: 36..62, carbs: 44..78, fat: 44..74, conf: :med } },
    # No stated portion → restaurant carbonara honestly spans ~700-1300 kcal by pasta amount.
    { id: "c7_carbonara", tier: 7, text: "spaghetti carbonara — pasta, pancetta, eggs, parmesan, black pepper",
      expect: { items: 2..5, calories: 660..1300, protein: 28..60, carbs: 66..150, fat: 26..70, conf: :med } },
    { id: "c7_short_ribs", tier: 7, text: "red wine braised short ribs with mashed potatoes and roasted asparagus",
      expect: { items: 3..6, calories: 760..1220, protein: 38..66, carbs: 38..72, fat: 42..80, conf: :med } },
    { id: "c7_poke", tier: 7, text: "poke bowl: sushi rice, ahi tuna, edamame, avocado, cucumber, seaweed salad, spicy mayo, sesame",
      expect: { items: 5..9, calories: 600..980, protein: 32..58, carbs: 60..94, fat: 20..46, conf: :med } },
    { id: "c7_big_breakfast", tier: 7, text: "full breakfast plate: 2 fried eggs, 3 strips bacon, 2 sausage links, hash browns, and 2 pancakes with syrup and butter",
      expect: { items: 5..9, calories: 1120..1680, protein: 38..64, carbs: 100..160, fat: 60..98, conf: :med } }
  ].freeze
end
