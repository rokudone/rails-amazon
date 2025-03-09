class CreateShipmentTrackings < ActiveRecord::Migration[7.0]
  def change
    create_table :shipment_trackings do |t|
      t.references :shipment, null: false, foreign_key: true
      t.references :order, foreign_key: true
      t.string :tracking_number, null: false
      t.string :carrier
      t.string :status
      t.string :status_code
      t.text :status_description
      t.datetime :tracking_date, null: false
      t.string :location
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.boolean :is_exception, default: false
      t.text :exception_details
      t.string :estimated_delivery_date
      t.jsonb :raw_tracking_data
      t.string :tracking_url
      t.boolean :is_delivered, default: false
      t.datetime :delivered_at
      t.string :received_by
      t.boolean :signature_required, default: false
      t.string :signature_image_url
      t.string :proof_of_delivery_url
      t.text :notes

      t.timestamps
    end

    add_index :shipment_trackings, :tracking_number
    add_index :shipment_trackings, :tracking_date
    add_index :shipment_trackings, :status
    add_index :shipment_trackings, :is_exception
    add_index :shipment_trackings, :is_delivered
    add_index :shipment_trackings, :delivered_at
  end
end
