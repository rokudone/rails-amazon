class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.text :short_description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.string :sku, null: false
      t.string :upc
      t.string :manufacturer
      t.references :brand
      t.references :category
      t.references :seller
      t.boolean :is_active, default: true
      t.boolean :is_featured, default: false
      t.datetime :published_at

      t.timestamps
    end
    add_index :products, :sku, unique: true
  end
end
