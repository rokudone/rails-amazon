class CreateWishlists < ActiveRecord::Migration[7.1]
  def change
    create_table :wishlists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, default: 'My Wishlist'
      t.text :description
      t.boolean :is_public, default: false
      t.boolean :is_default, default: false
      t.string :sharing_token
      t.integer :items_count, default: 0
      t.datetime :last_modified_at
      t.string :occasion # birthday, wedding, holiday, etc.
      t.datetime :occasion_date
      t.string :status, default: 'active' # active, archived, deleted

      t.timestamps
    end

    add_index :wishlists, [:user_id, :is_default]
    add_index :wishlists, :sharing_token, unique: true

    create_table :wishlist_items do |t|
      t.references :wishlist, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, default: 1
      t.integer :priority, default: 0 # 0: normal, 1: high, 2: highest
      t.text :note
      t.boolean :is_purchased, default: false
      t.references :purchased_by, foreign_key: { to_table: :users }
      t.datetime :purchased_at
      t.datetime :added_at
      t.boolean :notify_on_price_drop, default: false
      t.decimal :price_at_addition, precision: 10, scale: 2

      t.timestamps
    end

    add_index :wishlist_items, [:wishlist_id, :product_id], unique: true
  end
end
