class UserSession < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :session_token, presence: true, uniqueness: true

  # コールバック
  before_create :set_expiry
  before_save :update_last_activity, if: -> { is_active_changed? && is_active? }

  # スコープ
  scope :active, -> { where(is_active: true).where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :inactive, -> { where(is_active: false) }
  scope :recent, -> { order(last_activity_at: :desc) }

  # カスタムメソッド
  def expired?
    expires_at <= Time.current
  end

  def expire!
    update(is_active: false, expires_at: Time.current)
  end

  def extend_expiry!(hours = 24)
    update(expires_at: Time.current + hours.hours)
  end

  def touch_activity!
    update(last_activity_at: Time.current)
  end

  private

  def set_expiry
    self.expires_at ||= 24.hours.from_now
    self.last_activity_at ||= Time.current
  end

  def update_last_activity
    self.last_activity_at = Time.current
  end
end
