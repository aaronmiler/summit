class AddSummaryToMeals < ActiveRecord::Migration[8.1]
  def change
    add_column :meals, :summary, :string
  end
end
