class PriceHistory < ApplicationRecord
  # 関連付け
  belongs_to :product
  belongs_to :product_variant, optional: true

  # バリデーション
  validates :old_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :new_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reason, length: { maximum: 255 }

  # スコープ
  scope :recent, -> { order(created_at: :desc) }
  scope :for_product, ->(product_id) { where(product_id: product_id) }
  scope :for_variant, ->(variant_id) { where(product_variant_id: variant_id) }
  scope :price_increases, -> { where('new_price > old_price') }
  scope :price_decreases, -> { where('new_price < old_price') }

  # カスタムメソッド
  def price_difference
    new_price - old_price
  end

  def price_change_percentage
    return 0 if old_price.zero?
    ((new_price - old_price) / old_price * 100).round(2)
  end

  def price_increased?
    new_price > old_price
  end

  def price_decreased?
    new_price < old_price
  end

  def price_unchanged?
    new_price == old_price
  end

  def display_reason
    reason.presence || default_reason
  end

  private

  def default_reason
    if price_increased?
      "価格上昇"
    elsif price_decreased?
      "価格下落"
    else
      "価格変更"
    end
  end
end
