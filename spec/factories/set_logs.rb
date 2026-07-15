FactoryBot.define do
  factory :set_log do
    association :workout
    association :exercise
    sequence(:set_number)
    reps { 8 }
    weight { 135.0 }
  end
end
