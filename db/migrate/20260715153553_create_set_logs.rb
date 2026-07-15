class CreateSetLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :set_logs do |t|
      t.references :workout, null: false, foreign_key: true
      # restrict FK (the default) — a movement with logged sets can't be deleted,
      # so history is never orphaned.
      t.references :exercise, null: false, foreign_key: true
      # nullable context — off-script logging carries neither.
      t.references :routine_exercise, null: true, foreign_key: true
      t.references :progression_phase, null: true, foreign_key: true
      t.integer :set_number, null: false
      t.integer :reps
      t.decimal :weight, precision: 6, scale: 2
      t.integer :duration_seconds
      t.decimal :rpe, precision: 3, scale: 1
      t.text :notes

      t.timestamps
    end
  end
end
