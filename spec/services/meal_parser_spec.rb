require "rails_helper"

# MealParser: one totals-mode LLM call -> FoodEntry rows. The LLM is stubbed;
# these pin the extract/coerce/replace behavior and the audit logging, not the
# model's accuracy (that's the eval's job — script/nutrition_eval).
RSpec.describe MealParser do
  let(:meal) { create(:meal, raw_text: "2 eggs, toast") }

  def stub_llm(content) = allow(LitellmClient).to receive(:chat).and_return(content)

  it "parses totals-mode JSON into FoodEntry rows" do
    stub_llm('{"items":[{"name":"eggs","amount":2,"unit":"egg","calories":140,"protein":12,"carbs":1,"fat":10,"confidence":0.8,"parse_notes":"large"}]}')

    entries = MealParser.call(meal)

    expect(entries.size).to eq(1)
    expect(meal.food_entries.first).to have_attributes(
      name: "eggs", amount: 2, unit: "egg", calories: 140, protein: 12, confidence: 0.8
    )
  end

  it "rounds fractional calories to the integer column and tolerates unit strays" do
    stub_llm('{"items":[{"name":"toast","amount":1,"unit":"slice","calories":80.6,"protein":"3g","carbs":14,"fat":1}]}')

    MealParser.call(meal)

    expect(meal.food_entries.first).to have_attributes(calories: 81, protein: 3)
  end

  it "strips qwen <think> blocks and markdown fences" do
    stub_llm(<<~OUT)
      <think>let me estimate</think>
      ```json
      {"items":[{"name":"toast","amount":1,"unit":"slice","calories":80,"protein":3,"carbs":14,"fat":1,"confidence":0.7}]}
      ```
    OUT

    expect { MealParser.call(meal) }.to change(meal.food_entries, :count).by(1)
  end

  it "replaces prior derived entries on re-parse" do
    create(:food_entry, meal:, name: "stale")
    stub_llm('{"items":[{"name":"fresh","amount":1,"unit":"serving","calories":100}]}')

    MealParser.call(meal)

    expect(meal.food_entries.reload.map(&:name)).to eq([ "fresh" ])
  end

  it "treats non-food text as zero entries and clears any stale ones" do
    create(:food_entry, meal:)
    stub_llm('{"items":[]}')

    MealParser.call(meal)

    expect(meal.food_entries.reload).to be_empty
  end

  it "logs a success IntegrationEvent tagged with the meal and model" do
    stub_llm('{"items":[{"name":"eggs","amount":2,"unit":"egg","calories":140}]}')

    expect { MealParser.call(meal) }
      .to change { IntegrationEvent.of_kind("llm.nutrition_parse").count }.by(1)

    ev = IntegrationEvent.last
    expect(ev).to have_attributes(status: "ok", user: meal.user)
    expect(ev.metadata).to include("meal_id" => meal.id, "item_count" => 1)
  end

  it "records a parse_error and leaves entries untouched on unparseable output" do
    create(:food_entry, meal:, name: "keep")
    stub_llm("sorry, I can't do that")

    expect(MealParser.call(meal)).to eq([])
    expect(meal.food_entries.reload.map(&:name)).to eq([ "keep" ])
    expect(IntegrationEvent.last.status).to eq("parse_error")
  end

  it "records an error and re-raises when the client fails" do
    allow(LitellmClient).to receive(:chat).and_raise(LitellmClient::Error, "boom")

    expect { MealParser.call(meal) }.to raise_error(LitellmClient::Error)
    expect(IntegrationEvent.last.status).to eq("error")
  end
end
