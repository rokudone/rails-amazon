class User < ApplicationRecord
  has_secure_password

  # 関連付け
  has_one :profile, dependent: :destroy
  has_many :addresses, dependent: :destroy
  has_many :payment_methods, dependent: :destroy
  has_one :user_preference, dependent: :destroy
  has_many :user_logs, dependent: :destroy
  has_many :user_devices, dependent: :destroy
  has_many :user_sessions, dependent: :destroy
  has_many :user_subscriptions, dependent: :destroy
  has_many :user_rewards, dependent: :destroy
  has_many :user_permissions, dependent: :destroy
  has_many :user_activities, dependent: :destroy

  # バリデーション
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }, allow_nil: true
  validates :first_name, :last_name, length: { maximum: 50 }
  validates :phone_number, format: { with: /\A\d{10,15}\z/ }, allow_blank: true

  # スコープ
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_recent_login, -> { where.not(last_login_at: nil).order(last_login_at: :desc) }

  # コールバック
  before_create :set_defaults

  # カスタムメソッド
  def full_name
    [first_name, last_name].compact.join(' ')
  end

  def lock_account!
    update(active: false, locked_at: Time.current)
  end

  def unlock_account!
    update(active: true, locked_at: nil, failed_attempts: 0)
  end

  def increment_failed_attempts!
    increment!(:failed_attempts)
    lock_account! if failed_attempts >= 5
  end

  def reset_password!
    token = generate_token
    update(
      reset_password_token: token,
      reset_password_sent_at: Time.current
    )
    token
  end

  private

  def set_defaults
    self.active = true if active.nil?
    self.failed_attempts = 0 if failed_attempts.nil?
  end

  def generate_token
    SecureRandom.hex(20)
  end
end
