class UserSubscription < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :subscription_type, presence: true
  validates :subscription_type, inclusion: { in: %w[prime music video kindle unlimited business] }
  validates :status, inclusion: { in: %w[active paused cancelled expired trial] }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :billing_period, inclusion: { in: %w[monthly quarterly biannual annual] }, allow_blank: true

  # コールバック
  before_create :set_dates
  before_save :update_status, if: -> { end_date_changed? }

  # スコープ
  scope :active, -> { where(status: 'active') }
  scope :paused, -> { where(status: 'paused') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :expired, -> { where(status: 'expired') }
  scope :trial, -> { where(status: 'trial') }
  scope :auto_renewing, -> { where(auto_renew: true) }
  scope :expiring_soon, -> { active.where('end_date <= ?', 7.days.from_now) }
  scope :by_type, ->(type) { where(subscription_type: type) }

  # カスタムメソッド
  def cancel!
    update(status: 'cancelled', auto_renew: false)
  end

  def pause!
    update(status: 'paused')
  end

  def resume!
    update(status: 'active')
  end

  def extend!(days)
    update(end_date: end_date + days.days)
  end

  def days_remaining
    return 0 if end_date.nil? || end_date < Date.current
    (end_date.to_date - Date.current).to_i
  end

  def active?
    status == 'active' && (end_date.nil? || end_date > Time.current)
  end

  private

  def set_dates
    self.start_date ||= Time.current
    self.end_date ||= calculate_end_date
    self.next_payment_date ||= calculate_next_payment_date if auto_renew
  end

  def update_status
    self.status = 'expired' if end_date && end_date < Time.current
  end

  def calculate_end_date
    case billing_period
    when 'monthly' then 1.month.from_now
    when 'quarterly' then 3.months.from_now
    when 'biannual' then 6.months.from_now
    when 'annual' then 1.year.from_now
    else 1.month.from_now
    end
  end

  def calculate_next_payment_date
    end_date - 1.day
  end
end
