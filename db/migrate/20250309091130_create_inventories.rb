class CreateInventories < ActiveRecord::Migration[7.0]
  def change
    create_table :inventories do |t|
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.references :warehouse, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 0
      t.integer :reserved_quantity, default: 0
      t.integer :available_quantity, default: 0
      t.integer :minimum_stock_level, default: 10
      t.integer :maximum_stock_level
      t.integer :reorder_point
      t.string :sku, null: false
      t.string :location_in_warehouse
      t.date :last_restock_date
      t.date :next_restock_date
      t.string :status, default: 'active'
      t.decimal :unit_cost, precision: 10, scale: 2
      t.string :batch_number
      t.date :expiry_date

      t.timestamps
    end

    add_index :inventories, :sku, unique: true
    add_index :inventories, :status
    add_index :inventories, [:product_id, :warehouse_id, :product_variant_id], unique: true, name: 'idx_inventory_product_warehouse_variant'
  end
end
