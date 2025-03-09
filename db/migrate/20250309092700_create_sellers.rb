class CreateSellers < ActiveRecord::Migration[7.1]
  def change
    create_table :sellers do |t|
      t.references :user, null: false, foreign_key: true
      t.string :company_name, null: false
      t.string :legal_name
      t.string :tax_identifier
      t.string :business_type # individual, corporation, partnership, etc.
      t.text :description
      t.string :logo_url
      t.string :website_url
      t.string :contact_email, null: false
      t.string :contact_phone
      t.string :status, default: 'pending' # pending, approved, suspended, rejected
      t.datetime :approved_at
      t.references :approved_by, foreign_key: { to_table: :users }
      t.boolean :is_featured, default: false
      t.boolean :is_verified, default: false
      t.datetime :verified_at
      t.integer :products_count, default: 0
      t.decimal :average_rating, precision: 3, scale: 2
      t.integer :ratings_count, default: 0
      t.datetime :last_active_at
      t.string :store_url
      t.boolean :accepts_returns, default: true
      t.integer :return_period_days, default: 30

      t.timestamps
    end

    add_index :sellers, :company_name
    add_index :sellers, :tax_identifier, unique: true
  end
end
