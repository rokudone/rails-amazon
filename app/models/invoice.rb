class Invoice < ApplicationRecord
  # 関連付け
  belongs_to :order
  belongs_to :user

  # バリデーション
  validates :invoice_number, presence: true, uniqueness: true
  validates :invoice_date, presence: true
  validates :status, inclusion: { in: ['pending', 'paid', 'partially_paid', 'overdue', 'cancelled', 'refunded'] }
  validates :subtotal, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :tax_total, numericality: { greater_than_or_equal_to: 0 }
  validates :shipping_total, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_total, numericality: { greater_than_or_equal_to: 0 }
  validates :grand_total, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :amount_paid, numericality: { greater_than_or_equal_to: 0 }
  validates :amount_due, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :payment_terms, inclusion: { in: ['due_on_receipt', 'net_15', 'net_30', 'net_60'] }, allow_nil: true
  validates :billing_name, presence: true
  validates :billing_address_line1, presence: true
  validates :billing_city, presence: true
  validates :billing_postal_code, presence: true
  validates :billing_country, presence: true
  validates :billing_email, presence: true

  # コールバック
  before_validation :calculate_amount_due
  before_validation :generate_invoice_number, on: :create
  after_create :send_invoice_notification

  # スコープ
  scope :pending, -> { where(status: 'pending') }
  scope :paid, -> { where(status: 'paid') }
  scope :partially_paid, -> { where(status: 'partially_paid') }
  scope :overdue, -> { where('due_date < ? AND status NOT IN (?)', Date.today, ['paid', 'cancelled', 'refunded']) }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :refunded, -> { where(status: 'refunded') }
  scope :by_date_range, ->(start_date, end_date) { where(invoice_date: start_date..end_date) }
  scope :by_due_date_range, ->(start_date, end_date) { where(due_date: start_date..end_date) }
  scope :by_order, ->(order_id) { where(order_id: order_id) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :recent, -> { order(invoice_date: :desc) }
  scope :due_soon, ->(days = 7) { where('due_date BETWEEN ? AND ?', Date.today, Date.today + days.days) }

  # ステータス管理
  def pending?
    status == 'pending'
  end

  def paid?
    status == 'paid'
  end

  def partially_paid?
    status == 'partially_paid'
  end

  def overdue?
    due_date.present? && due_date < Date.today && !['paid', 'cancelled', 'refunded'].include?(status)
  end

  def cancelled?
    status == 'cancelled'
  end

  def refunded?
    status == 'refunded'
  end

  # カスタムメソッド
  def mark_as_paid!(payment_amount = nil)
    payment = payment_amount || amount_due

    transaction do
      self.amount_paid += payment
      self.amount_due = [grand_total - self.amount_paid, 0].max

      if self.amount_paid >= grand_total
        self.status = 'paid'
      elsif self.amount_paid > 0
        self.status = 'partially_paid'
      end

      save!

      # 注文の支払いステータスを更新
      if paid?
        order.update(payment_status: 'paid')
      elsif partially_paid?
        order.update(payment_status: 'partially_paid')
      end

      true
    end
  rescue => e
    errors.add(:base, "支払い処理中にエラーが発生しました: #{e.message}")
    false
  end

  def cancel!
    return false if paid? || refunded?

    transaction do
      update(status: 'cancelled')

      # 注文ログを作成
      order.order_logs.create!(
        action: 'invoice_cancelled',
        message: "請求書 #{invoice_number} がキャンセルされました",
        reference_id: id.to_s,
        reference_type: 'invoice',
        source: 'system'
      )

      true
    end
  rescue => e
    errors.add(:base, "キャンセル処理中にエラーが発生しました: #{e.message}")
    false
  end

  def refund!(refund_amount = nil)
    return false unless paid?

    amount = refund_amount || amount_paid

    transaction do
      self.amount_paid -= amount
      self.amount_due = [grand_total - self.amount_paid, 0].max

      if self.amount_paid <= 0
        self.status = 'refunded'
      elsif self.amount_paid < grand_total
        self.status = 'partially_paid'
      end

      save!

      # 注文の支払いステータスを更新
      if refunded?
        order.update(payment_status: 'refunded')
      elsif partially_paid?
        order.update(payment_status: 'partially_refunded')
      end

      # 注文ログを作成
      order.order_logs.create!(
        action: 'invoice_refunded',
        message: "請求書 #{invoice_number} が返金されました。金額: #{amount} #{currency}",
        reference_id: id.to_s,
        reference_type: 'invoice',
        source: 'system'
      )

      true
    end
  rescue => e
    errors.add(:base, "返金処理中にエラーが発生しました: #{e.message}")
    false
  end

  def record_view!
    self.view_count += 1
    self.viewed_at = Time.now
    save
  end

  def send_invoice!
    return false if sent_at.present?

    # 実際の実装では、メール送信処理を行う
    # ここでは簡易的な実装
    update(sent_at: Time.now)

    # 注文ログを作成
    order.order_logs.create!(
      action: 'invoice_sent',
      message: "請求書 #{invoice_number} が送信されました",
      reference_id: id.to_s,
      reference_type: 'invoice',
      source: 'system'
    )

    true
  end

  def days_until_due
    return nil if due_date.blank?

    (due_date - Date.today).to_i
  end

  def days_overdue
    return 0 unless overdue?

    (Date.today - due_date).to_i
  end

  def payment_terms_label
    case payment_terms
    when 'due_on_receipt'
      '受領後即時支払い'
    when 'net_15'
      '15日以内'
    when 'net_30'
      '30日以内'
    when 'net_60'
      '60日以内'
    else
      payment_terms
    end
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

  def full_shipping_address
    [
      shipping_address_line1,
      shipping_address_line2,
      shipping_city,
      shipping_state,
      shipping_postal_code,
      shipping_country
    ].compact.join(', ')
  end

  def generate_pdf
    # 実際の実装では、PDFを生成する処理を行う
    # ここでは簡易的な実装
    "https://example.com/invoices/#{invoice_number}.pdf"
  end

  private

  def calculate_amount_due
    self.amount_due = grand_total - amount_paid if grand_total.present? && amount_paid.present?
  end

  def generate_invoice_number
    return if invoice_number.present?

    date_part = Date.today.strftime('%Y%m%d')
    random_part = SecureRandom.alphanumeric(6).upcase
    self.invoice_number = "INV-#{date_part}-#{random_part}"
  end

  def send_invoice_notification
    # 実際の実装では、通知処理を行う
    # ここでは簡易的な実装
    true
  end
end
