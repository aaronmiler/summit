FactoryBot.define do
  factory :progression do
    sequence(:name) { |n| "Progression #{n}" }
  end
end
