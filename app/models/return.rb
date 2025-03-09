class Return < ApplicationRecord
  # 関連付け
  belongs_to :order
  belongs_to :user
  belongs_to :exchange_order, class_name: 'Order', optional: true
  has_many :order_items
  has_many :stock_movements, dependent: :restrict_with_error

  # バリデーション
  validates :return_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: ['requested', 'approved', 'received', 'inspected', 'completed', 'rejected'] }
  validates :return_type, inclusion: { in: ['refund', 'exchange', 'store_credit', 'warranty'] }, allow_nil: true
  validates :return_reason, inclusion: { in: ['damaged', 'defective', 'wrong_item', 'not_as_described', 'no_longer_needed'] }, allow_nil: true
  validates :requested_at, presence: true
  validates :refund_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :restocking_fee_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :return_shipping_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # コールバック
  before_validation :generate_return_number, on: :create
  after_save :update_order_items_status, if: :saved_change_to_status?

  # スコープ
  scope :requested, -> { where(status: 'requested') }
  scope :approved, -> { where(status: 'approved') }
  scope :received, -> { where(status: 'received') }
  scope :inspected, -> { where(status: 'inspected') }
  scope :completed, -> { where(status: 'completed') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :by_type, ->(type) { where(return_type: type) }
  scope :by_reason, ->(reason) { where(return_reason: reason) }
  scope :by_order, ->(order_id) { where(order_id: order_id) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_date_range, ->(start_date, end_date) { where(requested_at: start_date..end_date) }
  scope :warranty_claims, -> { where(is_warranty_claim: true) }
  scope :recent, -> { order(requested_at: :desc) }

  # ステータス管理
  def requested?
    status == 'requested'
  end

  def approved?
    status == 'approved'
  end

  def received?
    status == 'received'
  end

  def inspected?
    status == 'inspected'
  end

  def completed?
    status == 'completed'
  end

  def rejected?
    status == 'rejected'
  end

  # カスタムメソッド
  def approve!(approved_by_user = nil)
    return false unless requested?

    transaction do
      update(
        status: 'approved',
        approved_at: Time.now,
        approved_by: approved_by_user,
        return_label_url: generate_return_label
      )

      # 返品承認ログを作成
      order.order_logs.create!(
        action: 'return_approved',
        message: "返品 #{return_number} が承認されました",
        reference_id: id.to_s,
        reference_type: 'return',
        source: 'system'
      )

      true
    end
  rescue => e
    errors.add(:base, "承認処理中にエラーが発生しました: #{e.message}")
    false
  end

  def receive!
    return false unless approved?

    update(
      status: 'received',
      received_at: Time.now
    )
  end

  def inspect!(condition, notes = nil, inspector = nil)
    return false unless received?

    update(
      status: 'inspected',
      condition_on_return: condition,
      inspection_notes: notes,
      inspector_name: inspector
    )
  end

  def complete!(refund_amount = nil)
    return false unless inspected?

    transaction do
      attrs = {
        status: 'completed',
        completed_at: Time.now
      }

      if refund_amount.present?
        attrs[:refund_amount] = refund_amount
      end

      update(attrs)

      # 返金処理
      if return_type == 'refund' && refund_amount.present? && refund_amount > 0
        process_refund
      end

      # 在庫を戻す
      process_inventory_return

      # 返品完了ログを作成
      order.order_logs.create!(
        action: 'return_completed',
        message: "返品 #{return_number} が完了しました",
        reference_id: id.to_s,
        reference_type: 'return',
        source: 'system'
      )

      true
    end
  rescue => e
    errors.add(:base, "完了処理中にエラーが発生しました: #{e.message}")
    false
  end

  def reject!(reason = nil)
    return false if completed? || rejected?

    transaction do
      update(
        status: 'rejected',
        rejection_reason: reason
      )

      # 返品拒否ログを作成
      order.order_logs.create!(
        action: 'return_rejected',
        message: "返品 #{return_number} が拒否されました。理由: #{reason || '理由なし'}",
        reference_id: id.to_s,
        reference_type: 'return',
        source: 'system'
      )

      # 注文アイテムのステータスを元に戻す
      order_items.each do |item|
        item.update(status: 'delivered', return_id: nil)
      end

      true
    end
  rescue => e
    errors.add(:base, "拒否処理中にエラーが発生しました: #{e.message}")
    false
  end

  def add_item(order_item, return_reason = nil)
    return false unless order_item.order_id == order_id

    order_item.update(
      return_id: id,
      status: 'returned',
      return_reason: return_reason
    )
  end

  def total_items
    order_items.count
  end

  def total_refund_amount
    refund_amount || calculate_refund_amount
  end

  def calculate_refund_amount
    total = order_items.sum { |item| item.total }

    if restocking_fee_applied && restocking_fee_amount.present?
      total -= restocking_fee_amount
    end

    if return_shipping_paid_by_customer && return_shipping_cost.present?
      total -= return_shipping_cost
    end

    [total, 0].max
  end

  def days_since_requested
    ((Time.now - requested_at) / 1.day).to_i
  end

  def days_since_order
    ((requested_at - order.order_date) / 1.day).to_i
  end

  def generate_rma_number
    date_part = Date.today.strftime('%Y%m%d')
    random_part = SecureRandom.alphanumeric(4).upcase
    "RMA-#{date_part}-#{random_part}"
  end

  def tracking_url
    return nil if return_tracking_number.blank? || return_carrier.blank?

    case return_carrier.downcase
    when 'fedex'
      "https://www.fedex.com/apps/fedextrack/?tracknumbers=#{return_tracking_number}"
    when 'ups'
      "https://www.ups.com/track?tracknum=#{return_tracking_number}"
    when 'usps'
      "https://tools.usps.com/go/TrackConfirmAction?tLabels=#{return_tracking_number}"
    when 'dhl'
      "https://www.dhl.com/en/express/tracking.html?AWB=#{return_tracking_number}"
    else
      nil
    end
  end

  private

  def generate_return_number
    return if return_number.present?

    date_part = Date.today.strftime('%Y%m%d')
    random_part = SecureRandom.alphanumeric(6).upcase
    self.return_number = "RET-#{date_part}-#{random_part}"
  end

  def generate_return_label
    # 実際の実装では、配送業者のAPIを呼び出して返品ラベルを生成する
    # ここでは簡易的な実装
    "https://example.com/return-labels/#{return_number}.pdf"
  end

  def process_refund
    # 支払い情報を取得
    payment = order.payments.where(status: 'completed').order(created_at: :desc).first
    return unless payment

    # 返金トランザクションを作成
    PaymentTransaction.create!(
      payment: payment,
      order: order,
      transaction_type: 'refund',
      transaction_id: "REFUND-#{SecureRandom.alphanumeric(8).upcase}",
      reference_id: payment.transaction_id,
      amount: refund_amount,
      currency: order.currency,
      status: 'success',
      transaction_date: Time.now,
      payment_provider: payment.payment_provider,
      payment_method_details: payment.card_type,
      notes: "返品 #{return_number} に対する返金"
    )

    # 支払いステータスを更新
    if refund_amount >= order.grand_total
      order.update(payment_status: 'refunded')
    else
      order.update(payment_status: 'partially_refunded')
    end

    # 返金トランザクションIDを保存
    update(refund_transaction_id: "REFUND-#{SecureRandom.alphanumeric(8).upcase}", refunded_at: Time.now)
  end

  def process_inventory_return
    order_items.each do |item|
      next if item.is_digital

      # 在庫を探す
      inventory = Inventory.find_by(
        product_id: item.product_id,
        product_variant_id: item.product_variant_id,
        warehouse_id: item.warehouse_id || order.shipments.first&.warehouse_id
      )

      next unless inventory

      # 在庫を増やす
      inventory.update(quantity: inventory.quantity + item.quantity)

      # 在庫移動を記録
      StockMovement.create!(
        inventory: inventory,
        destination_warehouse_id: inventory.warehouse_id,
        quantity: item.quantity,
        movement_type: 'return',
        reference_number: return_number,
        order_id: order.id,
        return_id: id,
        status: 'completed',
        completed_at: Time.now,
        reason: return_reason
      )
    end
  end

  def update_order_items_status
    case status
    when 'approved'
      order_items.update_all(status: 'returned')
    when 'rejected'
      order_items.update_all(status: 'delivered', return_id: nil)
    end
  end
end
