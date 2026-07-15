FactoryBot.define do
  factory :health_import do
    association :workout
    source { "Apple Health" }
  end
end
