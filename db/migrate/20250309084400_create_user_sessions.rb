class CreateUserSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :session_token, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :last_activity_at
      t.datetime :expires_at
      t.boolean :is_active, default: true

      t.timestamps
    end
    add_index :user_sessions, :session_token, unique: true
  end
end
