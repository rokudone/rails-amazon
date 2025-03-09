FactoryBot.define do
  factory :product_description do
    association :product
    full_description { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    features { Faker::Lorem.sentences(number: 5).map { |s| "- #{s}" }.join("\n") }
    care_instructions { Faker::Lorem.sentences(number: 3).map { |s| "- #{s}" }.join("\n") }
    warranty_info { Faker::Lorem.paragraph }
    return_policy { Faker::Lorem.paragraph }

    trait :minimal do
      full_description { Faker::Lorem.paragraph }
      features { nil }
      care_instructions { nil }
      warranty_info { nil }
      return_policy { nil }
    end

    trait :detailed do
      full_description { Faker::Lorem.paragraphs(number: 5).join("\n\n") }
      features { Faker::Lorem.sentences(number: 10).map { |s| "- #{s}" }.join("\n") }
      care_instructions { Faker::Lorem.sentences(number: 5).map { |s| "- #{s}" }.join("\n") }
      warranty_info { Faker::Lorem.paragraphs(number: 2).join("\n\n") }
      return_policy { Faker::Lorem.paragraphs(number: 2).join("\n\n") }
    end
  end
end
