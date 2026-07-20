require "rails_helper"

# Nutrition logging over the session cookie: a meal is freeform text that gets an
# async parse; entries + parse status read back on show; portion corrections are a
# code-side rescale (food_entries#update). The parse itself is stubbed/queued —
# MealParser has its own spec.
RSpec.describe "Api::V1::Meals", type: :request do
  let!(:aaron) { create(:user, name: "Aaron") }
  let!(:bree) { create(:user, name: "Bree") }

  def sign_in(user) = post("/api/v1/session", params: { user_id: user.id })

  describe "POST /api/v1/meals" do
    it "logs the meal and enqueues an async parse" do
      sign_in(aaron)

      expect {
        post "/api/v1/meals", params: { raw_text: "2 eggs, toast" }, as: :json
      }.to change(aaron.meals, :count).by(1).and have_enqueued_job(ParseMealJob)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("raw_text" => "2 eggs, toast", "parse_status" => "pending")
    end

    it "422s a meal with no text" do
      sign_in(aaron)
      post "/api/v1/meals", params: { raw_text: "" }, as: :json

      expect(response).to have_http_status(422)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "requires a picked user" do
      post "/api/v1/meals", params: { raw_text: "x" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/meals" do
    it "lists the picked user's meals newest first, and only theirs" do
      sign_in(aaron)
      old = create(:meal, user: aaron, raw_text: "oats", created_at: 2.days.ago)
      recent = create(:meal, user: aaron, raw_text: "tacos", created_at: 1.hour.ago)
      create(:meal, user: bree, raw_text: "not mine")

      get "/api/v1/meals"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |m| m["id"] }).to eq([ recent.id, old.id ])
    end
  end

  describe "PATCH /api/v1/meals/:id" do
    it "re-parses when the text changes" do
      sign_in(aaron)
      meal = create(:meal, user: aaron, raw_text: "eggs")

      expect {
        patch "/api/v1/meals/#{meal.id}", params: { raw_text: "3 eggs and toast" }, as: :json
      }.to have_enqueued_job(ParseMealJob).with(meal.id)

      expect(response).to have_http_status(:ok)
      expect(meal.reload.raw_text).to eq("3 eggs and toast")
    end

    it "edits notes/eaten_at without re-parsing" do
      sign_in(aaron)
      meal = create(:meal, user: aaron, raw_text: "eggs")

      expect {
        patch "/api/v1/meals/#{meal.id}", params: { notes: "post-workout" }, as: :json
      }.not_to have_enqueued_job(ParseMealJob)

      expect(meal.reload.notes).to eq("post-workout")
    end
  end

  describe "GET /api/v1/meals/:id" do
    it "returns the meal, its entries, and a derived parse status" do
      sign_in(aaron)
      meal = create(:meal, user: aaron, raw_text: "pizza")
      create(:food_entry, meal:, name: "cheese pizza", amount: 3, unit: "slice", calories: 840)
      create(:integration_event, kind: "llm.nutrition_parse", user: aaron, status: "ok",
                                  metadata: { "meal_id" => meal.id })

      get "/api/v1/meals/#{meal.id}"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include("parse_status" => "ok")
      expect(body["food_entries"].first).to include("name" => "cheese pizza", "amount" => "3.0", "unit" => "slice")
    end
  end

  describe "POST /api/v1/meals/:id/parse" do
    it "enqueues a re-parse" do
      sign_in(aaron)
      meal = create(:meal, user: aaron)

      expect {
        post "/api/v1/meals/#{meal.id}/parse"
      }.to have_enqueued_job(ParseMealJob).with(meal.id)

      expect(response).to have_http_status(:accepted)
    end
  end
end
