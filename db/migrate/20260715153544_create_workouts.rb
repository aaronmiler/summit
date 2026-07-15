class CreateWorkouts < ActiveRecord::Migration[8.1]
  def change
    create_table :workouts do |t|
      t.references :user, null: false, foreign_key: true
      # nullable — off-script / ad-hoc workouts have no routine.
      t.references :routine, null: true, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.text :notes

      t.timestamps
    end
    add_index :workouts, [ :user_id, :started_at ]
  end
end
