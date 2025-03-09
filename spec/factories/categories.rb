FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    sequence(:slug) { |n| "category-#{n}" }
    description { Faker::Lorem.paragraph }
    position { rand(1..100) }
    is_active { true }

    trait :inactive do
      is_active { false }
    end

    trait :with_parent do
      association :parent, factory: :category
    end

    trait :with_children do
      transient do
        children_count { 3 }
      end

      after(:create) do |category, evaluator|
        create_list(:category, evaluator.children_count, parent: category)
      end
    end

    trait :with_sub_categories do
      transient do
        sub_categories_count { 3 }
      end

      after(:create) do |category, evaluator|
        create_list(:sub_category, evaluator.sub_categories_count, category: category)
      end
    end

    trait :with_products do
      transient do
        products_count { 5 }
      end

      after(:create) do |category, evaluator|
        create_list(:product, evaluator.products_count, category: category)
      end
    end

    factory :category_with_hierarchy do
      with_parent
      with_children
      with_sub_categories
      with_products
    end
  end
end
