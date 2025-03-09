class CreateQuestions < ActiveRecord::Migration[7.1]
  def change
    create_table :questions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.text :content, null: false
      t.boolean :is_approved, default: false
      t.datetime :approved_at
      t.integer :answers_count, default: 0
      t.boolean :is_answered, default: false
      t.string :status, default: 'pending' # pending, approved, rejected
      t.boolean :is_featured, default: false
      t.integer :votes_count, default: 0

      t.timestamps
    end
  end
end
