class PaymentTransaction < ApplicationRecord
  # 関連付け
  belongs_to :payment
  belongs_to :order, optional: true

  # バリデーション
  validates :transaction_type, presence: true, inclusion: { in: ['authorization', 'capture', 'sale', 'refund', 'void'] }
  validates :transaction_id, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, presence: true, inclusion: { in: ['pending', 'success', 'failed', 'processing'] }
  validates :transaction_date, presence: true

  # スコープ
  scope :successful, -> { where(status: 'success') }
  scope :failed, -> { where(status: 'failed') }
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :by_type, ->(type) { where(transaction_type: type) }
  scope :authorizations, -> { where(transaction_type: 'authorization') }
  scope :captures, -> { where(transaction_type: 'capture') }
  scope :sales, -> { where(transaction_type: 'sale') }
  scope :refunds, -> { where(transaction_type: 'refund') }
  scope :voids, -> { where(transaction_type: 'void') }
  scope :by_date_range, ->(start_date, end_date) { where(transaction_date: start_date..end_date) }
  scope :by_payment, ->(payment_id) { where(payment_id: payment_id) }
  scope :by_order, ->(order_id) { where(order_id: order_id) }
  scope :by_provider, ->(provider) { where(payment_provider: provider) }
  scope :recent, -> { order(transaction_date: :desc) }
  scope :test_transactions, -> { where(is_test_transaction: true) }
  scope :live_transactions, -> { where(is_test_transaction: false) }

  # カスタムメソッド
  def successful?
    status == 'success'
  end

  def failed?
    status == 'failed'
  end

  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def authorization?
    transaction_type == 'authorization'
  end

  def capture?
    transaction_type == 'capture'
  end

  def sale?
    transaction_type == 'sale'
  end

  def refund?
    transaction_type == 'refund'
  end

  def void?
    transaction_type == 'void'
  end

  def test_transaction?
    is_test_transaction
  end

  def live_transaction?
    !is_test_transaction
  end

  def update_status(new_status, message = nil)
    return false unless ['pending', 'success', 'failed', 'processing'].include?(new_status)

    update(
      status: new_status,
      gateway_response_message: message || gateway_response_message
    )
  end

  def formatted_amount
    "#{amount} #{currency}"
  end

  def transaction_description
    case transaction_type
    when 'authorization'
      "支払い認証"
    when 'capture'
      "支払い確定"
    when 'sale'
      "即時決済"
    when 'refund'
      "返金"
    when 'void'
      "取消"
    else
      transaction_type
    end
  end

  def status_description
    case status
    when 'pending'
      "処理中"
    when 'success'
      "成功"
    when 'failed'
      "失敗"
    when 'processing'
      "処理中"
    else
      status
    end
  end

  def provider_description
    case payment_provider
    when 'stripe'
      "Stripe"
    when 'paypal'
      "PayPal"
    when 'amazon_pay'
      "Amazon Pay"
    when 'credit_card'
      "クレジットカード"
    when 'bank_transfer'
      "銀行振込"
    else
      payment_provider
    end
  end

  def response_data
    return {} if gateway_response_data.blank?

    gateway_response_data
  end

  def has_error?
    error_code.present? || error_description.present?
  end

  def error_message
    return nil unless has_error?

    "#{error_code}: #{error_description}"
  end
end
