class CreateReferralPrograms < ActiveRecord::Migration[7.1]
  def change
    create_table :referral_programs do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :is_active, default: true
      t.datetime :start_date
      t.datetime :end_date
      t.string :reward_type # discount, credit, gift_card, etc.
      t.decimal :referrer_reward_amount, precision: 10, scale: 2
      t.decimal :referee_reward_amount, precision: 10, scale: 2
      t.integer :usage_limit_per_user
      t.integer :usage_limit_total
      t.integer :usage_count, default: 0
      t.text :terms_and_conditions
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :status # active, inactive, pending_approval
      t.integer :referral_count, default: 0
      t.decimal :total_rewards_given, precision: 10, scale: 2, default: 0
      t.integer :conversion_rate, default: 0
      t.string :code_prefix

      t.timestamps
    end
  end
end
