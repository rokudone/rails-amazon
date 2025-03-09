class CreateUserSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :user_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :subscription_type, null: false
      t.string :status, default: 'active'
      t.datetime :start_date
      t.datetime :end_date
      t.decimal :amount, precision: 10, scale: 2
      t.string :billing_period
      t.string :payment_method_id
      t.datetime :last_payment_date
      t.datetime :next_payment_date
      t.boolean :auto_renew, default: true

      t.timestamps
    end
  end
end
