class Campaign < ApplicationRecord
  # 関連付け
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :promotion, optional: true
  has_many :advertisements, dependent: :nullify

  # バリデーション
  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :campaign_type, presence: true
  validates :budget, numericality: { greater_than: 0 }, allow_nil: true
  validates :spent_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :tracking_code, uniqueness: true, allow_blank: true
  validate :end_date_after_start_date
  validate :spent_amount_not_exceeding_budget

  # コールバック
  before_validation :generate_tracking_code, if: -> { tracking_code.blank? }
  before_save :set_status

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :current, -> { where('start_date <= ? AND end_date >= ?', Time.current, Time.current) }
  scope :upcoming, -> { where('start_date > ?', Time.current) }
  scope :expired, -> { where('end_date < ?', Time.current) }
  scope :by_type, ->(type) { where(campaign_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :featured, -> { where(is_featured: true) }
  scope :by_target_audience, ->(audience) { where(target_audience: audience) }
  scope :within_budget, -> { where('budget > spent_amount OR budget IS NULL') }

  # カスタムメソッド
  def active?
    is_active && current? && within_budget?
  end

  def current?
    start_date <= Time.current && end_date >= Time.current
  end

  def upcoming?
    start_date > Time.current
  end

  def expired?
    end_date < Time.current
  end

  def within_budget?
    budget.nil? || spent_amount < budget
  end

  def budget_percentage_used
    return 0 if budget.nil? || budget.zero?
    ((spent_amount / budget) * 100).round(1)
  end

  def remaining_budget
    return nil if budget.nil?
    [budget - spent_amount, 0].max
  end

  def activate!
    update(is_active: true)
  end

  def deactivate!
    update(is_active: false)
  end

  def feature!
    update(is_featured: true)
  end

  def unfeature!
    update(is_featured: false)
  end

  def record_expense!(amount)
    increment!(:spent_amount, amount)
  end

  def days_remaining
    return 0 if expired?
    (end_date.to_date - Date.current).to_i
  end

  def days_active
    start = [start_date.to_date, Date.current].min
    finish = [end_date.to_date, Date.current].min
    (finish - start).to_i
  end

  def daily_budget
    return nil if budget.nil?
    total_days = (end_date.to_date - start_date.to_date).to_i
    return 0 if total_days.zero?
    (budget / total_days).round(2)
  end

  def daily_spent
    return 0 if days_active.zero?
    (spent_amount / days_active).round(2)
  end

  def update_results!(metrics)
    update(results: metrics.to_json)
  end

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "は開始日より後の日付にしてください")
    end
  end

  def spent_amount_not_exceeding_budget
    return if spent_amount.blank? || budget.blank?

    if spent_amount > budget
      errors.add(:spent_amount, "は予算を超えることはできません")
    end
  end

  def generate_tracking_code
    prefix = "CAM"
    self.tracking_code = "#{prefix}-#{SecureRandom.hex(4).upcase}-#{Time.current.strftime('%y%m%d')}"
  end

  def set_status
    self.status = if Time.current < start_date
                    'scheduled'
                  elsif Time.current > end_date
                    'completed'
                  elsif is_active
                    'active'
                  else
                    'cancelled'
                  end
  end
end
