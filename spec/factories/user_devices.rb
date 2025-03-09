FactoryBot.define do
  factory :user_device do
    association :user
    device_type { %w[mobile tablet desktop other].sample }
    device_token { SecureRandom.uuid }
    device_id { SecureRandom.uuid }
    os_type { %w[ios android windows macos linux other].sample }
    os_version { "#{rand(8..15)}.#{rand(0..9)}.#{rand(0..9)}" }
    app_version { "#{rand(1..5)}.#{rand(0..9)}.#{rand(0..9)}" }
    last_used_at { Faker::Time.backward(days: 30) }
    is_active { true }

    trait :inactive do
      is_active { false }
    end

    trait :mobile do
      device_type { 'mobile' }
      os_type { ['ios', 'android'].sample }
    end

    trait :tablet do
      device_type { 'tablet' }
      os_type { ['ios', 'android'].sample }
    end

    trait :desktop do
      device_type { 'desktop' }
      os_type { ['windows', 'macos', 'linux'].sample }
    end

    trait :ios do
      os_type { 'ios' }
      os_version { "#{rand(12..16)}.#{rand(0..7)}" }
    end

    trait :android do
      os_type { 'android' }
      os_version { "#{rand(8..13)}.#{rand(0..9)}" }
    end
  end
end
