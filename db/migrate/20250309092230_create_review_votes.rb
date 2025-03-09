class CreateReviewVotes < ActiveRecord::Migration[7.1]
  def change
    create_table :review_votes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :review, null: false, foreign_key: true
      t.boolean :is_helpful, null: false
      t.text :reason
      t.boolean :is_reported, default: false
      t.string :report_reason

      t.timestamps
    end

    add_index :review_votes, [:user_id, :review_id], unique: true
  end
end
