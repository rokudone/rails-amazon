class CreateProductVariants < ActiveRecord::Migration[7.1]
  def change
    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :sku, null: false
      t.string :name
      t.decimal :price, precision: 10, scale: 2
      t.decimal :compare_at_price, precision: 10, scale: 2
      t.string :color
      t.string :size
      t.string :material
      t.string :style
      t.decimal :weight, precision: 8, scale: 2
      t.boolean :is_active, default: true

      t.timestamps
    end
    add_index :product_variants, :sku, unique: true
  end
end
