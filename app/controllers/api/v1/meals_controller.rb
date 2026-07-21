module Api
  module V1
    # Napkin nutrition: log a meal as freeform text, then let the LLM derive its
    # per-item macros in the background (ParseMealJob → MealParser). The text is
    # the truth; entries are derived and fill in when the parse lands, so a meal is
    # useful immediately. Scoped to the picked user — meals are per-user Log events.
    class MealsController < BaseController
      before_action :require_current_user!

      # GET /api/v1/meals — the picked user's meals, newest first (the log).
      def index
        meals = current_user.meals.includes(:food_entries).order(created_at: :desc)
        render json: meals.map { |m| meal_json(m) }
      end

      # POST /api/v1/meals — log the text and kick off an async parse.
      def create
        meal = current_user.meals.new(meal_params)
        if meal.save
          ParseMealJob.perform_later(meal.id)
          render json: meal_json(meal), status: :created
        else
          render json: { errors: meal.errors.full_messages }, status: 422
        end
      end

      # GET /api/v1/meals/:id — the meal, its entries, and derived parse status.
      def show
        render json: meal_json(find_meal)
      end

      # PATCH /api/v1/meals/:id — correct the meal. Editing the text re-parses
      # (the entries are derived from it); editing notes/eaten_at does not.
      def update
        meal = find_meal
        reparse = meal_params.key?(:raw_text) && meal_params[:raw_text] != meal.raw_text
        if meal.update(meal_params)
          ParseMealJob.perform_later(meal.id) if reparse
          render json: meal_json(meal)
        else
          render json: { errors: meal.errors.full_messages }, status: 422
        end
      end

      # POST /api/v1/meals/:id/parse — explicit re-parse (replaces prior entries).
      def parse
        meal = find_meal
        ParseMealJob.perform_later(meal.id)
        render json: meal_json(meal), status: :accepted
      end

      private

      def find_meal
        current_user.meals.find(params[:id])
      end

      def meal_params
        params.permit(:raw_text, :notes, :eaten_at, :meal_type)
      end

      def meal_json(meal)
        meal.as_json(only: %i[id raw_text notes eaten_at meal_type created_at]).merge(
          "parse_status" => meal.parse_status,
          "parsed_at" => meal.parsed_at,
          "food_entries" => meal.food_entries.map(&:as_entry_json)
        )
      end
    end
  end
end
