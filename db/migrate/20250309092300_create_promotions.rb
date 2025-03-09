class CreatePromotions < ActiveRecord::Migration[7.1]
  def change
    create_table :promotions do |t|
      t.string :name, null: false
      t.text :description
      t.datetime :start_date, null: false
      t.datetime :end_date, null: false
      t.boolean :is_active, default: true
      t.string :promotion_type # percentage_discount, fixed_amount, buy_x_get_y, etc.
      t.decimal :discount_amount, precision: 10, scale: 2
      t.decimal :minimum_order_amount, precision: 10, scale: 2
      t.integer :usage_limit
      t.integer :usage_count, default: 0
      t.string :code
      t.boolean :is_public, default: true
      t.boolean :is_combinable, default: false
      t.integer :priority, default: 0
      t.references :created_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :promotions, :code, unique: true
  end
end
