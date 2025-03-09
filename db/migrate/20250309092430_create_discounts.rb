class CreateDiscounts < ActiveRecord::Migration[7.1]
  def change
    create_table :discounts do |t|
      t.string :name, null: false
      t.text :description
      t.datetime :start_date, null: false
      t.datetime :end_date, null: false
      t.boolean :is_active, default: true
      t.string :discount_type # percentage, fixed_amount, buy_one_get_one, etc.
      t.decimal :discount_amount, precision: 10, scale: 2
      t.decimal :minimum_purchase_amount, precision: 10, scale: 2
      t.integer :usage_limit
      t.integer :usage_count, default: 0
      t.references :product, foreign_key: true
      t.references :category, foreign_key: true
      t.references :brand, foreign_key: true
      t.boolean :is_combinable, default: false
      t.integer :priority, default: 0
      t.references :created_by, foreign_key: { to_table: :users }
      t.boolean :is_automatic, default: true
      t.string :status # active, scheduled, expired, cancelled

      t.timestamps
    end
  end
end
