class SellerTransaction < ApplicationRecord
  # 関連付け
  belongs_to :seller
  belongs_to :order, optional: true

  # バリデーション
  validates :transaction_type, presence: true
  validates :amount, presence: true, numericality: { other_than: 0 }
  validates :net_amount, presence: true
  validates :currency, presence: true
  validates :status, presence: true
  validates :reference_number, uniqueness: true, allow_blank: true

  # コールバック
  before_validation :set_net_amount, if: -> { net_amount.nil? && amount.present? }
  before_validation :generate_reference_number, if: -> { reference_number.blank? }
  before_save :set_processed_at, if: -> { status_changed? && status == 'completed' }
  after_save :update_seller_balance, if: -> { saved_change_to_status? && status == 'completed' }

  # スコープ
  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :by_type, ->(type) { where(transaction_type: type) }
  scope :sales, -> { where(transaction_type: 'sale') }
  scope :refunds, -> { where(transaction_type: 'refund') }
  scope :fees, -> { where(transaction_type: 'fee') }
  scope :payouts, -> { where(transaction_type: 'payout') }
  scope :adjustments, -> { where(transaction_type: 'adjustment') }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :recent, -> { order(created_at: :desc) }

  # クラスメソッド
  def self.total_sales(seller_id, start_date = nil, end_date = nil)
    transactions = sales.completed.where(seller_id: seller_id)
    transactions = transactions.by_date_range(start_date, end_date) if start_date && end_date
    transactions.sum(:amount)
  end

  def self.total_fees(seller_id, start_date = nil, end_date = nil)
    transactions = fees.completed.where(seller_id: seller_id)
    transactions = transactions.by_date_range(start_date, end_date) if start_date && end_date
    transactions.sum(:amount)
  end

  def self.total_payouts(seller_id, start_date = nil, end_date = nil)
    transactions = payouts.completed.where(seller_id: seller_id)
    transactions = transactions.by_date_range(start_date, end_date) if start_date && end_date
    transactions.sum(:amount)
  end

  def self.total_refunds(seller_id, start_date = nil, end_date = nil)
    transactions = refunds.completed.where(seller_id: seller_id)
    transactions = transactions.by_date_range(start_date, end_date) if start_date && end_date
    transactions.sum(:amount)
  end

  def self.net_earnings(seller_id, start_date = nil, end_date = nil)
    transactions = completed.where(seller_id: seller_id)
    transactions = transactions.by_date_range(start_date, end_date) if start_date && end_date
    transactions.sum(:net_amount)
  end

  # カスタムメソッド
  def complete!
    update(status: 'completed', processed_at: Time.current)
  end

  def fail!(reason = nil)
    update(status: 'failed', failure_reason: reason)
  end

  def cancel!(reason = nil)
    update(status: 'cancelled', cancellation_reason: reason)
  end

  def pending?
    status == 'pending'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def cancelled?
    status == 'cancelled'
  end

  def sale?
    transaction_type == 'sale'
  end

  def refund?
    transaction_type == 'refund'
  end

  def fee?
    transaction_type == 'fee'
  end

  def payout?
    transaction_type == 'payout'
  end

  def adjustment?
    transaction_type == 'adjustment'
  end

  def transaction_type_name
    case transaction_type
    when 'sale'
      '売上'
    when 'refund'
      '返金'
    when 'fee'
      '手数料'
    when 'payout'
      '支払い'
    when 'adjustment'
      '調整'
    else
      transaction_type.humanize
    end
  end

  def status_name
    case status
    when 'pending'
      '処理中'
    when 'completed'
      '完了'
    when 'failed'
      '失敗'
    when 'cancelled'
      'キャンセル'
    else
      status.humanize
    end
  end

  private

  def set_net_amount
    self.net_amount = amount - (fee_amount || 0) - (tax_amount || 0)
  end

  def generate_reference_number
    prefix = case transaction_type
             when 'sale' then 'SL'
             when 'refund' then 'RF'
             when 'fee' then 'FE'
             when 'payout' then 'PO'
             when 'adjustment' then 'AD'
             else 'TX'
             end

    self.reference_number = "#{prefix}#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
  end

  def set_processed_at
    self.processed_at = Time.current
  end

  def update_seller_balance
    # 販売者の残高を更新する処理（実装は別途必要）
  end
end
