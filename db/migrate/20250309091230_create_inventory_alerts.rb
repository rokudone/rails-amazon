class CreateInventoryAlerts < ActiveRecord::Migration[7.0]
  def change
    create_table :inventory_alerts do |t|
      t.references :inventory, null: false, foreign_key: true
      t.references :product, foreign_key: true
      t.references :warehouse, foreign_key: true
      t.string :alert_type, null: false # 'low_stock', 'overstock', 'expiry', 'no_movement'
      t.integer :threshold_value
      t.boolean :active, default: true
      t.string :notification_method # 'email', 'sms', 'dashboard', 'all'
      t.string :notification_recipients
      t.text :message_template
      t.integer :frequency_days, default: 1 # How often to send the alert
      t.datetime :last_triggered_at
      t.integer :trigger_count, default: 0
      t.boolean :auto_reorder, default: false
      t.integer :auto_reorder_quantity
      t.string :severity, default: 'medium' # 'low', 'medium', 'high', 'critical'

      t.timestamps
    end

    add_index :inventory_alerts, :alert_type
    add_index :inventory_alerts, :active
    add_index :inventory_alerts, :severity
    add_index :inventory_alerts, :last_triggered_at
  end
end
