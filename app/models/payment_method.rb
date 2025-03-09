class PaymentMethod < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :payment_type, presence: true
  validates :payment_type, inclusion: { in: %w[credit_card debit_card bank_account paypal other] }
  validates :account_number, format: { with: /\A[\d\*]{4,16}\z/ }, allow_blank: true
  validates :expiry_date, format: { with: /\A(0[1-9]|1[0-2])\/\d{2}\z/ }, allow_blank: true

  # コールバック
  before_save :ensure_only_one_default_payment_method, if: -> { is_default_changed? && is_default? }
  before_save :mask_account_number, if: -> { account_number_changed? && account_number.present? }

  # スコープ
  scope :default, -> { where(is_default: true) }
  scope :credit_cards, -> { where(payment_type: 'credit_card') }
  scope :debit_cards, -> { where(payment_type: 'debit_card') }
  scope :bank_accounts, -> { where(payment_type: 'bank_account') }
  scope :paypal, -> { where(payment_type: 'paypal') }

  # カスタムメソッド
  def last_four_digits
    account_number.present? ? account_number.last(4) : nil
  end

  def expired?
    return false unless expiry_date.present?
    month, year = expiry_date.split('/')
    expiry_date = Date.new("20#{year}".to_i, month.to_i, 1).end_of_month
    Date.current > expiry_date
  end

  private

  def ensure_only_one_default_payment_method
    user.payment_methods.where.not(id: id).update_all(is_default: false) if user
  end

  def mask_account_number
    return if account_number.blank?
    visible_digits = 4
    masked_length = account_number.length - visible_digits
    self.account_number = "*" * masked_length + account_number.last(visible_digits) if masked_length > 0
  end
end
