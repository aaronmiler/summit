FactoryBot.define do
  factory :exercise do
    sequence(:name) { |n| "Exercise #{n}" }
    modality { "barbell" }
    muscle_group { "back" }
  end
end
