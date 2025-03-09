class CreateInventoryForecasts < ActiveRecord::Migration[7.0]
  def change
    create_table :inventory_forecasts do |t|
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.references :warehouse, foreign_key: true
      t.date :forecast_date, null: false
      t.integer :forecasted_demand, null: false
      t.integer :forecasted_supply
      t.integer :forecasted_inventory_level
      t.decimal :confidence_level, precision: 5, scale: 2
      t.string :forecast_method # 'moving_average', 'exponential_smoothing', 'arima', 'machine_learning'
      t.text :forecast_notes
      t.jsonb :historical_data
      t.jsonb :seasonal_factors
      t.string :forecast_period # 'daily', 'weekly', 'monthly', 'quarterly'
      t.boolean :is_adjusted, default: false
      t.integer :manual_adjustment
      t.string :adjusted_by
      t.datetime :adjusted_at
      t.decimal :forecasted_revenue, precision: 12, scale: 2
      t.decimal :forecasted_cost, precision: 12, scale: 2

      t.timestamps
    end

    add_index :inventory_forecasts, :forecast_date
    add_index :inventory_forecasts, [:product_id, :warehouse_id, :forecast_date], name: 'idx_forecast_product_warehouse_date'
    add_index :inventory_forecasts, :forecast_period
  end
end
