class CreateUserRewards < ActiveRecord::Migration[7.1]
  def change
    create_table :user_rewards do |t|
      t.references :user, null: false, foreign_key: true
      t.string :reward_type
      t.string :status, default: 'active'
      t.integer :points
      t.decimal :amount, precision: 10, scale: 2
      t.string :code
      t.text :description
      t.datetime :issued_at
      t.datetime :expires_at
      t.datetime :redeemed_at
      t.text :redemption_details

      t.timestamps
    end
  end
end
