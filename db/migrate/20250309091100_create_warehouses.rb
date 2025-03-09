class CreateWarehouses < ActiveRecord::Migration[7.0]
  def change
    create_table :warehouses do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.text :address, null: false
      t.string :city, null: false
      t.string :state
      t.string :postal_code, null: false
      t.string :country, null: false
      t.string :phone
      t.string :email
      t.float :latitude
      t.float :longitude
      t.boolean :active, default: true
      t.integer :capacity
      t.string :warehouse_type
      t.text :description
      t.string :manager_name

      t.timestamps
    end

    add_index :warehouses, :code, unique: true
    add_index :warehouses, :name
    add_index :warehouses, :active
  end
end
