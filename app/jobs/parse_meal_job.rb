# Parse a meal's raw_text into FoodEntry rows in the background. Enqueued when a
# meal is logged (auto) or on an explicit re-parse. A meal is valid and viewable
# before this lands; entries fill in when it does.
class ParseMealJob < ApplicationJob
  queue_as :default

  def perform(meal_id)
    meal = Meal.find_by(id: meal_id)
    return unless meal # deleted before the job ran

    MealParser.call(meal)
  end
end
