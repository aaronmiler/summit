class AddMaxHrToHealthImports < ActiveRecord::Migration[8.1]
  def change
    # Peak heart rate for the session (bpm) — the effort ceiling that pairs with
    # avg_hr. Populated defensively from the HAE payload (maxHeartRate / the
    # heartRate.max fallback); NULL when the export didn't carry it.
    add_column :health_imports, :max_hr, :integer

    # Total energy burned (kcal) = active + basal, from HAE's `totalEnergy`. The
    # "calories out" number (existing `calories` is active-only); columned so it
    # can be rolled up over weeks. NULL when the export didn't carry it.
    add_column :health_imports, :total_calories, :integer
  end
end
