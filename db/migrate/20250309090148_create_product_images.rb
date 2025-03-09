class CreateProductImages < ActiveRecord::Migration[7.1]
  def change
    create_table :product_images do |t|
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.string :image_url, null: false
      t.string :alt_text
      t.integer :position, default: 0
      t.boolean :is_primary, default: false

      t.timestamps
    end
  end
end
