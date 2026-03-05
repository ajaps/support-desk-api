FactoryBot.define do
  factory :export do
    association :agent, factory: [ :user, :agent ]
    status { :completed }
    export_type { "recently_closed_tickets" }
    filename { "closed_tickets_#{Time.current.strftime('%Y_%m_%d_%H_%M')}.csv" }
    error_message { nil }

    trait :pending do
      status { :pending }
    end

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
