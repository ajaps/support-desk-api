FactoryBot.define do
  factory :user do
    name     { Faker::Name.name }
    email    { Faker::Internet.unique.email }
    password { "Password1!" }
    role     { "customer" }

    trait :agent do
      role { 1 }
    end

    trait :customer do
      role { 0 }
    end
  end
end
