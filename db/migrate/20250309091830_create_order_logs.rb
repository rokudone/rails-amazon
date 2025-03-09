class CreateOrderLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :order_logs do |t|
      t.references :order, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :action, null: false # 'created', 'updated', 'status_changed', 'payment_received', 'shipped', 'delivered', 'cancelled', 'refunded'
      t.string :previous_status
      t.string :new_status
      t.text :message
      t.jsonb :data_changes
      t.string :ip_address
      t.string :user_agent
      t.string :source # 'system', 'admin', 'customer', 'api'
      t.string :reference_id
      t.string :reference_type # 'payment', 'shipment', 'return', 'invoice'
      t.text :notes
      t.boolean :is_customer_visible, default: false
      t.boolean :is_notification_sent, default: false
      t.datetime :notification_sent_at
      t.string :notification_type # 'email', 'sms', 'push', 'in_app'

      t.timestamps
    end

    add_index :order_logs, :action
    add_index :order_logs, :created_at
    add_index :order_logs, :source
    add_index :order_logs, [:reference_type, :reference_id]
    add_index :order_logs, :is_customer_visible
  end
end
