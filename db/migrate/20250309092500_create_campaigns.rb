class CreateCampaigns < ActiveRecord::Migration[7.1]
  def change
    create_table :campaigns do |t|
      t.string :name, null: false
      t.text :description
      t.datetime :start_date, null: false
      t.datetime :end_date, null: false
      t.boolean :is_active, default: true
      t.string :campaign_type # seasonal, holiday, flash_sale, clearance, etc.
      t.decimal :budget, precision: 10, scale: 2
      t.decimal :spent_amount, precision: 10, scale: 2, default: 0
      t.string :target_audience # all, prime_members, new_customers, etc.
      t.jsonb :target_demographics
      t.string :status # draft, scheduled, active, completed, cancelled
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :promotion, foreign_key: true
      t.string :tracking_code
      t.text :success_metrics
      t.text :results
      t.boolean :is_featured, default: false
      t.string :banner_image_url
      t.string :landing_page_url

      t.timestamps
    end

    add_index :campaigns, :tracking_code, unique: true
  end
end
