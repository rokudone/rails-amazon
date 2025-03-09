class CreateStockMovements < ActiveRecord::Migration[7.0]
  def change
    create_table :stock_movements do |t|
      t.references :inventory, null: false, foreign_key: true
      t.references :source_warehouse, foreign_key: { to_table: :warehouses }
      t.references :destination_warehouse, foreign_key: { to_table: :warehouses }
      t.integer :quantity, null: false
      t.string :movement_type, null: false # 'inbound', 'outbound', 'transfer', 'return', 'adjustment', 'disposal'
      t.string :reference_number
      t.references :order, foreign_key: true
      t.references :supplier_order, foreign_key: true
      t.references :return, foreign_key: true
      t.text :reason
      t.string :status, default: 'pending' # 'pending', 'in_progress', 'completed', 'cancelled'
      t.datetime :completed_at
      t.string :created_by
      t.string :approved_by
      t.decimal :unit_cost, precision: 10, scale: 2
      t.decimal :total_cost, precision: 10, scale: 2
      t.string :batch_number
      t.date :expiry_date

      t.timestamps
    end

    add_index :stock_movements, :movement_type
    add_index :stock_movements, :reference_number
    add_index :stock_movements, :status
    add_index :stock_movements, :completed_at
  end
end
