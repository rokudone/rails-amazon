class CreateCountries < ActiveRecord::Migration[7.1]
  def change
    create_table :countries do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :native_name
      t.string :phone_code
      t.string :capital
      t.string :currency_code
      t.string :tld # Top Level Domain
      t.string :region
      t.string :subregion
      t.float :latitude
      t.float :longitude
      t.string :flag_image_url
      t.boolean :is_active, default: true
      t.boolean :is_shipping_available, default: true
      t.boolean :is_billing_available, default: true
      t.jsonb :address_format
      t.jsonb :postal_code_format
      t.references :currency, foreign_key: true
      t.integer :position, default: 0
      t.string :locale

      t.timestamps
    end

    add_index :countries, :code, unique: true
    add_index :countries, :name
  end
end
