class Order < ApplicationRecord
  # 関連付け
  belongs_to :user
  belongs_to :order_status
  belongs_to :billing_address, class_name: 'Address', optional: true
  belongs_to :shipping_address, class_name: 'Address', optional: true

  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items
  has_many :payments, dependent: :restrict_with_error
  has_many :payment_transactions, dependent: :restrict_with_error
  has_many :shipments, dependent: :restrict_with_error
  has_many :returns, dependent: :restrict_with_error
  has_many :invoices, dependent: :restrict_with_error
  has_many :order_logs, dependent: :destroy
  has_many :order_discounts, dependent: :destroy
  has_many :gift_wraps, dependent: :destroy
  has_many :stock_movements, dependent: :restrict_with_error

  # バリデーション
  validates :order_number, presence: true, uniqueness: true
  validates :order_date, presence: true
  validates :subtotal, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :tax_total, numericality: { greater_than_or_equal_to: 0 }
  validates :shipping_total, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_total, numericality: { greater_than_or_equal_to: 0 }
  validates :grand_total, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :payment_status, inclusion: { in: ['pending', 'authorized', 'paid', 'partially_refunded', 'refunded', 'failed'] }
  validates :fulfillment_status, inclusion: { in: ['pending', 'processing', 'partially_shipped', 'shipped', 'delivered', 'cancelled'] }
  validates :currency, presence: true
  validates :exchange_rate, presence: true, numericality: { greater_than: 0 }

  # コールバック
  before_validation :generate_order_number, on: :create
  before_validation :calculate_totals
  after_create :create_initial_log
  after_save :log_status_change, if: :saved_change_to_order_status_id?

  # スコープ
  scope :recent, -> { order(order_date: :desc) }
  scope :by_status, ->(status_id) { where(order_status_id: status_id) }
  scope :by_payment_status, ->(status) { where(payment_status: status) }
  scope :by_fulfillment_status, ->(status) { where(fulfillment_status: status) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_date_range, ->(start_date, end_date) { where(order_date: start_date..end_date) }
  scope :completed, -> { joins(:order_status).where(order_statuses: { code: 'completed' }) }
  scope :cancelled, -> { joins(:order_status).where(order_statuses: { code: 'cancelled' }) }
  scope :pending, -> { joins(:order_status).where(order_statuses: { code: 'pending' }) }
  scope :processing, -> { joins(:order_status).where(order_statuses: { code: 'processing' }) }
  scope :shipped, -> { joins(:order_status).where(order_statuses: { code: 'shipped' }) }
  scope :delivered, -> { joins(:order_status).where(order_statuses: { code: 'delivered' }) }
  scope :returned, -> { joins(:order_status).where(order_statuses: { code: 'returned' }) }
  scope :prime, -> { where(is_prime: true) }
  scope :with_gift, -> { where(is_gift: true) }
  scope :by_source, ->(source) { where(source: source) }
  scope :with_coupon, ->(coupon_code) { where(coupon_code: coupon_code) }

  # カスタムメソッド
  def total_items
    order_items.sum(:quantity)
  end

  def total_unique_items
    order_items.count
  end

  def add_item(product, quantity = 1, variant = nil, options = {})
    existing_item = find_item(product, variant)

    if existing_item
      existing_item.update(quantity: existing_item.quantity + quantity)
      existing_item
    else
      item = order_items.build(
        product: product,
        product_variant: variant,
        quantity: quantity,
        unit_price: variant&.price || product.price,
        sku: variant&.sku || product.sku,
        name: product.name,
        description: product.short_description,
        is_gift: options[:is_gift] || false,
        gift_message: options[:gift_message],
        is_digital: product.digital?
      )

      item.save ? item : nil
    end
  end

  def find_item(product, variant = nil)
    if variant
      order_items.find_by(product_id: product.id, product_variant_id: variant.id)
    else
      order_items.find_by(product_id: product.id, product_variant_id: nil)
    end
  end

  def remove_item(item_id)
    item = order_items.find_by(id: item_id)
    item&.destroy
  end

  def update_item_quantity(item_id, quantity)
    item = order_items.find_by(id: item_id)
    return false unless item

    if quantity <= 0
      item.destroy
    else
      item.update(quantity: quantity)
    end

    calculate_totals
    save
  end

  def apply_coupon(coupon_code)
    # 実際のクーポン処理ロジックを実装
    # ここでは簡易的な実装
    self.coupon_code = coupon_code
    self.discount_total = calculate_discount
    calculate_totals
    save
  end

  def calculate_discount
    # 実際の割引計算ロジックを実装
    # ここでは簡易的な実装
    return 0 if coupon_code.blank?

    # 例: 10%割引
    (subtotal * 0.1).round(2)
  end

  def cancel!
    return false if order_status.code == 'cancelled' || order_status.code == 'completed'

    cancelled_status = OrderStatus.find_by_code('cancelled')
    return false unless cancelled_status

    transaction do
      update(
        order_status: cancelled_status,
        fulfillment_status: 'cancelled',
        cancelled_at: Time.now
      )

      # 在庫を戻す
      order_items.each do |item|
        next if item.is_digital

        inventory = Inventory.find_by(
          product_id: item.product_id,
          product_variant_id: item.product_variant_id,
          warehouse_id: item.warehouse_id
        )

        next unless inventory

        inventory.update(reserved_quantity: [inventory.reserved_quantity - item.quantity, 0].max)
      end

      # キャンセルログを作成
      order_logs.create!(
        action: 'status_changed',
        previous_status: order_status.code,
        new_status: 'cancelled',
        message: "注文がキャンセルされました。理由: #{cancellation_reason.presence || '理由なし'}",
        source: 'system'
      )

      true
    end
  rescue => e
    errors.add(:base, "キャンセル処理中にエラーが発生しました: #{e.message}")
    false
  end

  def refund!(amount = nil, reason = nil)
    return false if payment_status == 'refunded'

    amount ||= grand_total

    transaction do
      # 支払い状態を更新
      if amount >= grand_total
        update(payment_status: 'refunded')
      else
        update(payment_status: 'partially_refunded')
      end

      # 返金トランザクションを作成
      payment = payments.order(created_at: :desc).first
      return false unless payment

      PaymentTransaction.create!(
        payment: payment,
        order: self,
        transaction_type: 'refund',
        transaction_id: "REFUND-#{SecureRandom.alphanumeric(8).upcase}",
        reference_id: payment.transaction_id,
        amount: amount,
        currency: currency,
        status: 'success',
        transaction_date: Time.now,
        payment_provider: payment.payment_provider,
        payment_method_details: payment.card_type,
        notes: reason
      )

      # 返金ログを作成
      order_logs.create!(
        action: 'refunded',
        message: "#{amount} #{currency}が返金されました。理由: #{reason.presence || '理由なし'}",
        source: 'system'
      )

      true
    end
  rescue => e
    errors.add(:base, "返金処理中にエラーが発生しました: #{e.message}")
    false
  end

  def update_status!(new_status_code, notes = nil)
    new_status = OrderStatus.find_by_code(new_status_code)
    return false unless new_status

    old_status = order_status
    return false unless old_status.can_transition_to?(new_status)

    transaction do
      update(order_status: new_status)

      # ステータス変更に基づいて他のフィールドを更新
      case new_status_code
      when 'processing'
        update(fulfillment_status: 'processing')
      when 'shipped'
        update(fulfillment_status: 'shipped')
      when 'delivered'
        update(fulfillment_status: 'delivered')
      when 'completed'
        # 何もしない
      end

      # ステータス変更ログを作成
      order_logs.create!(
        action: 'status_changed',
        previous_status: old_status.code,
        new_status: new_status.code,
        message: notes,
        source: 'system'
      )

      true
    end
  rescue => e
    errors.add(:base, "ステータス更新中にエラーが発生しました: #{e.message}")
    false
  end

  def reserve_inventory
    return false if order_items.empty?

    success = true

    transaction do
      order_items.each do |item|
        next if item.is_digital

        inventory = Inventory.find_by(
          product_id: item.product_id,
          product_variant_id: item.product_variant_id,
          warehouse_id: item.warehouse_id || Warehouse.active.first&.id
        )

        unless inventory && inventory.reserve(item.quantity)
          success = false
          raise ActiveRecord::Rollback
        end
      end
    end

    success
  end

  def unreserve_inventory
    return false if order_items.empty?

    success = true

    transaction do
      order_items.each do |item|
        next if item.is_digital

        inventory = Inventory.find_by(
          product_id: item.product_id,
          product_variant_id: item.product_variant_id,
          warehouse_id: item.warehouse_id
        )

        unless inventory && inventory.unreserve(item.quantity)
          success = false
          raise ActiveRecord::Rollback
        end
      end
    end

    success
  end

  def create_shipment(options = {})
    return false if order_items.empty?

    shipment = shipments.create!(
      shipment_number: "SH-#{order_number}-#{shipments.count + 1}",
      carrier: options[:carrier],
      service_level: options[:service_level],
      tracking_number: options[:tracking_number],
      status: 'pending',
      warehouse_id: options[:warehouse_id] || order_items.first.warehouse_id || Warehouse.active.first&.id,
      shipping_cost: shipping_total,
      shipping_method: shipping_method,
      recipient_name: shipping_address&.full_name || user.profile.full_name,
      recipient_phone: shipping_address&.phone || user.profile.phone,
      recipient_email: user.email,
      shipping_address_line1: shipping_address&.line1,
      shipping_address_line2: shipping_address&.line2,
      shipping_city: shipping_address&.city,
      shipping_state: shipping_address&.state,
      shipping_postal_code: shipping_address&.postal_code,
      shipping_country: shipping_address&.country,
      requires_signature: requires_signature,
      is_gift: is_gift,
      gift_message: gift_message
    )

    if shipment.persisted?
      # 出荷ログを作成
      order_logs.create!(
        action: 'shipment_created',
        message: "出荷 #{shipment.shipment_number} が作成されました。",
        reference_id: shipment.id.to_s,
        reference_type: 'shipment',
        source: 'system'
      )

      # 在庫から商品を引き落とす
      order_items.each do |item|
        next if item.is_digital

        inventory = Inventory.find_by(
          product_id: item.product_id,
          product_variant_id: item.product_variant_id,
          warehouse_id: shipment.warehouse_id
        )

        next unless inventory

        # 在庫移動を記録
        StockMovement.create!(
          inventory: inventory,
          source_warehouse_id: shipment.warehouse_id,
          quantity: item.quantity,
          movement_type: 'outbound',
          reference_number: order_number,
          order_id: id,
          status: 'completed',
          completed_at: Time.now
        )

        # 在庫を更新
        inventory.update(
          quantity: [inventory.quantity - item.quantity, 0].max,
          reserved_quantity: [inventory.reserved_quantity - item.quantity, 0].max
        )

        # 出荷アイテムを更新
        item.update(shipment_id: shipment.id)
      end

      # 注文ステータスを更新
      if order_status.code == 'processing'
        update_status!('shipped')
      end

      shipment
    else
      false
    end
  rescue => e
    errors.add(:base, "出荷作成中にエラーが発生しました: #{e.message}")
    false
  end

  def create_invoice
    return false if invoices.exists?

    invoice = invoices.create!(
      invoice_number: "INV-#{order_number}",
      user: user,
      invoice_date: Date.today,
      due_date: Date.today + 30.days,
      status: 'pending',
      subtotal: subtotal,
      tax_total: tax_total,
      shipping_total: shipping_total,
      discount_total: discount_total,
      grand_total: grand_total,
      amount_due: grand_total,
      currency: currency,
      payment_terms: 'due_on_receipt',
      billing_name: billing_address&.full_name || user.profile.full_name,
      billing_company: billing_address&.company,
      billing_address_line1: billing_address&.line1,
      billing_address_line2: billing_address&.line2,
      billing_city: billing_address&.city,
      billing_state: billing_address&.state,
      billing_postal_code: billing_address&.postal_code,
      billing_country: billing_address&.country,
      billing_phone: billing_address&.phone || user.profile.phone,
      billing_email: user.email,
      shipping_name: shipping_address&.full_name || user.profile.full_name,
      shipping_company: shipping_address&.company,
      shipping_address_line1: shipping_address&.line1,
      shipping_address_line2: shipping_address&.line2,
      shipping_city: shipping_address&.city,
      shipping_state: shipping_address&.state,
      shipping_postal_code: shipping_address&.postal_code,
      shipping_country: shipping_address&.country
    )

    if invoice.persisted?
      # 請求書ログを作成
      order_logs.create!(
        action: 'invoice_created',
        message: "請求書 #{invoice.invoice_number} が作成されました。",
        reference_id: invoice.id.to_s,
        reference_type: 'invoice',
        source: 'system'
      )

      invoice
    else
      false
    end
  rescue => e
    errors.add(:base, "請求書作成中にエラーが発生しました: #{e.message}")
    false
  end

  # ステータス管理
  def pending?
    order_status.code == 'pending'
  end

  def processing?
    order_status.code == 'processing'
  end

  def shipped?
    order_status.code == 'shipped'
  end

  def delivered?
    order_status.code == 'delivered'
  end

  def completed?
    order_status.code == 'completed'
  end

  def cancelled?
    order_status.code == 'cancelled'
  end

  def returned?
    order_status.code == 'returned'
  end

  def paid?
    payment_status == 'paid'
  end

  def payment_pending?
    payment_status == 'pending'
  end

  def payment_failed?
    payment_status == 'failed'
  end

  def refunded?
    payment_status == 'refunded'
  end

  def partially_refunded?
    payment_status == 'partially_refunded'
  end

  def cancellable?
    order_status.cancellable? && !cancelled? && !completed?
  end

  def returnable?
    order_status.returnable? && !cancelled? && !returned?
  end

  private

  def generate_order_number
    return if order_number.present?

    date_part = Date.today.strftime('%Y%m%d')
    random_part = SecureRandom.alphanumeric(6).upcase
    self.order_number = "ORD-#{date_part}-#{random_part}"
  end

  def calculate_totals
    self.subtotal = order_items.sum { |item| item.subtotal || (item.unit_price * item.quantity) }
    self.discount_total = order_discounts.sum(:applied_amount) || calculate_discount
    self.grand_total = subtotal + tax_total + shipping_total - discount_total
  end

  def create_initial_log
    order_logs.create!(
      action: 'created',
      message: '注文が作成されました',
      source: source || 'system'
    )
  end

  def log_status_change
    return unless saved_change_to_order_status_id?

    old_status_id, new_status_id = saved_change_to_order_status_id
    old_status = OrderStatus.find_by(id: old_status_id)
    new_status = OrderStatus.find_by(id: new_status_id)

    order_logs.create!(
      action: 'status_changed',
      previous_status: old_status&.code,
      new_status: new_status&.code,
      message: "注文ステータスが #{old_status&.name || '不明'} から #{new_status&.name || '不明'} に変更されました",
      source: 'system'
    )
  end
end
