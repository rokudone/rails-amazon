class ProductSpecification < ApplicationRecord
  # 関連付け
  belongs_to :product

  # バリデーション
  validates :name, presence: true, length: { maximum: 255 }
  validates :value, presence: true, length: { maximum: 255 }
  validates :unit, length: { maximum: 50 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :name, uniqueness: { scope: :product_id, message: "はこの商品で既に使用されています" }

  # スコープ
  scope :ordered, -> { order(position: :asc) }
  scope :by_name, ->(name) { where(name: name) }

  # コールバック
  before_save :ensure_position

  # カスタムメソッド
  def display_value
    if unit.present?
      "#{value} #{unit}"
    else
      value
    end
  end

  def display_name
    "#{name}: #{display_value}"
  end

  # クラスメソッド
  def self.specification_names_for_product(product_id)
    where(product_id: product_id).pluck(:name).uniq
  end

  def self.values_for_specification(name)
    where(name: name).pluck(:value).uniq
  end

  private

  def ensure_position
    self.position ||= 0
  end
end
