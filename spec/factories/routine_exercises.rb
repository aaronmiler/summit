FactoryBot.define do
  factory :routine_exercise do
    association :routine
    association :exercise
    sequence(:position)

    # exercise XOR progression — swap to a progression slot with this trait.
    trait :progression_slot do
      exercise { nil }
      association :progression
    end
  end
end
