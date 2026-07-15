FactoryBot.define do
  factory :meal do
    association :user
    raw_text { "2 eggs, sausage, toast" }
  end
end
