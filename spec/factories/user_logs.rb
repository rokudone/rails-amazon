FactoryBot.define do
  factory :user_log do
    association :user
    action { ['login', 'logout', 'password_reset', 'profile_update', 'payment_method_added', 'address_added'].sample }
    ip_address { Faker::Internet.ip_v4_address }
    user_agent { "Mozilla/5.0 (#{['Windows NT 10.0', 'Macintosh', 'Linux'].sample}; rv:#{rand(70..100)}.0) Gecko/20100101 Firefox/#{rand(70..100)}.0" }
    details { Faker::Json.shallow_json(width: 3, options: { key: 'Name.first_name', value: 'Name.last_name' }) }

    trait :login do
      action { 'login' }
      details { { success: [true, false].sample, method: ['password', 'oauth', 'token'].sample }.to_json }
    end

    trait :logout do
      action { 'logout' }
      details { { reason: ['user_initiated', 'session_timeout', 'security_concern'].sample }.to_json }
    end

    trait :password_reset do
      action { 'password_reset' }
      details { { requested_at: Faker::Time.backward(days: 1).iso8601, completed: [true, false].sample }.to_json }
    end

    trait :profile_update do
      action { 'profile_update' }
      details { { fields: ['name', 'email', 'avatar', 'bio'].sample(rand(1..4)) }.to_json }
    end
  end
end
