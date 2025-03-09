class CreateSubCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :sub_categories do |t|
      t.references :category, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :position
      t.string :slug, null: false
      t.boolean :is_active, default: true

      t.timestamps
    end
    add_index :sub_categories, :name
    add_index :sub_categories, :slug, unique: true
  end
end
