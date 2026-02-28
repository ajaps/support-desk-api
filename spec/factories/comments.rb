FactoryBot.define do
  factory :comment do
    body   { Faker::Lorem.sentence }
    association :ticket
    association :user
  end
end
