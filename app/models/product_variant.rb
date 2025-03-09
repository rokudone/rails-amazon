class ProductVariant < ApplicationRecord
  # 関連付け
  belongs_to :product
  has_many :product_images, dependent: :nullify
  has_many :price_histories, dependent: :destroy

  # バリデーション
  validates :sku, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :compare_at_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weight, numericality: { greater_than: 0 }, allow_nil: true

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :by_color, ->(color) { where(color: color) }
  scope :by_size, ->(size) { where(size: size) }
  scope :by_material, ->(material) { where(material: material) }
  scope :by_style, ->(style) { where(style: style) }

  # カスタムメソッド
  def display_name
    name.presence || "#{product.name} - #{variant_details}"
  end

  def variant_details
    details = []
    details << "Color: #{color}" if color.present?
    details << "Size: #{size}" if size.present?
    details << "Material: #{material}" if material.present?
    details << "Style: #{style}" if style.present?
    details.join(', ').presence || 'Standard'
  end

  def discount_percentage
    return 0 unless price.present? && compare_at_price.present? && compare_at_price > 0
    ((compare_at_price - price) / compare_at_price * 100).round(2)
  end

  def on_sale?
    price.present? && compare_at_price.present? && price < compare_at_price
  end

  def primary_image
    product_images.find_by(is_primary: true) || product_images.first || product.primary_image
  end

  def update_price(new_price, reason = nil)
    return false unless new_price.is_a?(Numeric) && new_price >= 0

    old_price = price
    price_histories.create(
      product: product,
      old_price: old_price,
      new_price: new_price,
      reason: reason
    )

    update(price: new_price)
  end
end
