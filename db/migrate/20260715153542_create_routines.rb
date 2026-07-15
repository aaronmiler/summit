class CreateRoutines < ActiveRecord::Migration[8.1]
  def change
    create_table :routines do |t|
      t.string :name, null: false
      t.text :notes
      t.string :tags, array: true, null: false, default: []
      t.string :preferred_frequency

      t.timestamps
    end
  end
end
