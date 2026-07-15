class CreateMeals < ActiveRecord::Migration[8.1]
  def change
    create_table :meals do |t|
      t.references :user, null: false, foreign_key: true
      t.text :raw_text, null: false
      t.datetime :eaten_at
      t.text :notes

      t.timestamps
    end
  end
end
