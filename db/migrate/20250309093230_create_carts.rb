class CreateCarts < ActiveRecord::Migration[7.1]
  def change
    create_table :carts do |t|
      t.references :user, foreign_key: true
      t.string :session_id
      t.string :status, default: 'active' # active, abandoned, converted, merged
      t.datetime :last_activity_at
      t.boolean :is_guest, default: false
      t.integer :items_count, default: 0
      t.decimal :total_amount, precision: 10, scale: 2, default: 0
      t.string :coupon_code
      t.decimal :discount_amount, precision: 10, scale: 2, default: 0
      t.decimal :tax_amount, precision: 10, scale: 2, default: 0
      t.decimal :shipping_amount, precision: 10, scale: 2, default: 0
      t.decimal :final_amount, precision: 10, scale: 2, default: 0
      t.string :currency, default: 'JPY'
      t.boolean :has_gift_wrap, default: false
      t.text :gift_message
      t.references :shipping_address, foreign_key: { to_table: :addresses }
      t.references :billing_address, foreign_key: { to_table: :addresses }
      t.datetime :converted_at
      t.references :converted_to_order, foreign_key: { to_table: :orders }

      t.timestamps
    end

    add_index :carts, :session_id
    add_index :carts, [:user_id, :status]

    create_table :cart_items do |t|
      t.references :cart, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.references :seller, foreign_key: true
      t.integer :quantity, default: 1
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :total_price, precision: 10, scale: 2, null: false
      t.boolean :is_saved_for_later, default: false
      t.boolean :is_gift, default: false
      t.text :gift_message
      t.boolean :has_gift_wrap, default: false
      t.references :gift_wrap, foreign_key: true
      t.string :status # in_stock, out_of_stock, back_ordered
      t.datetime :added_at
      t.datetime :last_modified_at
      t.jsonb :selected_options

      t.timestamps
    end

    add_index :cart_items, [:cart_id, :product_id, :product_variant_id], unique: true, name: 'index_cart_items_on_cart_product_and_variant'
  end
end
