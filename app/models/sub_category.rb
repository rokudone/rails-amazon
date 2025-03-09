class SubCategory < ApplicationRecord
  # 関連付け
  belongs_to :category
  has_many :products, dependent: :nullify

  # バリデーション
  validates :name, presence: true, length: { maximum: 255 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 255 },
            format: { with: /\A[a-z0-9\-_]+\z/, message: "は小文字英数字、ハイフン、アンダースコアのみ使用できます" }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(position: :asc) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }

  # カスタムメソッド
  def active_products
    products.active
  end

  def path
    "#{category.name} > #{name}"
  end

  # コールバック
  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
