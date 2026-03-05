FactoryBot.define do
  factory :ticket do
    title       { Faker::Lorem.sentence(word_count: 4) }
    description { Faker::Lorem.paragraph }
    association :customer, factory: [ :user ]

    trait :closed do
      closed_at { Time.current }
      status    { "closed" }
      association :agent, factory: [ :user, :agent ]
    end
  end
end
