class UserDevice < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :device_id, presence: true, uniqueness: true
  validates :device_type, inclusion: { in: %w[mobile tablet desktop other] }, allow_blank: true
  validates :os_type, inclusion: { in: %w[ios android windows macos linux other] }, allow_blank: true

  # コールバック
  before_save :update_last_used_at, if: -> { is_active_changed? && is_active? }

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :mobile, -> { where(device_type: 'mobile') }
  scope :tablet, -> { where(device_type: 'tablet') }
  scope :desktop, -> { where(device_type: 'desktop') }
  scope :ios, -> { where(os_type: 'ios') }
  scope :android, -> { where(os_type: 'android') }
  scope :recently_used, -> { order(last_used_at: :desc) }

  # カスタムメソッド
  def deactivate!
    update(is_active: false)
  end

  def activate!
    update(is_active: true)
  end

  private

  def update_last_used_at
    self.last_used_at = Time.current
  end
end
