class ReferralProgram < ApplicationRecord
  # 関連付け
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :referrals, dependent: :nullify
  has_many :referral_rewards, dependent: :nullify

  # バリデーション
  validates :name, presence: true
  validates :reward_type, presence: true
  validates :referrer_reward_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :referee_reward_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :usage_limit_per_user, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :usage_limit_total, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :end_date_after_start_date, if: -> { start_date.present? && end_date.present? }

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :current, -> {
    where('(start_date IS NULL OR start_date <= ?) AND (end_date IS NULL OR end_date >= ?)',
          Time.current, Time.current)
  }
  scope :upcoming, -> { where('start_date > ?', Time.current) }
  scope :expired, -> { where('end_date < ?', Time.current) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_reward_type, ->(type) { where(reward_type: type) }

  # カスタムメソッド
  def active?
    is_active && current? && !usage_limit_reached?
  end

  def current?
    (start_date.nil? || start_date <= Time.current) &&
    (end_date.nil? || end_date >= Time.current)
  end

  def upcoming?
    start_date.present? && start_date > Time.current
  end

  def expired?
    end_date.present? && end_date < Time.current
  end

  def activate!
    update(is_active: true, status: 'active')
  end

  def deactivate!
    update(is_active: false, status: 'inactive')
  end

  def increment_usage!
    increment!(:usage_count)
    increment!(:referral_count)
  end

  def usage_limit_reached?
    usage_limit_total.present? && usage_count >= usage_limit_total
  end

  def usage_limit_reached_for_user?(user)
    return false unless usage_limit_per_user.present? && user.present?

    user_referrals_count = referrals.where(referrer: user).count
    user_referrals_count >= usage_limit_per_user
  end

  def remaining_usage
    return nil if usage_limit_total.nil?
    [usage_limit_total - usage_count, 0].max
  end

  def remaining_usage_for_user(user)
    return nil if usage_limit_per_user.nil? || user.nil?

    user_referrals_count = referrals.where(referrer: user).count
    [usage_limit_per_user - user_referrals_count, 0].max
  end

  def generate_referral_code(user)
    return nil if user.nil?

    prefix = code_prefix.presence || 'REF'
    "#{prefix}#{user.id}#{SecureRandom.hex(4).upcase}"
  end

  def create_referral!(referrer, referee)
    return false if referrer.nil? || referee.nil? || referrer == referee
    return false if usage_limit_reached?
    return false if usage_limit_reached_for_user?(referrer)

    referral = referrals.create(
      referrer: referrer,
      referee: referee,
      status: 'pending',
      code: generate_referral_code(referrer)
    )

    if referral.persisted?
      increment_usage!
      update_conversion_rate
    end

    referral
  end

  def complete_referral!(referral, order = nil)
    return false unless referral.present? && referral.status == 'pending'

    referral.update(
      status: 'completed',
      completed_at: Time.current,
      order: order
    )

    if referral.saved_change_to_status?
      create_rewards_for_referral(referral)
      update_conversion_rate
    end

    referral
  end

  def calculate_referrer_reward(order_amount = nil)
    case reward_type
    when 'discount'
      referrer_reward_amount
    when 'credit'
      referrer_reward_amount
    when 'percentage'
      return 0 if order_amount.nil?
      (order_amount * referrer_reward_amount / 100).round(2)
    else
      0
    end
  end

  def calculate_referee_reward(order_amount = nil)
    case reward_type
    when 'discount'
      referee_reward_amount
    when 'credit'
      referee_reward_amount
    when 'percentage'
      return 0 if order_amount.nil?
      (order_amount * referee_reward_amount / 100).round(2)
    else
      0
    end
  end

  private

  def end_date_after_start_date
    if end_date < start_date
      errors.add(:end_date, "は開始日より後の日付にしてください")
    end
  end

  def create_rewards_for_referral(referral)
    order_amount = referral.order&.total

    # 紹介者への報酬
    referrer_amount = calculate_referrer_reward(order_amount)
    if referrer_amount > 0
      referral_rewards.create(
        user: referral.referrer,
        referral: referral,
        amount: referrer_amount,
        reward_type: reward_type,
        status: 'pending'
      )

      increment!(:total_rewards_given, referrer_amount)
    end

    # 被紹介者への報酬
    referee_amount = calculate_referee_reward(order_amount)
    if referee_amount > 0
      referral_rewards.create(
        user: referral.referee,
        referral: referral,
        amount: referee_amount,
        reward_type: reward_type,
        status: 'pending'
      )

      increment!(:total_rewards_given, referee_amount)
    end
  end

  def update_conversion_rate
    total_referrals = referrals.count
    completed_referrals = referrals.where(status: 'completed').count

    if total_referrals > 0
      rate = (completed_referrals.to_f / total_referrals * 100).round
      update_column(:conversion_rate, rate)
    end
  end
end
