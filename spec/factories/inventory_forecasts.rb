FactoryBot.define do
  factory :inventory_forecast do
    association :product
    association :warehouse
    product_variant { nil }
    forecast_date { 1.month.from_now.to_date }
    forecasted_demand { 100 }
    forecasted_supply { 150 }
    forecasted_inventory_level { 200 }
    confidence_level { 85.5 }
    forecast_method { "moving_average" }
    forecast_notes { "標準的な予測" }
    historical_data { { "past_30_days": [80, 90, 85, 95, 100], "past_90_days": [75, 80, 85, 90, 95, 100] } }
    seasonal_factors { { "spring": 1.2, "summer": 1.5, "fall": 1.0, "winter": 0.8 } }
    forecast_period { "monthly" }
    is_adjusted { false }
    manual_adjustment { nil }
    adjusted_by { nil }
    adjusted_at { nil }
    forecasted_revenue { 10000.0 }
    forecasted_cost { 5000.0 }

    trait :with_variant do
      association :product_variant
    end

    trait :daily_forecast do
      forecast_period { "daily" }
      forecast_date { 1.day.from_now.to_date }
    end

    trait :weekly_forecast do
      forecast_period { "weekly" }
      forecast_date { 1.week.from_now.to_date }
    end

    trait :monthly_forecast do
      forecast_period { "monthly" }
      forecast_date { 1.month.from_now.to_date }
    end

    trait :quarterly_forecast do
      forecast_period { "quarterly" }
      forecast_date { 3.months.from_now.to_date }
    end

    trait :high_demand do
      forecasted_demand { 500 }
      forecasted_inventory_level { 100 }
    end

    trait :low_demand do
      forecasted_demand { 10 }
      forecasted_inventory_level { 300 }
    end

    trait :adjusted do
      is_adjusted { true }
      manual_adjustment { 50 }
      adjusted_by { "admin" }
      adjusted_at { 1.day.ago }
    end

    trait :high_confidence do
      confidence_level { 95.0 }
    end

    trait :low_confidence do
      confidence_level { 45.0 }
    end

    trait :exponential_smoothing do
      forecast_method { "exponential_smoothing" }
    end

    trait :arima do
      forecast_method { "arima" }
    end

    trait :machine_learning do
      forecast_method { "machine_learning" }
      confidence_level { 92.0 }
    end

    trait :high_revenue do
      forecasted_demand { 200 }
      forecasted_revenue { 50000.0 }
      forecasted_cost { 20000.0 }
    end
  end
end
