class CreateSellerTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :seller_transactions do |t|
      t.references :seller, null: false, foreign_key: true
      t.references :order, foreign_key: true
      t.string :transaction_type # sale, refund, fee, payout, adjustment, etc.
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :fee_amount, precision: 10, scale: 2, default: 0
      t.decimal :tax_amount, precision: 10, scale: 2, default: 0
      t.decimal :net_amount, precision: 10, scale: 2, null: false
      t.string :currency, default: 'JPY'
      t.string :status # pending, completed, failed, cancelled
      t.string :payment_method
      t.string :reference_number
      t.text :description
      t.jsonb :metadata
      t.datetime :processed_at

      t.timestamps
    end

    add_index :seller_transactions, :reference_number, unique: true
  end
end
