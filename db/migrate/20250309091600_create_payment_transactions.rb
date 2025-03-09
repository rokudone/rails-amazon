class CreatePaymentTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :payment_transactions do |t|
      t.references :payment, null: false, foreign_key: true
      t.references :order, foreign_key: true
      t.string :transaction_type, null: false # 'authorization', 'capture', 'sale', 'refund', 'void'
      t.string :transaction_id, null: false
      t.string :reference_id
      t.string :gateway_response_code
      t.text :gateway_response_message
      t.jsonb :gateway_response_data
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :currency, default: 'USD'
      t.string :status, null: false # 'pending', 'success', 'failed', 'processing'
      t.datetime :transaction_date, null: false
      t.string :payment_provider # 'stripe', 'paypal', 'amazon_pay', 'credit_card', 'bank_transfer'
      t.string :payment_method_details
      t.string :error_code
      t.text :error_description
      t.boolean :is_test_transaction, default: false
      t.string :processor_id
      t.string :authorization_code
      t.integer :response_time_ms
      t.string :ip_address
      t.string :user_agent
      t.text :notes
      t.string :created_by
      t.jsonb :metadata

      t.timestamps
    end

    add_index :payment_transactions, :transaction_id, unique: true
    add_index :payment_transactions, :reference_id
    add_index :payment_transactions, :transaction_type
    add_index :payment_transactions, :status
    add_index :payment_transactions, :transaction_date
    add_index :payment_transactions, :payment_provider
  end
end
