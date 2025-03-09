class CreateProductDescriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :product_descriptions do |t|
      t.references :product, null: false, foreign_key: true
      t.text :full_description, null: false
      t.text :features
      t.text :care_instructions
      t.text :warranty_info
      t.text :return_policy

      t.timestamps
    end
  end
end
