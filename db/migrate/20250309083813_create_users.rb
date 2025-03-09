class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :first_name
      t.string :last_name
      t.string :phone_number
      t.boolean :active, default: true
      t.datetime :last_login_at
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.integer :failed_attempts, default: 0
      t.datetime :locked_at

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
