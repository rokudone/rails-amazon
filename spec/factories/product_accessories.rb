FactoryBot.define do
  factory :product_accessory do
    association :product
    association :accessory, factory: :product
    is_required { [true, false].sample }

    trait :required do
      is_required { true }
    end

    trait :optional do
      is_required { false }
    end
  end
end
