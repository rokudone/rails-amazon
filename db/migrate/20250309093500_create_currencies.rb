class CreateCurrencies < ActiveRecord::Migration[7.1]
  def change
    create_table :currencies do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :symbol, null: false
      t.boolean :is_active, default: true
      t.boolean :is_default, default: false
      t.integer :decimal_places, default: 2
      t.string :format # %s%v, %v %s, etc.
      t.decimal :exchange_rate_to_default, precision: 10, scale: 6, default: 1.0
      t.datetime :exchange_rate_updated_at
      t.references :updated_by, foreign_key: { to_table: :users }
      t.string :flag_image_url
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :currencies, :code, unique: true
    add_index :currencies, :is_default
  end
end
