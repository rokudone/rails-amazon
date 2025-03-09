class CreateUserPermissions < ActiveRecord::Migration[7.1]
  def change
    create_table :user_permissions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :permission_name, null: false
      t.string :resource_type
      t.integer :resource_id
      t.string :action, null: false
      t.boolean :is_allowed, default: true
      t.datetime :granted_at
      t.datetime :expires_at
      t.string :granted_by

      t.timestamps
    end
    add_index :user_permissions, [:user_id, :permission_name, :resource_type, :resource_id, :action], unique: true, name: 'index_user_permissions_on_user_and_permission'
  end
end
