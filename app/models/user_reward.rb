class UserReward < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :reward_type, inclusion: { in: %w[points coupon discount gift promotion cashback] }, allow_blank: true
  validates :status, inclusion: { in: %w[active expired redeemed cancelled] }
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :code, uniqueness: true, allow_blank: true

  # コールバック
  before_create :set_issued_at
  before_save :update_status, if: -> { expires_at_changed? }

  # スコープ
  scope :active, -> { where(status: 'active') }
  scope :expired, -> { where(status: 'expired') }
  scope :redeemed, -> { where(status: 'redeemed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :by_type, ->(type) { where(reward_type: type) }
  scope :expiring_soon, -> { active.where('expires_at <= ?', 7.days.from_now) }
  scope :points_only, -> { where.not(points: nil) }
  scope :amount_only, -> { where.not(amount: nil) }

  # カスタムメソッド
  def redeem!(details = nil)
    return false if status != 'active'
    update(
      status: 'redeemed',
      redeemed_at: Time.current,
      redemption_details: details
    )
  end

  def cancel!
    update(status: 'cancelled')
  end

  def extend!(days)
    update(expires_at: expires_at + days.days)
  end

  def expired?
    status == 'expired' || (expires_at && expires_at < Time.current)
  end

  def days_until_expiry
    return 0 if expires_at.nil? || expires_at < Date.current
    (expires_at.to_date - Date.current).to_i
  end

  private

  def set_issued_at
    self.issued_at ||= Time.current
    self.status ||= 'active'
  end

  def update_status
    self.status = 'expired' if expires_at && expires_at < Time.current && status == 'active'
  end
end
