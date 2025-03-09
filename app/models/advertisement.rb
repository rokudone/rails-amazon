class Advertisement < ApplicationRecord
  # 関連付け
  belongs_to :campaign, optional: true
  belongs_to :product, optional: true
  belongs_to :category, optional: true
  belongs_to :seller, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  # バリデーション
  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :ad_type, presence: true
  validates :budget, numericality: { greater_than: 0 }, allow_nil: true
  validates :spent_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cost_per_click, numericality: { greater_than: 0 }, allow_nil: true
  validate :end_date_after_start_date
  validate :spent_amount_not_exceeding_budget
  validate :target_present

  # コールバック
  before_save :set_status
  before_save :calculate_click_through_rate

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :current, -> { where('start_date <= ? AND end_date >= ?', Time.current, Time.current) }
  scope :upcoming, -> { where('start_date > ?', Time.current) }
  scope :expired, -> { where('end_date < ?', Time.current) }
  scope :by_type, ->(type) { where(ad_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_placement, ->(placement) { where(placement: placement) }
  scope :for_product, ->(product_id) { where(product_id: product_id) }
  scope :for_category, ->(category_id) { where(category_id: category_id) }
  scope :for_seller, ->(seller_id) { where(seller_id: seller_id) }
  scope :within_budget, -> { where('budget > spent_amount OR budget IS NULL') }
  scope :best_performing, -> { where('impressions_count > 0').order(click_through_rate: :desc) }

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

  def record_impression!
    increment!(:impressions_count)
    calculate_click_through_rate
    save if changed?
  end

  def record_click!
    increment!(:clicks_count)

    if cost_per_click.present?
      increment!(:spent_amount, cost_per_click)
    end

    calculate_click_through_rate
    save if changed?
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

  def average_cost_per_impression
    return 0 if impressions_count.zero?
    (spent_amount / impressions_count).round(4)
  end

  def average_cost_per_click
    return 0 if clicks_count.zero?
    (spent_amount / clicks_count).round(2)
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

  def target_present
    if product_id.blank? && category_id.blank? && seller_id.blank?
      errors.add(:base, "商品、カテゴリ、または販売者のいずれかを指定してください")
    end
  end

  def calculate_click_through_rate
    if impressions_count.positive?
      self.click_through_rate = (clicks_count.to_f / impressions_count * 100).round(2)
    else
      self.click_through_rate = 0
    end
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
