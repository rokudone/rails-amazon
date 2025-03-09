class InventoryForecast < ApplicationRecord
  # 関連付け
  belongs_to :product
  belongs_to :product_variant, optional: true
  belongs_to :warehouse, optional: true

  # バリデーション
  validates :forecast_date, presence: true
  validates :forecasted_demand, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :forecasted_supply, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :forecasted_inventory_level, numericality: { only_integer: true }, allow_nil: true
  validates :confidence_level, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :forecast_method, inclusion: { in: ['moving_average', 'exponential_smoothing', 'arima', 'machine_learning'] }, allow_nil: true
  validates :forecast_period, inclusion: { in: ['daily', 'weekly', 'monthly', 'quarterly'] }, allow_nil: true
  validates :manual_adjustment, numericality: { only_integer: true }, allow_nil: true
  validates :forecasted_revenue, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :forecasted_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :unique_forecast_date_product_warehouse_combination

  # スコープ
  scope :by_product, ->(product_id) { where(product_id: product_id) }
  scope :by_variant, ->(variant_id) { where(product_variant_id: variant_id) }
  scope :by_warehouse, ->(warehouse_id) { where(warehouse_id: warehouse_id) }
  scope :by_date_range, ->(start_date, end_date) { where(forecast_date: start_date..end_date) }
  scope :by_forecast_period, ->(period) { where(forecast_period: period) }
  scope :future, -> { where('forecast_date >= ?', Date.today) }
  scope :past, -> { where('forecast_date < ?', Date.today) }
  scope :adjusted, -> { where(is_adjusted: true) }
  scope :unadjusted, -> { where(is_adjusted: false) }
  scope :high_confidence, ->(threshold = 80) { where('confidence_level >= ?', threshold) }
  scope :low_confidence, ->(threshold = 50) { where('confidence_level < ?', threshold) }

  # カスタムメソッド
  def adjusted?
    is_adjusted
  end

  def adjust!(adjustment_value, adjusted_by_user = nil)
    self.manual_adjustment = adjustment_value
    self.is_adjusted = true
    self.adjusted_by = adjusted_by_user
    self.adjusted_at = Time.now

    # 予測在庫レベルを再計算
    if forecasted_inventory_level.present?
      self.forecasted_inventory_level += adjustment_value
    end

    save
  end

  def accuracy_against_actual(actual_demand)
    return nil if actual_demand.nil? || forecasted_demand.nil?

    error = (forecasted_demand - actual_demand).abs
    accuracy = (1 - (error.to_f / [actual_demand, 1].max)) * 100
    [accuracy, 0].max # 負の精度を0に制限
  end

  def forecast_error_against_actual(actual_demand)
    return nil if actual_demand.nil? || forecasted_demand.nil?

    forecasted_demand - actual_demand
  end

  def forecast_error_percentage(actual_demand)
    return nil if actual_demand.nil? || forecasted_demand.nil? || actual_demand.zero?

    ((forecasted_demand - actual_demand).to_f / actual_demand * 100).round(2)
  end

  def self.calculate_moving_average(product_id, warehouse_id, variant_id = nil, periods = 3)
    # 過去の需要データを取得
    conditions = { product_id: product_id }
    conditions[:warehouse_id] = warehouse_id if warehouse_id.present?
    conditions[:product_variant_id] = variant_id if variant_id.present?

    historical_data = where(conditions)
      .order(forecast_date: :desc)
      .limit(periods)
      .pluck(:forecasted_demand)

    return nil if historical_data.empty?

    # 移動平均を計算
    historical_data.sum / historical_data.size
  end

  private

  def unique_forecast_date_product_warehouse_combination
    query = InventoryForecast.where(
      forecast_date: forecast_date,
      product_id: product_id,
      warehouse_id: warehouse_id,
      product_variant_id: product_variant_id
    )

    query = query.where.not(id: id) if persisted?

    if query.exists?
      errors.add(:base, 'この日付、商品、倉庫、バリアントの組み合わせはすでに存在します')
    end
  end
end
