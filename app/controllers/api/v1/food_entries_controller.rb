module Api
  module V1
    # A meal's derived items — hand-correctable. The split (docs/nutrition_parsing.md):
    # the human owns name/portion/unit; macros always come from the LLM, never
    # typed by hand. So the mutations are: edit name/unit (`update`), add/remove an
    # item (`create`/`destroy`), rescale a portion (`rescale` — code-side linear
    # math, no LLM), and estimate one item's macros (`estimate` — one LLM call).
    # All scoped to the user's own meals.
    class FoodEntriesController < BaseController
      before_action :require_current_user!

      # POST /api/v1/meals/:meal_id/food_entries — add an item the parse missed.
      # Macros come later via `estimate`; here it's just name + portion.
      def create
        meal = current_user.meals.find(params[:meal_id])
        entry = meal.food_entries.new(entry_params)
        if entry.save
          render json: entry.as_entry_json, status: :created
        else
          render json: { errors: entry.errors.full_messages }, status: 422
        end
      end

      # PATCH /api/v1/food_entries/:id — edit name/unit (portion is `rescale`).
      def update
        entry = find_entry
        if entry.update(entry_params)
          render json: entry.as_entry_json
        else
          render json: { errors: entry.errors.full_messages }, status: 422
        end
      end

      # DELETE /api/v1/food_entries/:id — drop a spurious item.
      def destroy
        find_entry.destroy!
        head :no_content
      end

      # POST /api/v1/food_entries/:id/rescale — correct the portion; macro totals
      # rescale linearly in code (× new/old). No LLM.
      def rescale
        entry = find_entry
        entry.rescale_to!(params.require(:amount).to_f)
        render json: entry.as_entry_json
      end

      # POST /api/v1/food_entries/:id/estimate — fill this item's macros with one
      # LLM call. Synchronous (foreground action, unlike the async meal parse).
      # Optional `calories`: a measured total to pin — the model fills only the
      # macro split and the human's calorie number is kept.
      def estimate
        known = params[:calories].presence&.to_f
        entry = FoodEntryEstimator.call(find_entry, known_calories: known)
        render json: entry.as_entry_json
      rescue LitellmClient::Error => e
        render json: { error: e.message }, status: :bad_gateway
      end

      private

      def find_entry
        FoodEntry.joins(:meal)
          .where(meals: { user_id: current_user.id })
          .find(params[:id])
      end

      def entry_params
        params.permit(:name, :amount, :unit)
      end
    end
  end
end
