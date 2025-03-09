class CreateUserActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :user_activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :activity_type, null: false
      t.string :action
      t.string :ip_address
      t.string :user_agent
      t.string :resource_type
      t.integer :resource_id
      t.text :details
      t.datetime :activity_time

      t.timestamps
    end
    add_index :user_activities, [:user_id, :activity_type]
    add_index :user_activities, [:resource_type, :resource_id]
  end
end
