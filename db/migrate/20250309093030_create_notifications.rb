class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :notification_type # order_status, price_drop, back_in_stock, etc.
      t.string :title, null: false
      t.text :content
      t.string :icon
      t.string :url
      t.boolean :is_read, default: false
      t.datetime :read_at
      t.boolean :is_actionable, default: false
      t.string :action_text
      t.string :action_url
      t.references :notifiable, polymorphic: true
      t.datetime :expires_at
      t.integer :priority, default: 0 # 0: normal, 1: important, 2: urgent
      t.string :delivery_method # in_app, email, sms, push
      t.boolean :is_sent, default: false
      t.datetime :sent_at

      t.timestamps
    end

    add_index :notifications, [:user_id, :is_read]
    add_index :notifications, [:user_id, :created_at]
  end
end
