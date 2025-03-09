class ProductAccessory < ApplicationRecord
  # 関連付け
  belongs_to :product
  belongs_to :accessory, class_name: 'Product', foreign_key: 'accessory_id'

  # バリデーション
  validates :accessory_id, uniqueness: { scope: :product_id, message: "はこの商品に既に追加されています" }
  validate :accessory_cannot_be_self

  # スコープ
  scope :required, -> { where(is_required: true) }
  scope :optional, -> { where(is_required: false) }
  scope :ordered_by_accessory_name, -> { joins(:accessory).order('products.name ASC') }

  # カスタムメソッド
  def required?
    is_required
  end

  private

  def accessory_cannot_be_self
    if accessory_id == product_id
      errors.add(:accessory_id, "は自分自身を指定できません")
    end
  end
end
