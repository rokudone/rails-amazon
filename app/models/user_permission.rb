class UserPermission < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :permission_name, :action, presence: true
  validates :permission_name, inclusion: { in: %w[admin moderator seller buyer support analyst] }
  validates :action, inclusion: { in: %w[read write delete manage all] }
  validates :is_allowed, inclusion: { in: [true, false] }
  validates :user_id, uniqueness: { scope: [:permission_name, :resource_type, :resource_id, :action] }

  # コールバック
  before_create :set_granted_at

  # スコープ
  scope :allowed, -> { where(is_allowed: true) }
  scope :denied, -> { where(is_allowed: false) }
  scope :active, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :by_permission, ->(name) { where(permission_name: name) }
  scope :by_action, ->(action) { where(action: action) }
  scope :for_resource, ->(type, id = nil) {
    if id.nil?
      where(resource_type: type)
    else
      where(resource_type: type, resource_id: id)
    end
  }

  # カスタムメソッド
  def revoke!
    update(is_allowed: false)
  end

  def grant!
    update(is_allowed: true, granted_at: Time.current)
  end

  def expired?
    expires_at && expires_at <= Time.current
  end

  def extend!(days)
    new_expiry = expires_at ? expires_at + days.days : days.days.from_now
    update(expires_at: new_expiry)
  end

  private

  def set_granted_at
    self.granted_at ||= Time.current
  end
end
