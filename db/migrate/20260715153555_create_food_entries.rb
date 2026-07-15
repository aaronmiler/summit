class CreateFoodEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :food_entries do |t|
      t.references :meal, null: false, foreign_key: true
      t.string :name
      t.integer :calories
      t.decimal :protein, precision: 6, scale: 2
      t.decimal :carbs, precision: 6, scale: 2
      t.decimal :fat, precision: 6, scale: 2
      t.decimal :confidence, precision: 3, scale: 2
      t.text :parse_notes

      t.timestamps
    end
  end
end
