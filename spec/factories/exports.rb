FactoryBot.define do
  factory :export do
    association :agent, factory: [ :user, :agent ]
    status { 1 }
    export_type { "closed_tickets" }
    exported_at { Time.current }
    error_message { nil }

    trait :with_file do
      after(:create) do |export|
        export.file.attach(
            io: File.open(Rails.root.join("spec/fixtures/sample_export.csv")),
            filename: "sample_export.csv",
            content_type: "text/csv"
        )
      end
    end
  end
end
