class CreateUserDevices < ActiveRecord::Migration[7.1]
  def change
    create_table :user_devices do |t|
      t.references :user, null: false, foreign_key: true
      t.string :device_type
      t.string :device_token
      t.string :device_id, null: false
      t.string :os_type
      t.string :os_version
      t.string :app_version
      t.datetime :last_used_at
      t.boolean :is_active, default: true

      t.timestamps
    end
    add_index :user_devices, :device_id, unique: true
  end
end
