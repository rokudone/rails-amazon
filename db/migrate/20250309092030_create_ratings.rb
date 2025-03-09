class CreateRatings < ActiveRecord::Migration[7.1]
  def change
    create_table :ratings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :value, null: false
      t.string :dimension # 例: 品質、価格、配送など
      t.text :comment
      t.boolean :is_anonymous, default: false

      t.timestamps
    end

    add_index :ratings, [:user_id, :product_id, :dimension], unique: true
  end
end
