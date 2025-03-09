FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    phone_number { Faker::PhoneNumber.cell_phone_in_e164 }
    active { true }
    last_login_at { Faker::Time.backward(days: 14) }

    trait :inactive do
      active { false }
    end

    trait :locked do
      active { false }
      locked_at { Time.current }
      failed_attempts { 5 }
    end

    trait :with_reset_password do
      reset_password_token { SecureRandom.hex(20) }
      reset_password_sent_at { Time.current }
    end

    trait :with_profile do
      after(:create) do |user|
        create(:profile, user: user)
      end
    end

    trait :with_address do
      after(:create) do |user|
        create(:address, user: user)
      end
    end

    trait :with_payment_method do
      after(:create) do |user|
        create(:payment_method, user: user)
      end
    end

    trait :with_preferences do
      after(:create) do |user|
        create(:user_preference, user: user)
      end
    end

    factory :complete_user do
      with_profile
      with_address
      with_payment_method
      with_preferences
    end
  end
end
