class ProductBundleItem < ApplicationRecord
  # 関連付け
  belongs_to :product_bundle
  belongs_to :product

  # バリデーション
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :product_id, uniqueness: { scope: :product_bundle_id, message: "はこのバンドルに既に追加されています" }

  # スコープ
  scope :ordered_by_product_name, -> { joins(:product).order('products.name ASC') }

  # カスタムメソッド
  def subtotal
    product.price * quantity
  end

  def subtotal_with_discount
    # 仮定: 割引ロジックが後で実装される
    subtotal
  end
end
