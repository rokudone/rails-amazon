FactoryBot.define do
  factory :user_preference do
    association :user
    email_notifications { true }
    sms_notifications { false }
    push_notifications { true }
    language { %w[en ja fr es de zh ru].sample }
    currency { %w[USD EUR JPY GBP CAD AUD CNY].sample }
    timezone { ActiveSupport::TimeZone.all.sample.name }
    two_factor_auth { false }

    trait :all_notifications_on do
      email_notifications { true }
      sms_notifications { true }
      push_notifications { true }
    end

    trait :all_notifications_off do
      email_notifications { false }
      sms_notifications { false }
      push_notifications { false }
    end

    trait :with_two_factor do
      two_factor_auth { true }
    end

    trait :japanese do
      language { 'ja' }
      currency { 'JPY' }
      timezone { 'Asia/Tokyo' }
    end

    trait :english do
      language { 'en' }
      currency { 'USD' }
      timezone { 'America/New_York' }
    end
  end
end
