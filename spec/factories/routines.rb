FactoryBot.define do
  factory :routine do
    sequence(:name) { |n| "Routine #{n}" }
    tags { [] }
  end
end
