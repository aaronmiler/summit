class FoodEntry < ApplicationRecord
  belongs_to :meal

  validates :name, presence: true

  MACROS = %i[protein carbs fat].freeze

  # Correct a portion by rescaling its stored totals linearly — the human owns the
  # portion; we do NOT re-ask the model (docs/nutrition_parsing.md § decided
  # approach). Pure arithmetic: new_total = total × (new_amount / old_amount).
  # With no positive prior amount there's nothing to scale from, so only `amount`
  # is set.
  def rescale_to!(new_amount)
    old = amount.to_f
    if old.positive? && new_amount.positive?
      factor = new_amount / old
      self.calories = (calories * factor).round if calories
      MACROS.each { |m| self[m] = (self[m] * factor).round(2) if self[m] }
    end
    self.amount = new_amount
    save!
  end

  def as_entry_json
    as_json(only: %i[id name amount unit calories protein carbs fat confidence parse_notes])
  end
end
