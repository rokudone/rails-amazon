class CreateCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.text :description
      t.references :parent, foreign_key: { to_table: :categories }
      t.integer :position
      t.string :slug, null: false
      t.boolean :is_active, default: true

      t.timestamps
    end
    add_index :categories, :name
    add_index :categories, :slug, unique: true
  end
end
