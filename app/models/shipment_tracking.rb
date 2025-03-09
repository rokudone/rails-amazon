class ShipmentTracking < ApplicationRecord
  # 関連付け
  belongs_to :shipment
  belongs_to :order, optional: true

  # バリデーション
  validates :tracking_number, presence: true
  validates :tracking_date, presence: true
  validates :status, presence: true

  # スコープ
  scope :by_tracking_number, ->(tracking_number) { where(tracking_number: tracking_number) }
  scope :by_carrier, ->(carrier) { where(carrier: carrier) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_date_range, ->(start_date, end_date) { where(tracking_date: start_date..end_date) }
  scope :by_shipment, ->(shipment_id) { where(shipment_id: shipment_id) }
  scope :by_order, ->(order_id) { where(order_id: order_id) }
  scope :exceptions, -> { where(is_exception: true) }
  scope :delivered, -> { where(is_delivered: true) }
  scope :not_delivered, -> { where(is_delivered: false) }
  scope :chronological, -> { order(tracking_date: :asc) }
  scope :reverse_chronological, -> { order(tracking_date: :desc) }

  # カスタムメソッド
  def delivered?
    is_delivered
  end

  def exception?
    is_exception
  end

  def status_label
    case status
    when 'pending'
      '出荷準備中'
    when 'processing'
      '処理中'
    when 'shipped'
      '出荷完了'
    when 'in_transit'
      '配送中'
    when 'out_for_delivery'
      '配達中'
    when 'delivered'
      '配達完了'
    when 'failed'
      '配達失敗'
    when 'returned'
      '返送'
    when 'exception'
      '例外発生'
    else
      status
    end
  end

  def formatted_tracking_date
    tracking_date.strftime('%Y年%m月%d日 %H:%M:%S')
  end

  def formatted_location
    return nil if location.blank?

    parts = []
    parts << city if city.present?
    parts << state if state.present?
    parts << postal_code if postal_code.present?
    parts << country if country.present?

    if parts.any?
      "#{location} (#{parts.join(', ')})"
    else
      location
    end
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

  def self.update_from_carrier_api(tracking_number, carrier)
    # 実際の実装では、各キャリアのAPIを呼び出して追跡情報を取得する
    # ここでは簡易的な実装
    tracking = find_by(tracking_number: tracking_number, carrier: carrier)
    return nil unless tracking

    # APIからの応答をシミュレート
    {
      status: tracking.status,
      location: tracking.location,
      timestamp: tracking.tracking_date,
      details: tracking.status_description
    }
  end

  def self.create_from_carrier_data(shipment, carrier_data)
    # キャリアAPIからのデータを基に追跡情報を作成
    # ここでは簡易的な実装
    create!(
      shipment: shipment,
      order: shipment.order,
      tracking_number: shipment.tracking_number,
      carrier: shipment.carrier,
      status: carrier_data[:status],
      status_description: carrier_data[:details],
      tracking_date: carrier_data[:timestamp],
      location: carrier_data[:location]
    )
  end
end
