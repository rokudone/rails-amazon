class CreateProductAttributes < ActiveRecord::Migration[7.1]
  def change
    create_table :product_attributes do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false
      t.string :value, null: false
      t.boolean :is_filterable, default: false
      t.boolean :is_searchable, default: false

      t.timestamps
    end
    add_index :product_attributes, [:product_id, :name], name: 'index_product_attributes_on_product_id_and_name'
  end
end
