class CreateCoupons < ActiveRecord::Migration[7.1]
  def change
    create_table :coupons do |t|
      t.string :code, null: false
      t.string :name
      t.text :description
      t.datetime :start_date, null: false
      t.datetime :end_date, null: false
      t.boolean :is_active, default: true
      t.string :coupon_type # percentage, fixed_amount, free_shipping, etc.
      t.decimal :discount_amount, precision: 10, scale: 2
      t.decimal :minimum_order_amount, precision: 10, scale: 2
      t.integer :usage_limit_per_user
      t.integer :usage_limit_total
      t.integer :usage_count, default: 0
      t.boolean :is_single_use, default: false
      t.boolean :is_first_order_only, default: false
      t.references :promotion, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :category, foreign_key: true
      t.references :product, foreign_key: true
      t.boolean :is_combinable, default: false
      t.integer :priority, default: 0

      t.timestamps
    end

    add_index :coupons, :code, unique: true
  end
end
