class Meal < ApplicationRecord
  belongs_to :user
  has_many :food_entries, dependent: :destroy

  validates :raw_text, presence: true
end
