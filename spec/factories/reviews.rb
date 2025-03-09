FactoryBot.define do
  factory :review do
    user
    product
    title { Faker::Lorem.sentence(word_count: 5) }
    content { Faker::Lorem.paragraph(sentence_count: 3) }
    rating { rand(1..5) }
    verified_purchase { [true, false].sample }
    is_approved { false }
    status { 'pending' }

    trait :approved do
      is_approved { true }
      approved_at { Time.current }
      status { 'approved' }
    end

    trait :rejected do
      is_approved { false }
      status { 'rejected' }
    end

    trait :featured do
      is_featured { true }
    end

    trait :with_spoiler do
      contains_spoiler { true }
    end

    trait :with_votes do
      helpful_votes_count { rand(1..50) }
      unhelpful_votes_count { rand(1..10) }
    end

    trait :with_images do
      transient do
        images_count { 2 }
      end

      after(:create) do |review, evaluator|
        create_list(:review_image, evaluator.images_count, review: review)
      end
    end

    factory :approved_review do
      is_approved { true }
      approved_at { Time.current }
      status { 'approved' }
    end

    factory :complete_review do
      is_approved { true }
      approved_at { Time.current }
      status { 'approved' }
      verified_purchase { true }
      helpful_votes_count { rand(1..50) }
      unhelpful_votes_count { rand(1..10) }

      after(:create) do |review|
        create_list(:review_image, 2, review: review)
        create_list(:review_vote, 3, review: review, is_helpful: true)
        create_list(:review_vote, 1, review: review, is_helpful: false)
      end
    end
  end

  factory :rating do
    user
    product
    value { rand(1..5) }
    dimension { ['quality', 'price', 'shipping', 'customer_service'].sample }
    comment { Faker::Lorem.sentence }
    is_anonymous { [true, false].sample }
  end

  factory :question do
    user
    product
    content { Faker::Lorem.paragraph(sentence_count: 2) }
    is_approved { false }
    status { 'pending' }

    trait :approved do
      is_approved { true }
      approved_at { Time.current }
      status { 'approved' }
    end

    trait :rejected do
      is_approved { false }
      status { 'rejected' }
    end

    trait :featured do
      is_featured { true }
    end

    trait :answered do
      is_answered { true }
      answers_count { rand(1..5) }

      after(:create) do |question, evaluator|
        create_list(:answer, evaluator.answers_count, question: question)
      end
    end

    factory :approved_question do
      is_approved { true }
      approved_at { Time.current }
      status { 'approved' }
    end
  end

  factory :answer do
    user
    question
    content { Faker::Lorem.paragraph(sentence_count: 2) }
    is_approved { false }
    status { 'pending' }

    trait :approved do
      is_approved { true }
      approved_at { Time.current }
      status { 'approved' }
    end

    trait :rejected do
      is_approved { false }
      status { 'rejected' }
    end

    trait :seller_answer do
      is_seller_answer { true }
    end

    trait :amazon_answer do
      is_amazon_answer { true }
    end

    trait :best_answer do
      is_best_answer { true }
    end

    trait :with_votes do
      helpful_votes_count { rand(1..30) }
      unhelpful_votes_count { rand(1..5) }
    end

    factory :approved_answer do
      is_approved { true }
      approved_at { Time.current }
      status { 'approved' }
    end
  end

  factory :review_image do
    review
    image_url { Faker::Internet.url(host: 'example.com', path: "/images/#{SecureRandom.hex(8)}.jpg") }
    alt_text { Faker::Lorem.sentence }
    position { rand(0..5) }
    is_approved { false }
    status { 'pending' }
    content_type { 'image/jpeg' }
    file_size { rand(100_000..5_000_000) }

    trait :approved do
      is_approved { true }
      approved_at { Time.current }
      status { 'approved' }
    end

    trait :rejected do
      is_approved { false }
      status { 'rejected' }
    end
  end

  factory :review_vote do
    user
    review
    is_helpful { [true, false].sample }

    trait :helpful do
      is_helpful { true }
    end

    trait :unhelpful do
      is_helpful { false }
    end

    trait :reported do
      is_reported { true }
      report_reason { Faker::Lorem.sentence }
    end
  end
end
