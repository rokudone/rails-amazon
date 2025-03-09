class CreateSystemConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :system_configs do |t|
      t.string :key, null: false
      t.text :value
      t.string :value_type # string, integer, float, boolean, json, etc.
      t.string :group # general, payment, shipping, email, etc.
      t.text :description
      t.boolean :is_editable, default: true
      t.boolean :is_visible, default: true
      t.references :updated_by, foreign_key: { to_table: :users }
      t.datetime :last_updated_at
      t.jsonb :options # 選択肢がある場合の選択肢リスト
      t.string :validation_rules
      t.boolean :requires_restart, default: false
      t.boolean :is_encrypted, default: false
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :system_configs, :key, unique: true
    add_index :system_configs, :group
  end
end
