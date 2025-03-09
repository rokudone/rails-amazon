class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :payment_method, foreign_key: true
      t.string :payment_provider # 'stripe', 'paypal', 'amazon_pay', 'credit_card', 'bank_transfer'
      t.string :payment_type # 'full', 'partial', 'installment', 'refund'
      t.string :transaction_id
      t.string :authorization_code
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :currency, default: 'USD'
      t.string :status, default: 'pending' # 'pending', 'processing', 'completed', 'failed', 'refunded', 'cancelled'
      t.datetime :payment_date
      t.text :error_message
      t.string :card_type
      t.string :last_four_digits
      t.string :cardholder_name
      t.integer :expiry_month
      t.integer :expiry_year
      t.string :billing_address_line1
      t.string :billing_address_line2
      t.string :billing_city
      t.string :billing_state
      t.string :billing_postal_code
      t.string :billing_country
      t.string :billing_phone
      t.string :billing_email
      t.boolean :is_default, default: false
      t.boolean :save_payment_method, default: false
      t.string :customer_ip
      t.string :user_agent
      t.jsonb :metadata
      t.text :notes

      t.timestamps
    end

    add_index :payments, :transaction_id, unique: true
    add_index :payments, :authorization_code
    add_index :payments, :status
    add_index :payments, :payment_date
    add_index :payments, :payment_provider
    add_index :payments, :payment_type
  end
end
