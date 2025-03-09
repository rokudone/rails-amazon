class Tag < ApplicationRecord
  # 関連付け
  has_many :product_tags, dependent: :destroy
  has_many :products, through: :product_tags

  # バリデーション
  validates :name, presence: true, uniqueness: true, length: { maximum: 255 }

  # スコープ
  scope :alphabetical, -> { order(name: :asc) }
  scope :popular, -> { joins(:product_tags).group(:id).order('COUNT(product_tags.id) DESC') }
  scope :with_products, -> { joins(:product_tags).distinct }

  # カスタムメソッド
  def product_count
    products.count
  end

  def related_tags
    Tag.joins(:product_tags)
       .where(product_tags: { product_id: product_ids })
       .where.not(id: id)
       .group(:id)
       .order('COUNT(product_tags.id) DESC')
  end
end
