class CreateOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :orders do |t|
      t.string :order_number, null: false
      t.references :user, null: false, foreign_key: true
      t.references :order_status, null: false, foreign_key: true
      t.datetime :order_date, null: false
      t.decimal :subtotal, precision: 12, scale: 2, null: false
      t.decimal :tax_total, precision: 10, scale: 2, default: 0
      t.decimal :shipping_total, precision: 10, scale: 2, default: 0
      t.decimal :discount_total, precision: 10, scale: 2, default: 0
      t.decimal :grand_total, precision: 12, scale: 2, null: false
      t.string :currency, default: 'USD'
      t.decimal :exchange_rate, precision: 10, scale: 6, default: 1.0
      t.string :payment_status, default: 'pending' # 'pending', 'authorized', 'paid', 'partially_refunded', 'refunded', 'failed'
      t.string :fulfillment_status, default: 'pending' # 'pending', 'processing', 'partially_shipped', 'shipped', 'delivered', 'cancelled'
      t.boolean :is_gift, default: false
      t.text :gift_message
      t.string :coupon_code
      t.string :tracking_number
      t.string :shipping_method
      t.datetime :estimated_delivery_date
      t.datetime :actual_delivery_date
      t.references :billing_address, foreign_key: { to_table: :addresses }
      t.references :shipping_address, foreign_key: { to_table: :addresses }
      t.string :customer_notes
      t.string :admin_notes
      t.string :source, default: 'website' # 'website', 'mobile_app', 'phone', 'in_store', 'marketplace'
      t.string :ip_address
      t.string :user_agent
      t.boolean :is_prime, default: false
      t.boolean :requires_signature, default: false
      t.datetime :cancelled_at
      t.string :cancellation_reason
      t.string :locale, default: 'en'

      t.timestamps
    end

    add_index :orders, :order_number, unique: true
    add_index :orders, :order_date
    add_index :orders, :payment_status
    add_index :orders, :fulfillment_status
    add_index :orders, :is_prime
    add_index :orders, :source
    add_index :orders, :coupon_code
  end
end
