class CreateIntegrationEvents < ActiveRecord::Migration[8.1]
  def change
    # A general audit log for external interactions — inbound webhooks (Health
    # Auto Export pushes) and, later, outbound LLM calls (workout building,
    # nutrition parsing). One row per interaction; `kind` is the discriminator
    # and `metadata` carries the kind-specific detail. Log bucket: immutable
    # events, never rewritten.
    create_table :integration_events do |t|
      t.references :user, null: true, foreign_key: true # null = unauth/system
      t.string :kind, null: false          # "health.push", "llm.workout_build", ...
      t.string :source                      # "health_auto_export", "anthropic", ...
      t.string :direction                   # "inbound" | "outbound"
      t.string :status, null: false         # "ok" | "error" | "unauthorized" | "bad_request"
      t.string :summary                     # one-line, human-readable
      t.jsonb :metadata, null: false, default: {} # kind-specific structured detail
      t.integer :duration_ms                # latency, where it applies
      t.text :error                         # message/class on failure
      t.string :remote_ip                   # inbound source

      t.timestamps
    end

    add_index :integration_events, [ :kind, :created_at ]
  end
end
