class CreateShipments < ActiveRecord::Migration[7.0]
  def change
    create_table :shipments do |t|
      t.references :order, null: false, foreign_key: true
      t.string :shipment_number, null: false
      t.string :carrier # 'fedex', 'ups', 'usps', 'dhl', 'amazon_logistics'
      t.string :service_level # 'standard', 'expedited', 'priority', 'overnight', 'two_day'
      t.string :tracking_number
      t.string :status, default: 'pending' # 'pending', 'processing', 'shipped', 'in_transit', 'out_for_delivery', 'delivered', 'failed', 'returned'
      t.datetime :shipped_at
      t.datetime :estimated_delivery_date
      t.datetime :actual_delivery_date
      t.references :warehouse, foreign_key: true
      t.decimal :shipping_cost, precision: 10, scale: 2
      t.decimal :insurance_cost, precision: 10, scale: 2, default: 0
      t.boolean :is_insured, default: false
      t.decimal :declared_value, precision: 12, scale: 2
      t.decimal :weight, precision: 8, scale: 2
      t.string :weight_unit, default: 'kg'
      t.jsonb :dimensions
      t.string :dimensions_unit, default: 'cm'
      t.integer :package_count, default: 1
      t.string :shipping_method
      t.text :shipping_notes
      t.string :recipient_name
      t.string :recipient_phone
      t.string :recipient_email
      t.text :shipping_address_line1
      t.text :shipping_address_line2
      t.string :shipping_city
      t.string :shipping_state
      t.string :shipping_postal_code
      t.string :shipping_country
      t.boolean :requires_signature, default: false
      t.boolean :is_gift, default: false
      t.text :gift_message
      t.string :customs_declaration_number
      t.jsonb :customs_information
      t.string :return_label_url
      t.string :shipping_label_url
      t.string :packing_slip_url
      t.string :created_by
      t.jsonb :metadata

      t.timestamps
    end

    add_index :shipments, :shipment_number, unique: true
    add_index :shipments, :tracking_number
    add_index :shipments, :status
    add_index :shipments, :shipped_at
    add_index :shipments, :estimated_delivery_date
    add_index :shipments, :actual_delivery_date
    add_index :shipments, :carrier
  end
end
