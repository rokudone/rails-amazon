class CreateReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :title
      t.text :content, null: false
      t.integer :rating, null: false
      t.boolean :verified_purchase, default: false
      t.boolean :is_approved, default: false
      t.datetime :approved_at
      t.integer :helpful_votes_count, default: 0
      t.integer :unhelpful_votes_count, default: 0
      t.boolean :is_featured, default: false
      t.boolean :contains_spoiler, default: false
      t.string :status, default: 'pending' # pending, approved, rejected

      t.timestamps
    end

    add_index :reviews, [:user_id, :product_id], unique: true
  end
end
