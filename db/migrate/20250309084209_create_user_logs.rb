class CreateUserLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :user_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.string :ip_address
      t.string :user_agent
      t.text :details

      t.timestamps
    end
  end
end
