FactoryBot.define do
  factory :product_tag do
    association :product
    association :tag
  end
end
