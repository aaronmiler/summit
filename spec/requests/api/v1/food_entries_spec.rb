require "rails_helper"

# Hand-correcting a meal's derived items. The human owns name/portion/unit;
# macros come from the LLM (rescale is code-side math, estimate is one LLM call).
# All scoped to the picked user's own meals.
RSpec.describe "Api::V1::FoodEntries", type: :request do
  let!(:aaron) { create(:user, name: "Aaron") }
  let!(:bree) { create(:user, name: "Bree") }
  let(:meal) { create(:meal, user: aaron) }

  def sign_in(user) = post("/api/v1/session", params: { user_id: user.id })
  before { sign_in(aaron) }

  describe "POST /api/v1/meals/:meal_id/food_entries" do
    it "adds an item the parse missed (macros come later)" do
      expect {
        post "/api/v1/meals/#{meal.id}/food_entries",
             params: { name: "side salad", amount: 1, unit: "serving" }, as: :json
      }.to change(meal.food_entries, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("name" => "side salad", "unit" => "serving")
    end
  end

  describe "PATCH /api/v1/food_entries/:id" do
    it "edits name and unit without touching macros" do
      entry = create(:food_entry, meal:, name: "eggs", unit: "egg", calories: 140)

      patch "/api/v1/food_entries/#{entry.id}", params: { name: "scrambled eggs", unit: "large egg" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(entry.reload).to have_attributes(name: "scrambled eggs", unit: "large egg", calories: 140)
    end

    it "won't touch another user's item" do
      entry = create(:food_entry, meal: create(:meal, user: bree), name: "keep")

      patch "/api/v1/food_entries/#{entry.id}", params: { name: "hacked" }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(entry.reload.name).to eq("keep")
    end
  end

  describe "DELETE /api/v1/food_entries/:id" do
    it "removes a spurious item" do
      entry = create(:food_entry, meal:)

      expect { delete "/api/v1/food_entries/#{entry.id}" }.to change(meal.food_entries, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "POST /api/v1/food_entries/:id/rescale" do
    it "rescales the stored macro totals by the new amount (no LLM)" do
      entry = create(:food_entry, meal:, name: "cheese pizza", amount: 1, unit: "slice",
                                  calories: 280, protein: 12, carbs: 36, fat: 10)

      post "/api/v1/food_entries/#{entry.id}/rescale", params: { amount: 3 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(entry.reload).to have_attributes(amount: 3, calories: 840, protein: 36, carbs: 108, fat: 30)
    end
  end

  describe "POST /api/v1/food_entries/:id/estimate" do
    it "fills the item's macros from one LLM call" do
      entry = create(:food_entry, meal:, name: "side salad", amount: 1, unit: "serving")
      allow(LitellmClient).to receive(:chat).and_return(
        '{"calories":120,"protein":3,"carbs":10,"fat":8,"confidence":0.6,"parse_notes":"with dressing"}'
      )

      post "/api/v1/food_entries/#{entry.id}/estimate"

      expect(response).to have_http_status(:ok)
      expect(entry.reload).to have_attributes(calories: 120, protein: 3, carbs: 10, fat: 8, confidence: 0.6)
    end

    it "502s when the LLM is unreachable" do
      entry = create(:food_entry, meal:, name: "mystery")
      allow(LitellmClient).to receive(:chat).and_raise(LitellmClient::Error, "down")

      post "/api/v1/food_entries/#{entry.id}/estimate"

      expect(response).to have_http_status(:bad_gateway)
    end
  end
end
