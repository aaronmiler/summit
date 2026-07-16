class PrepareHealthImportsForIngestion < ActiveRecord::Migration[8.1]
  def change
    # A HealthImport is now a first-class per-user event: it can stand alone
    # (a pushed Apple Health session) or attach to a materialized Workout.
    add_reference :health_imports, :user, null: false, foreign_key: true
    change_column_null :health_imports, :workout_id, true

    add_column :health_imports, :activity_type, :string   # "Outdoor Walk", etc.
    add_column :health_imports, :distance, :decimal, precision: 8, scale: 2 # miles
    add_column :health_imports, :recorded_at, :datetime   # the session's start
    add_column :health_imports, :external_id, :string     # HealthKit UUID, for dedupe
    add_column :health_imports, :raw, :jsonb              # the verbatim payload, lossless

    # Dedupe: a given source event lands once per user (re-sends are no-ops).
    add_index :health_imports, [ :user_id, :external_id ], unique: true,
              where: "external_id IS NOT NULL", name: "index_health_imports_on_user_and_external_id"
  end
end
