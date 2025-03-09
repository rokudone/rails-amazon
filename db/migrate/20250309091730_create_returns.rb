class CreateReturns < ActiveRecord::Migration[7.0]
  def change
    create_table :returns do |t|
      t.string :return_number, null: false
      t.references :order, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, default: 'requested' # 'requested', 'approved', 'received', 'inspected', 'completed', 'rejected'
      t.string :return_type # 'refund', 'exchange', 'store_credit', 'warranty'
      t.string :return_reason # 'damaged', 'defective', 'wrong_item', 'not_as_described', 'no_longer_needed'
      t.text :return_description
      t.datetime :requested_at, null: false
      t.datetime :approved_at
      t.datetime :received_at
      t.datetime :completed_at
      t.string :return_method # 'mail', 'in_store', 'pickup'
      t.string :return_carrier
      t.string :return_tracking_number
      t.string :return_label_url
      t.decimal :refund_amount, precision: 12, scale: 2
      t.string :refund_method # 'original_payment', 'store_credit', 'bank_transfer'
      t.string :refund_transaction_id
      t.datetime :refunded_at
      t.boolean :restocking_fee_applied, default: false
      t.decimal :restocking_fee_amount, precision: 10, scale: 2, default: 0
      t.boolean :return_shipping_paid_by_customer, default: false
      t.decimal :return_shipping_cost, precision: 10, scale: 2, default: 0
      t.string :exchange_order_number
      t.references :exchange_order, foreign_key: { to_table: :orders }
      t.string :rma_number
      t.string :inspector_name
      t.text :inspection_notes
      t.string :condition_on_return # 'new', 'like_new', 'used', 'damaged', 'not_usable'
      t.boolean :is_warranty_claim, default: false
      t.string :warranty_claim_number
      t.text :rejection_reason
      t.string :created_by
      t.string :approved_by
      t.jsonb :metadata

      t.timestamps
    end

    add_index :returns, :return_number, unique: true
    add_index :returns, :status
    add_index :returns, :requested_at
    add_index :returns, :return_reason
    add_index :returns, :return_type
    add_index :returns, :rma_number
    add_index :returns, :return_tracking_number
  end
end
