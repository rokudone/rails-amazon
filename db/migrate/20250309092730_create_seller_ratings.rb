class CreateSellerRatings < ActiveRecord::Migration[7.1]
  def change
    create_table :seller_ratings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :seller, null: false, foreign_key: true
      t.references :order, foreign_key: true
      t.integer :rating, null: false
      t.text :comment
      t.string :dimension # shipping_speed, product_quality, customer_service, etc.
      t.boolean :is_verified_purchase, default: false
      t.boolean :is_anonymous, default: false
      t.boolean :is_approved, default: false
      t.datetime :approved_at
      t.integer :helpful_votes_count, default: 0
      t.integer :unhelpful_votes_count, default: 0
      t.boolean :is_featured, default: false
      t.string :status, default: 'pending' # pending, approved, rejected

      t.timestamps
    end

    add_index :seller_ratings, [:user_id, :seller_id, :dimension], unique: true
  end
end
