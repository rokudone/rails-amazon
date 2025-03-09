class CreateProductVideos < ActiveRecord::Migration[7.1]
  def change
    create_table :product_videos do |t|
      t.references :product, null: false, foreign_key: true
      t.string :video_url, null: false
      t.string :thumbnail_url
      t.string :title
      t.text :description
      t.integer :position, default: 0

      t.timestamps
    end
  end
end
