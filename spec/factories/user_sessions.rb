FactoryBot.define do
  factory :user_session do
    association :user
    session_token { SecureRandom.hex(32) }
    ip_address { Faker::Internet.ip_v4_address }
    user_agent { "Mozilla/5.0 (#{['Windows NT 10.0', 'Macintosh', 'Linux'].sample}; rv:#{rand(70..100)}.0) Gecko/20100101 Firefox/#{rand(70..100)}.0" }
    last_activity_at { Faker::Time.backward(days: 1) }
    expires_at { Faker::Time.forward(days: 1) }
    is_active { true }

    trait :inactive do
      is_active { false }
    end

    trait :expired do
      expires_at { Faker::Time.backward(days: 1) }
    end

    trait :mobile do
      user_agent { "Mozilla/5.0 (iPhone; CPU iPhone OS #{rand(12..16)}_#{rand(0..9)} like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/#{rand(12..16)}.#{rand(0..9)} Mobile/15E148 Safari/604.1" }
    end

    trait :long_lived do
      expires_at { Faker::Time.forward(days: 30) }
    end

    trait :recent_activity do
      last_activity_at { Faker::Time.backward(minutes: 5) }
    end

    factory :expired_session do
      expired
    end

    factory :inactive_session do
      inactive
    end
  end
end
