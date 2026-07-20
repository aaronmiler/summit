class CreatePrograms < ActiveRecord::Migration[8.1]
  def change
    # A Program groups Routines into a named block ("Winter Strength", "Climbing
    # Base") so the Today picker isn't a flat wall of routines. A Library object —
    # shared and freely edited, like Routine itself. Grouping only: ordering and
    # scheduling stay soft (notes), no day-of-week binding.
    create_table :programs do |t|
      t.string :name, null: false
      t.text :notes

      t.timestamps
    end

    # Nullify (not cascade): deleting a Program must never delete its Routines —
    # they just fall back to ungrouped ("Other" on Today). One program per routine.
    add_reference :routines, :program, null: true, foreign_key: { on_delete: :nullify }
  end
end
