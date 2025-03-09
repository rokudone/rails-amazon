class Product < ApplicationRecord
  # 関連付け
  belongs_to :brand, optional: true
  belongs_to :category, optional: true
  belongs_to :seller, optional: true

  has_many :product_variants, dependent: :destroy
  has_many :product_attributes, dependent: :destroy
  has_many :product_images, dependent: :destroy
  has_many :product_videos, dependent: :destroy
  has_many :product_documents, dependent: :destroy
  has_one :product_description, dependent: :destroy
  has_many :product_specifications, dependent: :destroy
  has_many :price_histories, dependent: :destroy

  has_many :product_accessories, dependent: :destroy
  has_many :accessories, through: :product_accessories, source: :accessory

  has_many :product_tags, dependent: :destroy
  has_many :tags, through: :product_tags

  # バリデーション
  validates :name, presence: true, length: { maximum: 255 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :sku, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :upc, length: { maximum: 50 }, allow_blank: true
  validates :manufacturer, length: { maximum: 255 }, allow_blank: true

  # コールバック
  before_validation :set_defaults

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :featured, -> { where(is_featured: true) }
  scope :published, -> { where.not(published_at: nil).where('published_at <= ?', Time.current) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }
  scope :by_brand, ->(brand_id) { where(brand_id: brand_id) }
  scope :by_price_range, ->(min, max) { where('price >= ? AND price <= ?', min, max) }
  scope :recent, -> { order(created_at: :desc) }
  scope :popular, -> { order(popularity: :desc) } # 仮定: popularityカラムが後で追加される

  # カスタムメソッド
  def available_variants
    product_variants.where(is_active: true)
  end

  def primary_image
    product_images.find_by(is_primary: true) || product_images.first
  end

  def price_with_discount
    # 仮定: 割引ロジックが後で実装される
    price
  end

  def in_stock?
    # 仮定: 在庫ロジックが後で実装される
    true
  end

  def related_products
    # 仮定: 関連商品ロジックが後で実装される
    Product.where(category_id: category_id).where.not(id: id).limit(5)
  end

  private

  def set_defaults
    self.is_active = true if is_active.nil?
    self.is_featured = false if is_featured.nil?
  end
end
