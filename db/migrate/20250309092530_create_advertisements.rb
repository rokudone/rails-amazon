class CreateAdvertisements < ActiveRecord::Migration[7.1]
  def change
    create_table :advertisements do |t|
      t.string :name, null: false
      t.text :description
      t.datetime :start_date, null: false
      t.datetime :end_date, null: false
      t.boolean :is_active, default: true
      t.string :ad_type # banner, sidebar, popup, sponsored_product, etc.
      t.string :image_url
      t.string :target_url
      t.string :placement # home_page, product_page, search_results, etc.
      t.decimal :budget, precision: 10, scale: 2
      t.decimal :spent_amount, precision: 10, scale: 2, default: 0
      t.decimal :cost_per_click, precision: 10, scale: 4
      t.integer :impressions_count, default: 0
      t.integer :clicks_count, default: 0
      t.decimal :click_through_rate, precision: 5, scale: 2, default: 0
      t.references :campaign, foreign_key: true
      t.references :product, foreign_key: true
      t.references :category, foreign_key: true
      t.references :seller, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.jsonb :targeting_criteria
      t.string :status # draft, scheduled, active, completed, cancelled

      t.timestamps
    end
  end
end
