class AddMealTypeToMeals < ActiveRecord::Migration[8.1]
  def change
    # An optional human override for the meal-type chip. NULL means "auto" — the
    # type derives from the meal's time (see Meal::MEAL_TYPES / frontend
    # mealMath). Stored only when you tap to correct a late/early log.
    add_column :meals, :meal_type, :string
  end
end
