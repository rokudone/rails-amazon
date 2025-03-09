class CreateSearchHistories < ActiveRecord::Migration[7.1]
  def change
    create_table :search_histories do |t|
      t.references :user, foreign_key: true
      t.string :query, null: false
      t.string :filters
      t.string :sort_by
      t.integer :results_count
      t.boolean :has_clicked_result, default: false
      t.integer :position_clicked
      t.references :product_clicked, foreign_key: { to_table: :products }
      t.string :category_path
      t.string :device_type # desktop, mobile, tablet, etc.
      t.string :browser
      t.string :ip_address
      t.string :session_id
      t.float :search_duration # in seconds
      t.boolean :is_voice_search, default: false
      t.boolean :is_image_search, default: false
      t.boolean :is_autocomplete, default: false

      t.timestamps
    end

    add_index :search_histories, [:user_id, :created_at]
    add_index :search_histories, :query
  end
end
