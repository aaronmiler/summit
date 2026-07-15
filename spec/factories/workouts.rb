FactoryBot.define do
  factory :workout do
    association :user
    started_at { Time.current }
  end
end
