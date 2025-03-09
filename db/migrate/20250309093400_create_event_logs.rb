class CreateEventLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :event_logs do |t|
      t.string :event_name, null: false
      t.string :event_type # system, user, error, security, etc.
      t.references :user, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.string :session_id
      t.string :request_method
      t.string :request_path
      t.jsonb :request_params
      t.integer :response_status
      t.text :details
      t.references :loggable, polymorphic: true
      t.string :severity # info, warning, error, critical
      t.float :duration # in milliseconds
      t.boolean :is_success, default: true
      t.string :source # web, api, admin, background_job, etc.
      t.string :browser
      t.string :device_type # desktop, mobile, tablet, etc.
      t.string :operating_system

      t.timestamps
    end

    add_index :event_logs, :event_name
    add_index :event_logs, :event_type
    add_index :event_logs, :created_at
    add_index :event_logs, [:loggable_type, :loggable_id]
  end
end
