class AddPortionToFoodEntries < ActiveRecord::Migration[8.1]
  def change
    # Portion is a first-class, correctable value: `amount` units of `unit`
    # ("3 slice", "1 cup"). Macros stay stored totals; amount/unit exist so a
    # human can rescale the total in code (× new/old) without an LLM round-trip.
    # See docs/nutrition_parsing.md.
    add_column :food_entries, :amount, :decimal, precision: 6, scale: 2
    add_column :food_entries, :unit, :string
  end
end
