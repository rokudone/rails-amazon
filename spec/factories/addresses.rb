FactoryBot.define do
  factory :address do
    association :user
    address_type { %w[billing shipping both].sample }
    name { Faker::Name.name }
    address_line1 { Faker::Address.street_address }
    address_line2 { Faker::Address.secondary_address }
    city { Faker::Address.city }
    state { Faker::Address.state }
    postal_code { Faker::Address.zip_code }
    country { Faker::Address.country_code }
    phone_number { Faker::PhoneNumber.cell_phone_in_e164 }
    is_default { false }

    trait :default do
      is_default { true }
    end

    trait :billing do
      address_type { 'billing' }
    end

    trait :shipping do
      address_type { 'shipping' }
    end

    trait :both do
      address_type { 'both' }
    end

    factory :default_address do
      default
    end

    factory :billing_address do
      billing
    end

    factory :shipping_address do
      shipping
    end
  end
end
