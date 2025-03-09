class CreateSellerPolicies < ActiveRecord::Migration[7.1]
  def change
    create_table :seller_policies do |t|
      t.references :seller, null: false, foreign_key: true
      t.string :policy_type # return, shipping, privacy, terms, etc.
      t.text :content, null: false
      t.boolean :is_active, default: true
      t.datetime :effective_date
      t.datetime :last_updated_at
      t.references :updated_by, foreign_key: { to_table: :users }
      t.boolean :is_approved, default: false
      t.datetime :approved_at
      t.references :approved_by, foreign_key: { to_table: :users }
      t.text :approval_notes
      t.string :version

      t.timestamps
    end

    add_index :seller_policies, [:seller_id, :policy_type], unique: true
  end
end
