require "rails_helper"

# FoodEntryEstimator: one LLM call fills a single item's macros. The LLM is
# stubbed — this pins that the human's name/amount/unit survive and only the
# macros are taken from the model, plus the audit logging.
RSpec.describe FoodEntryEstimator do
  let(:meal) { create(:meal) }
  let(:entry) { create(:food_entry, meal:, name: "side salad", amount: 2, unit: "cup") }

  def stub_llm(content) = allow(LitellmClient).to receive(:chat).and_return(content)

  it "fills macros while preserving the human's name/amount/unit" do
    stub_llm('{"calories":120,"protein":3,"carbs":10,"fat":8,"confidence":0.6,"parse_notes":"w/ dressing"}')

    FoodEntryEstimator.call(entry)

    expect(entry.reload).to have_attributes(
      name: "side salad", amount: 2, unit: "cup",
      calories: 120, protein: 3, fat: 8, confidence: 0.6, parse_notes: "w/ dressing"
    )
  end

  it "pins a known calorie total and fills only the macro split" do
    # The model still returns a calorie number; the human's measured total wins.
    stub_llm('{"calories":999,"protein":10,"carbs":20,"fat":5,"confidence":0.7}')

    FoodEntryEstimator.call(entry, known_calories: 240)

    expect(entry.reload).to have_attributes(calories: 240, protein: 10, carbs: 20, fat: 5)
  end

  it "logs a success IntegrationEvent tagged with the entry" do
    stub_llm('{"calories":120,"protein":3,"carbs":10,"fat":8}')

    expect { FoodEntryEstimator.call(entry) }
      .to change { IntegrationEvent.of_kind("llm.nutrition_estimate").count }.by(1)

    expect(IntegrationEvent.last.metadata).to include("food_entry_id" => entry.id, "meal_id" => meal.id)
  end

  it "leaves the entry untouched and records parse_error on unparseable output" do
    stub_llm("no idea")

    FoodEntryEstimator.call(entry)

    expect(entry.reload.calories).to be_nil
    expect(IntegrationEvent.last.status).to eq("parse_error")
  end

  it "records an error and re-raises when the client fails" do
    allow(LitellmClient).to receive(:chat).and_raise(LitellmClient::Error, "boom")

    expect { FoodEntryEstimator.call(entry) }.to raise_error(LitellmClient::Error)
    expect(IntegrationEvent.last.status).to eq("error")
  end
end
