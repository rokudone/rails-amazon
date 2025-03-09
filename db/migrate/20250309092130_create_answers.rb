class CreateAnswers < ActiveRecord::Migration[7.1]
  def change
    create_table :answers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.text :content, null: false
      t.boolean :is_approved, default: false
      t.datetime :approved_at
      t.boolean :is_seller_answer, default: false
      t.boolean :is_amazon_answer, default: false
      t.integer :helpful_votes_count, default: 0
      t.integer :unhelpful_votes_count, default: 0
      t.string :status, default: 'pending' # pending, approved, rejected
      t.boolean :is_best_answer, default: false

      t.timestamps
    end
  end
end
