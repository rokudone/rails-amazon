class CreateProductBundleItems < ActiveRecord::Migration[7.1]
  def change
    create_table :product_bundle_items do |t|
      t.references :product_bundle, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end
    add_index :product_bundle_items, [:product_bundle_id, :product_id], unique: true, name: 'index_product_bundle_items_on_bundle_and_product'
  end
end
