class CreatePromotionRules < ActiveRecord::Migration[7.1]
  def change
    create_table :promotion_rules do |t|
      t.references :promotion, null: false, foreign_key: true
      t.string :rule_type # product, category, customer, cart_quantity, etc.
      t.string :operator # equal, not_equal, greater_than, etc.
      t.text :value
      t.boolean :is_mandatory, default: true
      t.integer :position, default: 0
      t.text :error_message
      t.jsonb :conditions # 複雑なルール条件を格納するためのJSON

      t.timestamps
    end
  end
end
