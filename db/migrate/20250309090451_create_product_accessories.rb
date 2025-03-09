class CreateProductAccessories < ActiveRecord::Migration[7.1]
  def change
    create_table :product_accessories do |t|
      t.references :product, null: false, foreign_key: true
      t.references :accessory, null: false, foreign_key: { to_table: :products }
      t.boolean :is_required, default: false

      t.timestamps
    end
    add_index :product_accessories, [:product_id, :accessory_id], unique: true
  end
end
