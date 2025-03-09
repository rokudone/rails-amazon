class CreateRegions < ActiveRecord::Migration[7.1]
  def change
    create_table :regions do |t|
      t.references :country, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :native_name
      t.string :region_type # state, province, prefecture, etc.
      t.float :latitude
      t.float :longitude
      t.boolean :is_active, default: true
      t.boolean :is_shipping_available, default: true
      t.boolean :is_billing_available, default: true
      t.integer :position, default: 0
      t.jsonb :metadata

      t.timestamps
    end

    add_index :regions, [:country_id, :code], unique: true
    add_index :regions, [:country_id, :name]
  end
end
