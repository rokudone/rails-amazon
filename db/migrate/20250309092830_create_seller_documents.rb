class CreateSellerDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :seller_documents do |t|
      t.references :seller, null: false, foreign_key: true
      t.string :document_type # business_license, tax_certificate, identity_proof, etc.
      t.string :file_url, null: false
      t.string :file_name
      t.string :content_type
      t.integer :file_size
      t.datetime :expiry_date
      t.boolean :is_verified, default: false
      t.datetime :verified_at
      t.references :verified_by, foreign_key: { to_table: :users }
      t.text :verification_notes
      t.string :status, default: 'pending' # pending, approved, rejected
      t.text :rejection_reason
      t.boolean :is_required, default: true

      t.timestamps
    end
  end
end
