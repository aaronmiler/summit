FactoryBot.define do
  factory :progression_phase do
    association :progression
    association :exercise
    sequence(:position)
    target { "3x8" }
    graduation_criteria { "8 clean reps" }
  end
end
