class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.text :equipment
      t.text :goals
      t.text :preferences
      t.text :notes

      t.timestamps
    end
  end
end
