FactoryBot.define do
  factory :food_entry do
    association :meal
    sequence(:name) { |n| "Food #{n}" }
  end
end
