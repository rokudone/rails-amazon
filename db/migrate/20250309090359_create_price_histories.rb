class CreatePriceHistories < ActiveRecord::Migration[7.1]
  def change
    create_table :price_histories do |t|
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.decimal :old_price, precision: 10, scale: 2, null: false
      t.decimal :new_price, precision: 10, scale: 2, null: false
      t.string :reason

      t.timestamps
    end
  end
end
