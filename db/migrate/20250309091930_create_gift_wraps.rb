class CreateGiftWraps < ActiveRecord::Migration[7.0]
  def change
    create_table :gift_wraps do |t|
      t.references :order, null: false, foreign_key: true
      t.references :order_item, foreign_key: true
      t.string :wrap_type # 'standard', 'premium', 'luxury', 'eco_friendly', 'seasonal'
      t.string :wrap_color
      t.string :wrap_pattern
      t.string :ribbon_type
      t.string :ribbon_color
      t.boolean :include_gift_box, default: false
      t.boolean :include_gift_receipt, default: true
      t.boolean :hide_prices, default: true
      t.text :gift_message
      t.string :gift_from
      t.string :gift_to
      t.decimal :wrap_cost, precision: 8, scale: 2, default: 0
      t.string :special_instructions
      t.boolean :is_gift_wrapped, default: false
      t.string :wrapped_by
      t.datetime :wrapped_at
      t.string :gift_wrap_image_url
      t.jsonb :options # Additional customization options
      t.boolean :is_reusable_packaging, default: false
      t.string :packaging_type
      t.text :notes

      t.timestamps
    end

    add_index :gift_wraps, :wrap_type
    add_index :gift_wraps, :is_gift_wrapped
  end
end
