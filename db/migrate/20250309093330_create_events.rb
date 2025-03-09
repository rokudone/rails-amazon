class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :events do |t|
      t.string :name, null: false
      t.text :description
      t.datetime :start_date, null: false
      t.datetime :end_date, null: false
      t.boolean :is_active, default: true
      t.string :event_type # sale, promotion, holiday, product_launch, etc.
      t.string :banner_image_url
      t.string :landing_page_url
      t.boolean :is_featured, default: false
      t.integer :priority, default: 0
      t.references :campaign, foreign_key: true
      t.references :promotion, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :status # scheduled, active, completed, cancelled
      t.jsonb :metadata
      t.boolean :is_recurring, default: false
      t.string :recurrence_pattern
      t.string :timezone, default: 'Asia/Tokyo'

      t.timestamps
    end

    add_index :events, [:start_date, :end_date]
    add_index :events, :event_type
  end
end
