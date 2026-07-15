class CreateRoutineExercises < ActiveRecord::Migration[8.1]
  def change
    create_table :routine_exercises do |t|
      t.references :routine, null: false, foreign_key: true
      # exercise XOR progression — exactly one is set (see check constraint below).
      t.references :exercise, null: true, foreign_key: true
      t.references :progression, null: true, foreign_key: true
      t.integer :position, null: false
      t.string :target
      t.integer :rest_seconds
      t.text :notes
      t.text :progression_note

      t.timestamps
    end
    add_index :routine_exercises, [ :routine_id, :position ]
    add_check_constraint :routine_exercises,
      "num_nonnulls(exercise_id, progression_id) = 1",
      name: "routine_exercises_exactly_one_target"
  end
end
