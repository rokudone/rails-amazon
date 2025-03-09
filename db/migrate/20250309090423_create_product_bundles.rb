class CreateProductBundles < ActiveRecord::Migration[7.1]
  def change
    create_table :product_bundles do |t|
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.decimal :discount_percentage, precision: 5, scale: 2
      t.datetime :start_date
      t.datetime :end_date
      t.boolean :is_active, default: true

      t.timestamps
    end
    add_index :product_bundles, :name
  end
end
