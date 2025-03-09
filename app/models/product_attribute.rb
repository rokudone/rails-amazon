class ProductAttribute < ApplicationRecord
  # 関連付け
  belongs_to :product

  # バリデーション
  validates :name, presence: true, length: { maximum: 255 }
  validates :value, presence: true, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :product_id, message: "はこの商品で既に使用されています" }

  # スコープ
  scope :filterable, -> { where(is_filterable: true) }
  scope :searchable, -> { where(is_searchable: true) }
  scope :by_name, ->(name) { where(name: name) }
  scope :by_value, ->(value) { where(value: value) }

  # カスタムメソッド
  def display_name
    "#{name}: #{value}"
  end

  def make_filterable!
    update(is_filterable: true)
  end

  def make_searchable!
    update(is_searchable: true)
  end

  # クラスメソッド
  def self.attribute_names_for_product(product_id)
    where(product_id: product_id).pluck(:name).uniq
  end

  def self.values_for_attribute(name)
    where(name: name).pluck(:value).uniq
  end
end
