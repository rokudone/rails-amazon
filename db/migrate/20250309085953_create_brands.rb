class CreateBrands < ActiveRecord::Migration[7.1]
  def change
    create_table :brands do |t|
      t.string :name, null: false
      t.text :description
      t.string :logo
      t.string :website
      t.string :country_of_origin
      t.integer :year_established
      t.boolean :is_active, default: true

      t.timestamps
    end
    add_index :brands, :name
  end
end
