class CreateSellerProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :seller_products do |t|
      t.references :seller, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :quantity, default: 0
      t.boolean :is_active, default: true
      t.string :condition # new, used, refurbished, etc.
      t.text :condition_description
      t.string :sku
      t.decimal :shipping_cost, precision: 10, scale: 2
      t.integer :handling_days, default: 1
      t.boolean :is_featured, default: false
      t.boolean :is_prime_eligible, default: false
      t.boolean :is_fulfilled_by_amazon, default: false
      t.decimal :seller_cost, precision: 10, scale: 2
      t.decimal :profit_margin, precision: 5, scale: 2
      t.integer :sales_count, default: 0
      t.datetime :last_sold_at

      t.timestamps
    end

    add_index :seller_products, [:seller_id, :product_id], unique: true
    add_index :seller_products, :sku
  end
end
