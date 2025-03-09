class CreateOrderDiscounts < ActiveRecord::Migration[7.0]
  def change
    create_table :order_discounts do |t|
      t.references :order, null: false, foreign_key: true
      t.string :discount_type, null: false # 'coupon', 'promotion', 'volume', 'loyalty', 'seasonal', 'employee', 'bundle'
      t.string :discount_code
      t.string :description
      t.string :calculation_type, null: false # 'percentage', 'fixed_amount', 'free_shipping', 'buy_x_get_y'
      t.decimal :discount_value, precision: 10, scale: 2, null: false
      t.decimal :maximum_discount_amount, precision: 10, scale: 2
      t.decimal :minimum_order_amount, precision: 10, scale: 2
      t.boolean :is_applied, default: true
      t.decimal :applied_amount, precision: 10, scale: 2
      t.datetime :applied_at
      t.datetime :valid_from
      t.datetime :valid_until
      t.boolean :is_combinable, default: true
      t.integer :usage_limit
      t.integer :usage_count, default: 0
      t.string :created_by
      t.text :notes
      t.jsonb :conditions # e.g., product categories, specific products, customer groups
      t.jsonb :metadata

      t.timestamps
    end

    add_index :order_discounts, :discount_code
    add_index :order_discounts, :discount_type
    add_index :order_discounts, :calculation_type
    add_index :order_discounts, :is_applied
    add_index :order_discounts, :valid_from
    add_index :order_discounts, :valid_until
  end
end
