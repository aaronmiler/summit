class CreateHealthImports < ActiveRecord::Migration[8.1]
  def change
    create_table :health_imports do |t|
      t.references :workout, null: false, foreign_key: true
      t.integer :calories
      t.integer :avg_hr
      t.integer :duration_seconds
      t.string :source
      t.text :parse_notes
      t.decimal :confidence, precision: 3, scale: 2

      t.timestamps
    end
  end
end
