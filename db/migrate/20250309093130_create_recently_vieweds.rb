class CreateRecentlyVieweds < ActiveRecord::Migration[7.1]
  def change
    create_table :recently_vieweds do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :view_count, default: 1
      t.datetime :last_viewed_at
      t.float :view_duration # in seconds
      t.string :source # search, recommendation, category, direct, etc.
      t.string :device_type # desktop, mobile, tablet, etc.
      t.string :session_id
      t.boolean :added_to_cart, default: false
      t.boolean :added_to_wishlist, default: false
      t.boolean :purchased, default: false

      t.timestamps
    end

    add_index :recently_vieweds, [:user_id, :product_id], unique: true
    add_index :recently_vieweds, [:user_id, :last_viewed_at]
  end
end
