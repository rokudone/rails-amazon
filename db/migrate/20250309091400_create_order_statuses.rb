class CreateOrderStatuses < ActiveRecord::Migration[7.0]
  def change
    create_table :order_statuses do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.text :description
      t.integer :display_order
      t.string :color_code
      t.boolean :is_active, default: true
      t.boolean :is_default, default: false
      t.boolean :is_cancellable, default: true
      t.boolean :is_returnable, default: false
      t.boolean :requires_shipping, default: true
      t.boolean :requires_payment, default: true
      t.string :email_template
      t.string :sms_template
      t.string :notification_message

      t.timestamps
    end

    add_index :order_statuses, :code, unique: true
    add_index :order_statuses, :name, unique: true
    add_index :order_statuses, :is_active
    add_index :order_statuses, :is_default
    add_index :order_statuses, :display_order
  end
end
