FactoryBot.define do
  factory :product_video do
    association :product
    sequence(:video_url) { |n| "https://www.youtube.com/watch?v=#{SecureRandom.alphanumeric(11)}" }
    sequence(:thumbnail_url) { |n| "https://img.youtube.com/vi/#{SecureRandom.alphanumeric(11)}/hqdefault.jpg" }
    sequence(:title) { |n| "#{product.name} - Video #{n}" }
    description { Faker::Lorem.paragraph }
    position { rand(0..10) }

    trait :vimeo do
      sequence(:video_url) { |n| "https://vimeo.com/#{rand(100000000..999999999)}" }
      sequence(:thumbnail_url) { |n| "https://i.vimeocdn.com/video/#{rand(100000000..999999999)}_640.jpg" }
    end
  end
end
