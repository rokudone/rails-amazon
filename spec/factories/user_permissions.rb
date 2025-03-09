FactoryBot.define do
  factory :user_permission do
    association :user
    permission_name { %w[admin moderator seller buyer support analyst].sample }
    resource_type { ['Product', 'Order', 'Category', 'Review', 'User', nil].sample }
    resource_id { resource_type ? rand(1..1000) : nil }
    action { %w[read write delete manage all].sample }
    is_allowed { true }
    granted_at { Faker::Time.backward(days: 30) }
    expires_at { [nil, Faker::Time.forward(days: 180)].sample }
    granted_by { Faker::Name.name }

    trait :allowed do
      is_allowed { true }
    end

    trait :denied do
      is_allowed { false }
    end

    trait :expired do
      expires_at { Faker::Time.backward(days: 10) }
    end

    trait :permanent do
      expires_at { nil }
    end

    trait :admin do
      permission_name { 'admin' }
      action { 'all' }
      resource_type { nil }
      resource_id { nil }
    end

    trait :moderator do
      permission_name { 'moderator' }
      action { %w[read write delete].sample }
    end

    trait :seller do
      permission_name { 'seller' }
      resource_type { ['Product', 'Order'].sample }
    end

    trait :buyer do
      permission_name { 'buyer' }
      resource_type { ['Order', 'Review'].sample }
      action { %w[read write].sample }
    end

    trait :for_product do
      resource_type { 'Product' }
      resource_id { rand(1..1000) }
    end

    trait :for_order do
      resource_type { 'Order' }
      resource_id { rand(1..1000) }
    end

    factory :admin_permission do
      admin
      permanent
    end

    factory :moderator_permission do
      moderator
    end

    factory :seller_permission do
      seller
    end
  end
end
