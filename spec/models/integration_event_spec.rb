require "rails_helper"

RSpec.describe IntegrationEvent do
  describe ".record!" do
    it "writes an event with the given fields" do
      user = create(:user)
      event = IntegrationEvent.record!(
        kind: "llm.workout_build", user: user, source: "anthropic", direction: "outbound",
        summary: "built a push day", metadata: { model: "claude", prompt_tokens: 900 },
        duration_ms: 1234
      )

      expect(event).to have_attributes(
        kind: "llm.workout_build", status: "ok", source: "anthropic",
        direction: "outbound", duration_ms: 1234, user: user
      )
      expect(event.metadata).to eq("model" => "claude", "prompt_tokens" => 900)
      expect(event).to be_succeeded
    end

    it "never raises — a logging failure returns nil instead of propagating" do
      expect(IntegrationEvent.record!(kind: nil)).to be_nil # kind is required
    end
  end

  describe "scopes" do
    it "partitions by outcome and kind" do
      ok = create(:integration_event, kind: "health.push", status: "ok")
      err = create(:integration_event, kind: "health.push", status: "error")
      other = create(:integration_event, kind: "llm.nutrition_parse", status: "ok")

      expect(IntegrationEvent.succeeded).to contain_exactly(ok, other)
      expect(IntegrationEvent.failed).to contain_exactly(err)
      expect(IntegrationEvent.of_kind("health.push")).to contain_exactly(ok, err)
    end
  end
end
