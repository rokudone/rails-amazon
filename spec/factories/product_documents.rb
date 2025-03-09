FactoryBot.define do
  factory :product_document do
    association :product
    sequence(:document_url) { |n| "https://example.com/products/#{product.id}/documents/document-#{n}.pdf" }
    sequence(:title) { |n| "#{product.name} - Document #{n}" }
    document_type { %w[PDF Manual Specification Warranty Certificate].sample }
    position { rand(0..10) }

    trait :pdf do
      document_type { "PDF" }
      sequence(:document_url) { |n| "https://example.com/products/#{product.id}/documents/document-#{n}.pdf" }
    end

    trait :word do
      document_type { "Word" }
      sequence(:document_url) { |n| "https://example.com/products/#{product.id}/documents/document-#{n}.docx" }
    end

    trait :excel do
      document_type { "Excel" }
      sequence(:document_url) { |n| "https://example.com/products/#{product.id}/documents/document-#{n}.xlsx" }
    end
  end
end
