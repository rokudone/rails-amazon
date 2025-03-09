FactoryBot.define do
  factory :profile do
    association :user
    birth_date { Faker::Date.birthday(min_age: 18, max_age: 65) }
    gender { %w[male female other prefer_not_to_say].sample }
    bio { Faker::Lorem.paragraph(sentence_count: 3) }
    avatar { "https://example.com/avatars/#{Faker::Alphanumeric.alphanumeric(number: 10)}.jpg" }
    website { Faker::Internet.url }
    occupation { Faker::Job.title }
    company { Faker::Company.name }

    trait :minimal do
      bio { nil }
      avatar { nil }
      website { nil }
      occupation { nil }
      company { nil }
    end

    trait :with_long_bio do
      bio { Faker::Lorem.paragraphs(number: 5).join("\n\n") }
    end
  end
end
