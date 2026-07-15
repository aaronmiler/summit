class CreateProgressionPhases < ActiveRecord::Migration[8.1]
  def change
    create_table :progression_phases do |t|
      t.references :progression, null: false, foreign_key: true
      t.references :exercise, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :target
      t.text :graduation_criteria

      t.timestamps
    end
    add_index :progression_phases, [ :progression_id, :position ], unique: true
  end
end
