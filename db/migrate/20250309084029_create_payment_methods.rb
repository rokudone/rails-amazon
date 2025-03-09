class CreatePaymentMethods < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_methods do |t|
      t.references :user, null: false, foreign_key: true
      t.string :payment_type, null: false
      t.string :provider
      t.string :account_number
      t.string :expiry_date
      t.string :name_on_card
      t.boolean :is_default, default: false

      t.timestamps
    end
  end
end
