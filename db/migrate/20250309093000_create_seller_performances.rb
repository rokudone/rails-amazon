class CreateSellerPerformances < ActiveRecord::Migration[7.1]
  def change
    create_table :seller_performances do |t|
      t.references :seller, null: false, foreign_key: true
      t.datetime :period_start
      t.datetime :period_end
      t.integer :orders_count, default: 0
      t.integer :cancelled_orders_count, default: 0
      t.decimal :cancellation_rate, precision: 5, scale: 2, default: 0
      t.integer :late_shipments_count, default: 0
      t.decimal :late_shipment_rate, precision: 5, scale: 2, default: 0
      t.integer :returns_count, default: 0
      t.decimal :return_rate, precision: 5, scale: 2, default: 0
      t.decimal :average_rating, precision: 3, scale: 2
      t.integer :ratings_count, default: 0
      t.integer :negative_feedback_count, default: 0
      t.decimal :negative_feedback_rate, precision: 5, scale: 2, default: 0
      t.decimal :total_sales, precision: 12, scale: 2, default: 0
      t.decimal :total_fees, precision: 12, scale: 2, default: 0
      t.decimal :total_profit, precision: 12, scale: 2, default: 0
      t.string :performance_status # excellent, good, fair, poor, at_risk
      t.text :improvement_suggestions
      t.boolean :is_eligible_for_featured, default: true
      t.boolean :is_eligible_for_prime, default: true

      t.timestamps
    end

    add_index :seller_performances, [:seller_id, :period_start, :period_end], unique: true, name: 'index_seller_performances_on_seller_and_period'
  end
end
