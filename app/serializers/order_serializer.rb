class OrderSerializer < BaseSerializer
  # 基本属性
  attributes :id, :order_number, :status, :total, :subtotal, :tax, :shipping_fee, :discount
  attributes :currency, :notes, :created_at, :updated_at

  # 金額関連の属性
  attribute :formatted_total, method: :format_total
  attribute :formatted_subtotal, method: :format_subtotal
  attribute :formatted_tax, method: :format_tax
  attribute :formatted_shipping_fee, method: :format_shipping_fee
  attribute :formatted_discount, method: :format_discount

  # 関連データ
  has_one :user, serializer: UserSerializer
  has_many :order_items, serializer: OrderItemSerializer
  has_many :payments, serializer: PaymentSerializer
  has_many :shipments, serializer: ShipmentSerializer
  has_one :invoice, serializer: InvoiceSerializer
  has_many :order_discounts, serializer: OrderDiscountSerializer
  has_one :gift_wrap, serializer: GiftWrapSerializer
  has_many :order_logs, serializer: OrderLogSerializer
  has_one :order_status, serializer: OrderStatusSerializer
  has_one :billing_address, serializer: AddressSerializer, method: :get_billing_address
  has_one :shipping_address, serializer: AddressSerializer, method: :get_shipping_address

  # メタデータ
  meta :can_cancel, method: :can_cancel_order
  meta :can_return, method: :can_return_order
  meta :estimated_delivery, method: :get_estimated_delivery
  meta :tracking_info, method: :get_tracking_info

  # 金額をフォーマット
  def format_total(order)
    format_currency(order.total, order.currency)
  end

  def format_subtotal(order)
    format_currency(order.subtotal, order.currency)
  end

  def format_tax(order)
    format_currency(order.tax, order.currency)
  end

  def format_shipping_fee(order)
    format_currency(order.shipping_fee, order.currency)
  end

  def format_discount(order)
    format_currency(order.discount, order.currency)
  end

  # 通貨をフォーマット
  def format_currency(amount, currency)
    return nil unless amount

    symbol = case currency
             when 'JPY' then '¥'
             when 'USD' then '$'
             when 'EUR' then '€'
             when 'GBP' then '£'
             else '¥'
             end

    "#{symbol}#{amount.to_i.to_s(:delimited)}"
  end

  # 請求先住所を取得
  def get_billing_address(order)
    # 請求先住所を取得
    order.addresses.find_by(address_type: 'billing')
  end

  # 配送先住所を取得
  def get_shipping_address(order)
    # 配送先住所を取得
    order.addresses.find_by(address_type: 'shipping')
  end

  # 注文をキャンセルできるかチェック
  def can_cancel_order(order)
    # キャンセル可能なステータスかチェック
    ['pending', 'processing'].include?(order.status)
  end

  # 注文を返品できるかチェック
  def can_return_order(order)
    # 返品可能なステータスかチェック
    ['delivered', 'completed'].include?(order.status) &&
      (Date.today - order.updated_at.to_date).to_i <= 30 # 30日以内
  end

  # 配送予定日を取得
  def get_estimated_delivery(order)
    # 配送情報がある場合は配送予定日を取得
    return nil unless order.shipments.present?

    # 最新の配送情報を取得
    latest_shipment = order.shipments.order(created_at: :desc).first

    # 配送予定日を取得
    latest_shipment.estimated_delivery_date
  end

  # 追跡情報を取得
  def get_tracking_info(order)
    # 配送情報がある場合は追跡情報を取得
    return [] unless order.shipments.present?

    # 追跡情報を取得
    order.shipments.map do |shipment|
      {
        carrier: shipment.carrier,
        tracking_number: shipment.tracking_number,
        tracking_url: shipment.tracking_url,
        status: shipment.status,
        shipped_at: shipment.shipped_at,
        estimated_delivery_date: shipment.estimated_delivery_date
      }
    end
  end
end

# OrderItemSerializer
class OrderItemSerializer < BaseSerializer
  attributes :id, :product_id, :product_variant_id, :quantity, :price, :total

  # 金額関連の属性
  attribute :formatted_price, method: :format_price
  attribute :formatted_total, method: :format_total

  # 関連データ
  has_one :product, serializer: ProductSerializer
  has_one :product_variant, serializer: ProductVariantSerializer

  # 金額をフォーマット
  def format_price(order_item)
    format_currency(order_item.price, order_item.order.currency)
  end

  def format_total(order_item)
    format_currency(order_item.total, order_item.order.currency)
  end

  # 通貨をフォーマット
  def format_currency(amount, currency)
    return nil unless amount

    symbol = case currency
             when 'JPY' then '¥'
             when 'USD' then '$'
             when 'EUR' then '€'
             when 'GBP' then '£'
             else '¥'
             end

    "#{symbol}#{amount.to_i.to_s(:delimited)}"
  end
end

# PaymentSerializer
class PaymentSerializer < BaseSerializer
  attributes :id, :amount, :payment_method, :status, :transaction_id, :created_at

  # 金額関連の属性
  attribute :formatted_amount, method: :format_amount

  # 関連データ
  has_many :payment_transactions, serializer: PaymentTransactionSerializer

  # 金額をフォーマット
  def format_amount(payment)
    format_currency(payment.amount, payment.currency)
  end

  # 通貨をフォーマット
  def format_currency(amount, currency)
    return nil unless amount

    symbol = case currency
             when 'JPY' then '¥'
             when 'USD' then '$'
             when 'EUR' then '€'
             when 'GBP' then '£'
             else '¥'
             end

    "#{symbol}#{amount.to_i.to_s(:delimited)}"
  end
end

# PaymentTransactionSerializer
class PaymentTransactionSerializer < BaseSerializer
  attributes :id, :amount, :transaction_type, :status, :transaction_id, :created_at

  # 金額関連の属性
  attribute :formatted_amount, method: :format_amount

  # 金額をフォーマット
  def format_amount(transaction)
    format_currency(transaction.amount, transaction.payment.currency)
  end

  # 通貨をフォーマット
  def format_currency(amount, currency)
    return nil unless amount

    symbol = case currency
             when 'JPY' then '¥'
             when 'USD' then '$'
             when 'EUR' then '€'
             when 'GBP' then '£'
             else '¥'
             end

    "#{symbol}#{amount.to_i.to_s(:delimited)}"
  end
end

# ShipmentSerializer
class ShipmentSerializer < BaseSerializer
  attributes :id, :carrier, :tracking_number, :tracking_url, :status
  attributes :shipped_at, :estimated_delivery_date, :created_at

  # 関連データ
  has_many :shipment_trackings, serializer: ShipmentTrackingSerializer
end

# ShipmentTrackingSerializer
class ShipmentTrackingSerializer < BaseSerializer
  attributes :id, :status, :location, :description, :tracked_at
end

# InvoiceSerializer
class InvoiceSerializer < BaseSerializer
  attributes :id, :invoice_number, :issued_at, :due_at, :status, :created_at

  # 金額関連の属性
  attribute :formatted_total, method: :format_total

  # 金額をフォーマット
  def format_total(invoice)
    format_currency(invoice.total, invoice.order.currency)
  end

  # 通貨をフォーマット
  def format_currency(amount, currency)
    return nil unless amount

    symbol = case currency
             when 'JPY' then '¥'
             when 'USD' then '$'
             when 'EUR' then '€'
             when 'GBP' then '£'
             else '¥'
             end

    "#{symbol}#{amount.to_i.to_s(:delimited)}"
  end
end

# OrderDiscountSerializer
class OrderDiscountSerializer < BaseSerializer
  attributes :id, :discount_type, :amount, :code, :description

  # 金額関連の属性
  attribute :formatted_amount, method: :format_amount

  # 金額をフォーマット
  def format_amount(discount)
    if discount.discount_type == 'percentage'
      "#{discount.amount}%"
    else
      format_currency(discount.amount, discount.order.currency)
    end
  end

  # 通貨をフォーマット
  def format_currency(amount, currency)
    return nil unless amount

    symbol = case currency
             when 'JPY' then '¥'
             when 'USD' then '$'
             when 'EUR' then '€'
             when 'GBP' then '£'
             else '¥'
             end

    "#{symbol}#{amount.to_i.to_s(:delimited)}"
  end
end

# GiftWrapSerializer
class GiftWrapSerializer < BaseSerializer
  attributes :id, :price, :message, :is_gift

  # 金額関連の属性
  attribute :formatted_price, method: :format_price

  # 金額をフォーマット
  def format_price(gift_wrap)
    format_currency(gift_wrap.price, gift_wrap.order.currency)
  end

  # 通貨をフォーマット
  def format_currency(amount, currency)
    return nil unless amount

    symbol = case currency
             when 'JPY' then '¥'
             when 'USD' then '$'
             when 'EUR' then '€'
             when 'GBP' then '£'
             else '¥'
             end

    "#{symbol}#{amount.to_i.to_s(:delimited)}"
  end
end

# OrderLogSerializer
class OrderLogSerializer < BaseSerializer
  attributes :id, :status, :notes, :created_at

  # 関連データ
  has_one :user, serializer: UserSerializer
end

# OrderStatusSerializer
class OrderStatusSerializer < BaseSerializer
  attributes :id, :name, :description, :color, :position
end

# AddressSerializer
class AddressSerializer < BaseSerializer
  attributes :id, :address_type, :name, :address_line1, :address_line2, :city, :state
  attributes :postal_code, :country, :phone_number, :is_default

  # フォーマット済み住所
  attribute :formatted_address, method: :format_address

  # 住所をフォーマット
  def format_address(address)
    parts = []
    parts << address.postal_code if address.postal_code.present?
    parts << address.state if address.state.present?
    parts << address.city if address.city.present?
    parts << address.address_line1 if address.address_line1.present?
    parts << address.address_line2 if address.address_line2.present?
    parts.join(', ')
  end
end
