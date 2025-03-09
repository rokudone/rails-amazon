class SellerPerformance < ApplicationRecord
  # 関連付け
  belongs_to :seller

  # バリデーション
  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :seller_id, uniqueness: { scope: [:period_start, :period_end], message: "この期間のパフォーマンスレポートはすでに存在します" }
  validate :period_end_after_period_start

  # スコープ
  scope :current_month, -> { where(period_start: Time.current.beginning_of_month, period_end: Time.current.end_of_month) }
  scope :previous_month, -> { where(period_start: 1.month.ago.beginning_of_month, period_end: 1.month.ago.end_of_month) }
  scope :last_three_months, -> { where('period_start >= ?', 3.months.ago.beginning_of_month) }
  scope :last_six_months, -> { where('period_start >= ?', 6.months.ago.beginning_of_month) }
  scope :last_year, -> { where('period_start >= ?', 1.year.ago.beginning_of_month) }
  scope :by_performance_status, ->(status) { where(performance_status: status) }
  scope :at_risk, -> { where(performance_status: 'at_risk') }
  scope :excellent, -> { where(performance_status: 'excellent') }
  scope :eligible_for_featured, -> { where(is_eligible_for_featured: true) }
  scope :eligible_for_prime, -> { where(is_eligible_for_prime: true) }
  scope :recent, -> { order(period_end: :desc) }

  # カスタムメソッド
  def calculate_metrics!
    # 注文数
    self.orders_count = count_orders

    # キャンセル率
    self.cancelled_orders_count = count_cancelled_orders
    self.cancellation_rate = calculate_rate(cancelled_orders_count, orders_count)

    # 遅延発送率
    self.late_shipments_count = count_late_shipments
    self.late_shipment_rate = calculate_rate(late_shipments_count, orders_count)

    # 返品率
    self.returns_count = count_returns
    self.return_rate = calculate_rate(returns_count, orders_count)

    # 評価
    rating_data = calculate_ratings
    self.average_rating = rating_data[:average]
    self.ratings_count = rating_data[:count]

    # ネガティブフィードバック
    self.negative_feedback_count = count_negative_feedback
    self.negative_feedback_rate = calculate_rate(negative_feedback_count, ratings_count)

    # 売上と利益
    financial_data = calculate_financials
    self.total_sales = financial_data[:sales]
    self.total_fees = financial_data[:fees]
    self.total_profit = financial_data[:profit]

    # パフォーマンスステータスの計算
    calculate_performance_status

    # 特典資格の計算
    calculate_eligibility

    save
  end

  def performance_status_name
    case performance_status
    when 'excellent'
      '優秀'
    when 'good'
      '良好'
    when 'fair'
      '普通'
    when 'poor'
      '不良'
    when 'at_risk'
      '危険'
    else
      performance_status.humanize
    end
  end

  def period_name
    "#{period_start.strftime('%Y年%m月%d日')} 〜 #{period_end.strftime('%Y年%m月%d日')}"
  end

  def month_year
    period_start.strftime('%Y年%m月')
  end

  def improvement_suggestions_list
    return [] if improvement_suggestions.blank?

    improvement_suggestions.split("\n").map(&:strip).reject(&:blank?)
  end

  def metrics_improved_from_previous?
    previous = seller.seller_performances.where('period_end < ?', period_start).order(period_end: :desc).first
    return false if previous.nil?

    # 主要指標の改善をチェック
    cancellation_rate <= previous.cancellation_rate &&
    late_shipment_rate <= previous.late_shipment_rate &&
    return_rate <= previous.return_rate &&
    average_rating >= previous.average_rating
  end

  def metrics_summary
    {
      orders: orders_count,
      cancellation_rate: "#{cancellation_rate}%",
      late_shipment_rate: "#{late_shipment_rate}%",
      return_rate: "#{return_rate}%",
      average_rating: average_rating,
      total_sales: total_sales
    }
  end

  private

  def period_end_after_period_start
    return if period_end.blank? || period_start.blank?

    if period_end < period_start
      errors.add(:period_end, "は開始日より後の日付にしてください")
    end
  end

  def calculate_rate(numerator, denominator)
    return 0 if denominator.nil? || denominator.zero?
    ((numerator.to_f / denominator) * 100).round(2)
  end

  def count_orders
    seller.orders.where(created_at: period_start..period_end).count
  end

  def count_cancelled_orders
    seller.orders.where(created_at: period_start..period_end, status: 'cancelled').count
  end

  def count_late_shipments
    # 遅延発送の定義に基づいて実装（実装は別途必要）
    0
  end

  def count_returns
    seller.returns.where(created_at: period_start..period_end).count
  end

  def calculate_ratings
    ratings = seller.seller_ratings.where(created_at: period_start..period_end)
    {
      average: ratings.average(:rating).to_f.round(2),
      count: ratings.count
    }
  end

  def count_negative_feedback
    seller.seller_ratings.where(created_at: period_start..period_end, rating: 1..2).count
  end

  def calculate_financials
    transactions = seller.seller_transactions.where(created_at: period_start..period_end, status: 'completed')

    sales = transactions.where(transaction_type: 'sale').sum(:amount)
    fees = transactions.where(transaction_type: 'fee').sum(:amount)
    profit = sales - fees

    {
      sales: sales,
      fees: fees,
      profit: profit
    }
  end

  def calculate_performance_status
    # パフォーマンスステータスの計算ロジック（実装は別途必要）
    # 各指標に基づいてステータスを決定

    if cancellation_rate > 10 || late_shipment_rate > 15 || return_rate > 20 || average_rating < 3.0
      self.performance_status = 'at_risk'
    elsif cancellation_rate > 5 || late_shipment_rate > 10 || return_rate > 15 || average_rating < 3.5
      self.performance_status = 'poor'
    elsif cancellation_rate > 3 || late_shipment_rate > 5 || return_rate > 10 || average_rating < 4.0
      self.performance_status = 'fair'
    elsif cancellation_rate > 1 || late_shipment_rate > 2 || return_rate > 5 || average_rating < 4.5
      self.performance_status = 'good'
    else
      self.performance_status = 'excellent'
    end

    # 改善提案の生成
    generate_improvement_suggestions
  end

  def calculate_eligibility
    # 特典資格の計算ロジック
    self.is_eligible_for_featured = ['excellent', 'good'].include?(performance_status)
    self.is_eligible_for_prime = ['excellent', 'good', 'fair'].include?(performance_status) &&
                                late_shipment_rate < 5 &&
                                cancellation_rate < 3
  end

  def generate_improvement_suggestions
    suggestions = []

    if cancellation_rate > 3
      suggestions << "キャンセル率が高いです。商品説明を詳細にして、顧客の期待値を適切に設定しましょう。"
    end

    if late_shipment_rate > 2
      suggestions << "発送の遅延が見られます。在庫管理と出荷プロセスを見直しましょう。"
    end

    if return_rate > 5
      suggestions << "返品率が高いです。商品の品質と梱包方法を確認しましょう。"
    end

    if average_rating < 4.0
      suggestions << "評価が低めです。顧客サービスを向上させ、フィードバックに迅速に対応しましょう。"
    end

    if negative_feedback_rate > 10
      suggestions << "ネガティブなフィードバックが多いです。顧客の不満点を特定し、改善しましょう。"
    end

    self.improvement_suggestions = suggestions.join("\n")
  end
end
