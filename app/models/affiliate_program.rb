class AffiliateProgram < ApplicationRecord
  # 関連付け
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :affiliate_users, dependent: :nullify
  has_many :affiliate_commissions, dependent: :nullify

  # バリデーション
  validates :name, presence: true
  validates :commission_rate, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :commission_type, presence: true, inclusion: { in: ['percentage', 'fixed_amount'] }
  validates :minimum_payout, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cookie_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :payment_method, presence: true
  validates :status, presence: true

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_commission_type, ->(type) { where(commission_type: type) }
  scope :by_payment_method, ->(method) { where(payment_method: method) }
  scope :high_commission, -> { where('commission_rate >= ?', 10) }

  # カスタムメソッド
  def activate!
    update(is_active: true, status: 'active')
  end

  def deactivate!
    update(is_active: false, status: 'inactive')
  end

  def pending!
    update(status: 'pending_approval')
  end

  def calculate_commission(order_amount)
    case commission_type
    when 'percentage'
      (order_amount * commission_rate / 100).round(2)
    when 'fixed_amount'
      commission_rate
    else
      0
    end
  end

  def eligible_for_payout?(amount)
    minimum_payout.nil? || amount >= minimum_payout
  end

  def add_affiliate!(user)
    return false if user.nil?

    affiliate_user = affiliate_users.find_or_initialize_by(user: user)
    if affiliate_user.new_record?
      affiliate_user.tracking_code = generate_tracking_code(user)
      affiliate_user.save
      increment!(:affiliates_count)
    end

    affiliate_user
  end

  def remove_affiliate!(user)
    return false if user.nil?

    affiliate_user = affiliate_users.find_by(user: user)
    if affiliate_user.present?
      affiliate_user.destroy
      decrement!(:affiliates_count)
      true
    else
      false
    end
  end

  def record_commission!(affiliate_user, order, amount = nil)
    return false if affiliate_user.nil? || order.nil?

    commission_amount = amount || calculate_commission(order.total)

    commission = affiliate_commissions.create!(
      affiliate_user: affiliate_user,
      order: order,
      amount: commission_amount,
      status: 'pending'
    )

    increment!(:lifetime_commission_paid, commission_amount) if commission.persisted?
    commission
  end

  def update_terms_and_conditions!(new_terms)
    old_terms = terms_and_conditions
    update(terms_and_conditions: new_terms)

    # 利用規約変更の通知処理（実装は別途必要）
    notify_affiliates_of_terms_change(old_terms, new_terms) if saved_change_to_terms_and_conditions?
  end

  def eligible_categories_list
    return [] if eligible_categories.blank?
    JSON.parse(eligible_categories)
  rescue JSON::ParserError
    []
  end

  def eligible_products_list
    return [] if eligible_products.blank?
    JSON.parse(eligible_products)
  rescue JSON::ParserError
    []
  end

  def product_eligible?(product)
    return true if eligible_products.blank? && eligible_categories.blank?

    product_ids = eligible_products_list
    category_ids = eligible_categories_list

    return true if product_ids.include?(product.id.to_s)
    return true if category_ids.include?(product.category_id.to_s)

    false
  end

  private

  def generate_tracking_code(user)
    prefix = tracking_code_prefix.presence || 'AFF'
    "#{prefix}-#{user.id}-#{SecureRandom.hex(4).upcase}"
  end

  def notify_affiliates_of_terms_change(old_terms, new_terms)
    # 利用規約変更の通知処理（実装は別途必要）
  end
end
