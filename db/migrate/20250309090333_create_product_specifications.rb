class CreateProductSpecifications < ActiveRecord::Migration[7.1]
  def change
    create_table :product_specifications do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false
      t.string :value, null: false
      t.string :unit
      t.integer :position, default: 0

      t.timestamps
    end
    add_index :product_specifications, [:product_id, :name], name: 'index_product_specifications_on_product_id_and_name'
  end
end
