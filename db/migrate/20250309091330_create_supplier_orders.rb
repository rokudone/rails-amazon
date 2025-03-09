class CreateSupplierOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :supplier_orders do |t|
      t.string :order_number, null: false
      t.string :supplier_name, null: false
      t.string :supplier_email
      t.string :supplier_phone
      t.string :supplier_contact_person
      t.text :supplier_address
      t.date :order_date, null: false
      t.date :expected_delivery_date
      t.date :actual_delivery_date
      t.string :status, default: 'draft' # 'draft', 'submitted', 'confirmed', 'shipped', 'partially_received', 'received', 'cancelled'
      t.decimal :total_amount, precision: 12, scale: 2
      t.decimal :tax_amount, precision: 10, scale: 2
      t.decimal :shipping_cost, precision: 10, scale: 2
      t.string :payment_terms
      t.string :payment_status, default: 'pending' # 'pending', 'partial', 'paid'
      t.string :shipping_method
      t.string :tracking_number
      t.text :notes
      t.string :created_by
      t.string :approved_by
      t.datetime :approved_at
      t.references :warehouse, null: false, foreign_key: true
      t.jsonb :line_items
      t.string :currency, default: 'USD'
      t.decimal :exchange_rate, precision: 10, scale: 6, default: 1.0

      t.timestamps
    end

    add_index :supplier_orders, :order_number, unique: true
    add_index :supplier_orders, :supplier_name
    add_index :supplier_orders, :status
    add_index :supplier_orders, :order_date
    add_index :supplier_orders, :expected_delivery_date
    add_index :supplier_orders, :payment_status
  end
end
