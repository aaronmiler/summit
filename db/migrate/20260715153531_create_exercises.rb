class CreateExercises < ActiveRecord::Migration[8.1]
  def change
    create_table :exercises do |t|
      t.string :name, null: false
      t.string :modality, null: false
      t.string :muscle_group

      t.timestamps
    end
    add_index :exercises, :name, unique: true
  end
end
