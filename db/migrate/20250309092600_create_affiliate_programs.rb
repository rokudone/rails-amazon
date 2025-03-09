class CreateAffiliatePrograms < ActiveRecord::Migration[7.1]
  def change
    create_table :affiliate_programs do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :is_active, default: true
      t.decimal :commission_rate, precision: 5, scale: 2, null: false
      t.string :commission_type # percentage, fixed_amount
      t.decimal :minimum_payout, precision: 10, scale: 2, default: 0
      t.string :payment_method # bank_transfer, paypal, amazon_gift_card, etc.
      t.integer :cookie_days, default: 30
      t.text :terms_and_conditions
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :status # active, inactive, pending_approval
      t.jsonb :eligible_categories
      t.jsonb :eligible_products
      t.decimal :lifetime_commission_paid, precision: 10, scale: 2, default: 0
      t.integer :affiliates_count, default: 0
      t.string :tracking_code_prefix

      t.timestamps
    end
  end
end
