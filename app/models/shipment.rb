class Shipment < ApplicationRecord
  # 関連付け
  belongs_to :order
  belongs_to :warehouse, optional: true
  has_many :order_items
  has_many :shipment_trackings, dependent: :destroy

  # バリデーション
  validates :shipment_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: ['pending', 'processing', 'shipped', 'in_transit', 'out_for_delivery', 'delivered', 'failed', 'returned'] }
  validates :shipping_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :insurance_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :declared_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weight, numericality: { greater_than: 0 }, allow_nil: true
  validates :package_count, numericality: { only_integer: true, greater_than: 0 }
  validates :recipient_name, presence: true
  validates :shipping_address_line1, presence: true
  validates :shipping_city, presence: true
  validates :shipping_postal_code, presence: true
  validates :shipping_country, presence: true

  # コールバック
  before_validation :generate_shipment_number, on: :create
  after_save :update_order_status, if: :saved_change_to_status?
  after_create :create_initial_tracking

  # スコープ
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :shipped, -> { where(status: 'shipped') }
  scope :in_transit, -> { where(status: 'in_transit') }
  scope :out_for_delivery, -> { where(status: 'out_for_delivery') }
  scope :delivered, -> { where(status: 'delivered') }
  scope :failed, -> { where(status: 'failed') }
  scope :returned, -> { where(status: 'returned') }
  scope :by_carrier, ->(carrier) { where(carrier: carrier) }
  scope :by_service_level, ->(service_level) { where(service_level: service_level) }
  scope :by_tracking_number, ->(tracking_number) { where(tracking_number: tracking_number) }
  scope :by_warehouse, ->(warehouse_id) { where(warehouse_id: warehouse_id) }
  scope :by_order, ->(order_id) { where(order_id: order_id) }
  scope :by_date_range, ->(start_date, end_date) { where(shipped_at: start_date..end_date) }
  scope :requires_signature, -> { where(requires_signature: true) }
  scope :is_gift, -> { where(is_gift: true) }
  scope :recent, -> { order(created_at: :desc) }

  # ステータス管理
  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def shipped?
    status == 'shipped'
  end

  def in_transit?
    status == 'in_transit'
  end

  def out_for_delivery?
    status == 'out_for_delivery'
  end

  def delivered?
    status == 'delivered'
  end

  def failed?
    status == 'failed'
  end

  def returned?
    status == 'returned'
  end

  # カスタムメソッド
  def process!
    return false unless pending?

    update(status: 'processing')
  end

  def ship!(tracking_number = nil, carrier = nil, service_level = nil)
    return false unless ['pending', 'processing'].include?(status)

    attrs = {
      status: 'shipped',
      shipped_at: Time.now
    }

    attrs[:tracking_number] = tracking_number if tracking_number.present?
    attrs[:carrier] = carrier if carrier.present?
    attrs[:service_level] = service_level if service_level.present?

    if update(attrs)
      # 出荷時の追跡情報を作成
      create_tracking_event('shipped', '出荷されました')

      # 注文アイテムのステータスを更新
      order_items.update_all(status: 'shipped')

      true
    else
      false
    end
  end

  def mark_in_transit!(location = nil)
    return false unless shipped?

    if update(status: 'in_transit')
      create_tracking_event('in_transit', '配送中', location)
      true
    else
      false
    end
  end

  def mark_out_for_delivery!(location = nil)
    return false unless in_transit?

    if update(status: 'out_for_delivery')
      create_tracking_event('out_for_delivery', '配達中', location)
      true
    else
      false
    end
  end

  def mark_delivered!(received_by = nil, location = nil)
    return false unless ['in_transit', 'out_for_delivery'].include?(status)

    if update(
      status: 'delivered',
      actual_delivery_date: Time.now
    )
      create_tracking_event('delivered', "配達完了。受取人: #{received_by}", location, received_by)

      # 注文アイテムのステータスを更新
      order_items.update_all(status: 'delivered')

      true
    else
      false
    end
  end

  def mark_failed!(reason = nil, location = nil)
    return false if delivered? || returned?

    if update(status: 'failed')
      create_tracking_event('failed', "配達失敗。理由: #{reason}", location)
      true
    else
      false
    end
  end

  def mark_returned!(reason = nil, location = nil)
    return false if delivered?

    if update(status: 'returned')
      create_tracking_event('returned', "返送。理由: #{reason}", location)
      true
    else
      false
    end
  end

  def create_tracking_event(status_code, description, location = nil, received_by = nil)
    shipment_trackings.create!(
      order: order,
      tracking_number: tracking_number,
      carrier: carrier,
      status: status_code,
      status_description: description,
      tracking_date: Time.now,
      location: location,
      is_delivered: status_code == 'delivered',
      delivered_at: status_code == 'delivered' ? Time.now : nil,
      received_by: received_by
    )
  end

  def latest_tracking
    shipment_trackings.order(tracking_date: :desc).first
  end

  def tracking_history
    shipment_trackings.order(tracking_date: :desc)
  end

  def days_in_transit
    return nil unless shipped_at

    if delivered?
      ((actual_delivery_date || Time.now) - shipped_at) / 1.day
    else
      (Time.now - shipped_at) / 1.day
    end.to_i
  end

  def estimated_delivery_days
    return nil unless estimated_delivery_date && shipped_at

    (estimated_delivery_date - shipped_at.to_date).to_i
  end

  def delayed?
    return false unless estimated_delivery_date

    !delivered? && Date.today > estimated_delivery_date
  end

  def days_delayed
    return 0 unless delayed?

    (Date.today - estimated_delivery_date).to_i
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

  def tracking_url
    case carrier&.downcase
    when 'fedex'
      "https://www.fedex.com/apps/fedextrack/?tracknumbers=#{tracking_number}"
    when 'ups'
      "https://www.ups.com/track?tracknum=#{tracking_number}"
    when 'usps'
      "https://tools.usps.com/go/TrackConfirmAction?tLabels=#{tracking_number}"
    when 'dhl'
      "https://www.dhl.com/en/express/tracking.html?AWB=#{tracking_number}"
    when 'amazon_logistics'
      "https://track.amazon.com/tracking/#{tracking_number}"
    else
      nil
    end
  end

  private

  def generate_shipment_number
    return if shipment_number.present?

    date_part = Date.today.strftime('%Y%m%d')
    random_part = SecureRandom.alphanumeric(6).upcase
    self.shipment_number = "SH-#{date_part}-#{random_part}"
  end

  def update_order_status
    return unless order

    case status
    when 'shipped'
      # 注文のすべての商品が出荷されたかチェック
      all_items_shipped = order.order_items.where.not(status: ['shipped', 'delivered']).count.zero?

      if all_items_shipped
        order.update_status!('shipped')
      else
        order.update(fulfillment_status: 'partially_shipped')
      end
    when 'delivered'
      # 注文のすべての商品が配達されたかチェック
      all_items_delivered = order.order_items.where.not(status: 'delivered').count.zero?

      if all_items_delivered
        order.update_status!('delivered')
      else
        order.update(fulfillment_status: 'partially_shipped')
      end
    end
  end

  def create_initial_tracking
    create_tracking_event('pending', '出荷準備中')
  end
end
