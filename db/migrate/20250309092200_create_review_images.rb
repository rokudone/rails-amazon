class CreateReviewImages < ActiveRecord::Migration[7.1]
  def change
    create_table :review_images do |t|
      t.references :review, null: false, foreign_key: true
      t.string :image_url, null: false
      t.string :alt_text
      t.integer :position, default: 0
      t.boolean :is_approved, default: false
      t.datetime :approved_at
      t.string :status, default: 'pending' # pending, approved, rejected
      t.string :content_type
      t.integer :file_size

      t.timestamps
    end
  end
end
