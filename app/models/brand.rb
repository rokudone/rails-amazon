class Brand < ApplicationRecord
  # 関連付け
  has_many :products, dependent: :nullify

  # バリデーション
  validates :name, presence: true, length: { maximum: 255 }
  validates :website, format: { with: URI::regexp(%w(http https)), message: "は有効なURLである必要があります" }, allow_blank: true
  validates :year_established, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :alphabetical, -> { order(name: :asc) }
  scope :with_products, -> { joins(:products).distinct }
  scope :popular, -> { joins(:products).group(:id).order('COUNT(products.id) DESC') }

  # カスタムメソッド
  def active_products
    products.active
  end

  def product_count
    products.count
  end

  def logo_url
    logo.presence || "https://via.placeholder.com/150x150.png?text=#{URI.encode_www_form_component(name)}"
  end

  def age
    return nil unless year_established
    Time.current.year - year_established
  end
end
