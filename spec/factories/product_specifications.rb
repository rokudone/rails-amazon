FactoryBot.define do
  factory :product_specification do
    association :product
    sequence(:name) { |n| ["Dimensions", "Weight", "Battery Life", "Processor", "Memory", "Storage", "Display", "Resolution", "Connectivity", "Specification #{n}"].sample }
    sequence(:value) { |n| "Value #{n}" }
    unit { ["mm", "cm", "kg", "g", "hours", "GHz", "GB", "TB", "inches", "pixels", ""].sample }
    position { rand(0..10) }

    trait :dimensions do
      name { "Dimensions" }
      value { "#{rand(10..100)} x #{rand(10..100)} x #{rand(1..10)}" }
      unit { "cm" }
    end

    trait :weight do
      name { "Weight" }
      value { "#{rand(0.1..10.0).round(2)}" }
      unit { ["kg", "g"].sample }
    end

    trait :battery do
      name { "Battery Life" }
      value { "#{rand(1..24)}" }
      unit { "hours" }
    end
  end
end
