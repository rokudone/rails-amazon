class CreateOrderItems < ActiveRecord::Migration[7.0]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.string :sku, null: false
      t.string :name, null: false
      t.text :description
      t.integer :quantity, null: false, default: 1
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :original_price, precision: 10, scale: 2
      t.decimal :discount_amount, precision: 10, scale: 2, default: 0
      t.string :discount_type # 'percentage', 'fixed_amount', 'buy_x_get_y'
      t.string :discount_description
      t.decimal :tax_amount, precision: 10, scale: 2, default: 0
      t.decimal :tax_rate, precision: 6, scale: 4
      t.decimal :subtotal, precision: 12, scale: 2, null: false
      t.decimal :total, precision: 12, scale: 2, null: false
      t.string :status, default: 'pending' # 'pending', 'processing', 'shipped', 'delivered', 'cancelled', 'returned'
      t.boolean :is_gift, default: false
      t.text :gift_message
      t.string :gift_wrap_type
      t.decimal :gift_wrap_cost, precision: 8, scale: 2, default: 0
      t.boolean :is_digital, default: false
      t.string :digital_download_link
      t.integer :download_count, default: 0
      t.datetime :download_expiry
      t.boolean :requires_shipping, default: true
      t.decimal :weight, precision: 8, scale: 2
      t.string :weight_unit, default: 'kg'
      t.jsonb :dimensions
      t.references :warehouse, foreign_key: true
      t.references :shipment, foreign_key: true
      t.references :return, foreign_key: true
      t.string :return_reason
      t.text :notes
      t.jsonb :metadata

      t.timestamps
    end

    add_index :order_items, :sku
    add_index :order_items, :status
    add_index :order_items, :is_digital
  end
end
