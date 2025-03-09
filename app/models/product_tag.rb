class ProductTag < ApplicationRecord
  # 関連付け
  belongs_to :product
  belongs_to :tag

  # バリデーション
  validates :tag_id, uniqueness: { scope: :product_id, message: "はこの商品に既に追加されています" }

  # スコープ
  scope :ordered_by_tag_name, -> { joins(:tag).order('tags.name ASC') }

  # クラスメソッド
  def self.popular_tags(limit = 10)
    joins(:tag)
      .group(:tag_id)
      .order('COUNT(product_tags.id) DESC')
      .limit(limit)
      .pluck('tags.name', 'COUNT(product_tags.id)')
  end
end
