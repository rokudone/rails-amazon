class Payment < ApplicationRecord
  # 関連付け
  belongs_to :order
  belongs_to :user
  belongs_to :payment_method, optional: true
  has_many :payment_transactions, dependent: :restrict_with_error

  # バリデーション
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, inclusion: { in: ['pending', 'processing', 'completed', 'failed', 'refunded', 'cancelled'] }
  validates :payment_type, inclusion: { in: ['full', 'partial', 'installment', 'refund'] }, allow_nil: true
  validates :payment_provider, inclusion: { in: ['stripe', 'paypal', 'amazon_pay', 'credit_card', 'bank_transfer'] }, allow_nil: true
  validates :last_four_digits, format: { with: /\A\d{4}\z/, message: '4桁の数字を入力してください' }, allow_nil: true
  validates :expiry_month, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }, allow_nil: true
  validates :expiry_year, numericality: { only_integer: true, greater_than_or_equal_to: -> { Date.today.year } }, allow_nil: true

  # コールバック
  after_save :update_order_payment_status, if: :saved_change_to_status?

  # スコープ
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :refunded, -> { where(status: 'refunded') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :by_provider, ->(provider) { where(payment_provider: provider) }
  scope :by_type, ->(type) { where(payment_type: type) }
  scope :by_date_range, ->(start_date, end_date) { where(payment_date: start_date..end_date) }
  scope :by_card_type, ->(card_type) { where(card_type: card_type) }
  scope :successful, -> { where(status: 'completed') }
  scope :unsuccessful, -> { where(status: ['failed', 'cancelled']) }
  scope :recent, -> { order(created_at: :desc) }

  # ステータス管理
  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def refunded?
    status == 'refunded'
  end

  def cancelled?
    status == 'cancelled'
  end

  def successful?
    completed?
  end

  def unsuccessful?
    failed? || cancelled?
  end

  # カスタムメソッド
  def process!
    return false unless pending?

    update(status: 'processing')
  end

  def complete!
    return false unless ['pending', 'processing'].include?(status)

    update(
      status: 'completed',
      payment_date: Time.now
    )
  end

  def fail!(error_message = nil)
    return false if completed? || refunded?

    update(
      status: 'failed',
      error_message: error_message
    )
  end

  def refund!(amount = nil, reason = nil)
    return false unless completed?

    refund_amount = amount || self.amount

    transaction do
      update(status: 'refunded')

      # 返金トランザクションを作成
      payment_transactions.create!(
        order: order,
        transaction_type: 'refund',
        transaction_id: "REFUND-#{SecureRandom.alphanumeric(8).upcase}",
        reference_id: transaction_id,
        amount: refund_amount,
        currency: currency,
        status: 'success',
        transaction_date: Time.now,
        payment_provider: payment_provider,
        payment_method_details: card_type,
        notes: reason
      )

      true
    end
  rescue => e
    errors.add(:base, "返金処理中にエラーが発生しました: #{e.message}")
    false
  end

  def cancel!
    return false if completed? || refunded?

    update(status: 'cancelled')
  end

  def masked_card_number
    return nil unless last_four_digits.present?

    "XXXX-XXXX-XXXX-#{last_four_digits}"
  end

  def card_expiry
    return nil unless expiry_month.present? && expiry_year.present?

    "#{expiry_month.to_s.rjust(2, '0')}/#{expiry_year.to_s[-2..-1]}"
  end

  def expired?
    return false unless expiry_month.present? && expiry_year.present?

    today = Date.today
    expiry_date = Date.new(expiry_year, expiry_month, 1).end_of_month

    expiry_date < today
  end

  def create_transaction(type, amount, status, transaction_id = nil)
    payment_transactions.create!(
      order: order,
      transaction_type: type,
      transaction_id: transaction_id || "#{type.upcase}-#{SecureRandom.alphanumeric(8).upcase}",
      reference_id: self.transaction_id,
      amount: amount,
      currency: currency,
      status: status,
      transaction_date: Time.now,
      payment_provider: payment_provider,
      payment_method_details: card_type
    )
  end

  def full_billing_address
    [
      billing_address_line1,
      billing_address_line2,
      billing_city,
      billing_state,
      billing_postal_code,
      billing_country
    ].compact.join(', ')
  end

  private

  def update_order_payment_status
    return unless order

    case status
    when 'completed'
      order.update(payment_status: 'paid')
    when 'failed'
      order.update(payment_status: 'failed')
    when 'refunded'
      # 全額返金か部分返金かを確認
      total_refunded = payment_transactions.where(transaction_type: 'refund').sum(:amount)

      if total_refunded >= amount
        order.update(payment_status: 'refunded')
      else
        order.update(payment_status: 'partially_refunded')
      end
    when 'cancelled'
      # 他の支払いがあるか確認
      other_completed_payments = order.payments.where(status: 'completed').where.not(id: id).exists?

      unless other_completed_payments
        order.update(payment_status: 'pending')
      end
    end
  end
end
