class ProductSerializer < BaseSerializer
  # 基本属性
  attributes :id, :name, :short_description, :price, :sku, :upc, :manufacturer
  attributes :is_active, :is_featured, :published_at, :created_at, :updated_at

  # 価格関連の属性
  attribute :formatted_price, method: :format_price
  attribute :price_with_tax, method: :calculate_price_with_tax
  attribute :discount_percentage, method: :calculate_discount_percentage

  # 関連データ
  has_one :brand, serializer: BrandSerializer
  has_one :category, serializer: CategorySerializer
  has_one :seller, serializer: SellerSerializer
  has_many :product_variants, serializer: ProductVariantSerializer
  has_many :product_images, serializer: ProductImageSerializer
  has_many :product_videos, serializer: ProductVideoSerializer
  has_many :product_documents, serializer: ProductDocumentSerializer
  has_one :product_description, serializer: ProductDescriptionSerializer
  has_many :product_specifications, serializer: ProductSpecificationSerializer
  has_many :product_tags, serializer: ProductTagSerializer
  has_many :reviews, serializer: ReviewSerializer

  # 集計データ
  attribute :average_rating, method: :calculate_average_rating
  attribute :review_count, method: :calculate_review_count
  attribute :in_stock, method: :check_in_stock
  attribute :stock_quantity, method: :get_stock_quantity

  # メタデータ
  meta :breadcrumbs, method: :generate_breadcrumbs
  meta :related_products, method: :find_related_products
  meta :recently_viewed, method: :get_recently_viewed

  # 価格をフォーマット
  def format_price(product)
    "¥#{product.price.to_i.to_s(:delimited)}" if product.price
  end

  # 税込価格を計算
  def calculate_price_with_tax(product)
    return nil unless product.price

    tax_rate = 0.1 # 10%
    (product.price * (1 + tax_rate)).round(2)
  end

  # 割引率を計算
  def calculate_discount_percentage(product)
    return nil unless product.price && product.product_variants.present?

    # 最も高い定価を持つバリアントを探す
    max_compare_price = product.product_variants.map(&:compare_at_price).compact.max

    return nil unless max_compare_price && max_compare_price > 0

    # 割引率を計算
    discount = ((max_compare_price - product.price) / max_compare_price * 100).round

    # 割引がある場合のみ返す
    discount > 0 ? discount : nil
  end

  # 平均評価を計算
  def calculate_average_rating(product)
    return nil unless product.reviews.present?

    # 評価の平均を計算
    product.reviews.average(:rating)&.round(1)
  end

  # レビュー数を計算
  def calculate_review_count(product)
    product.reviews.count
  end

  # 在庫があるかチェック
  def check_in_stock(product)
    return false unless product.respond_to?(:inventory)

    # 在庫があるかチェック
    product.inventory&.quantity.to_i > 0
  end

  # 在庫数を取得
  def get_stock_quantity(product)
    return 0 unless product.respond_to?(:inventory)

    # 在庫数を取得
    product.inventory&.quantity.to_i
  end

  # パンくずリストを生成
  def generate_breadcrumbs(product)
    breadcrumbs = []

    # ホームを追加
    breadcrumbs << { name: 'Home', url: '/' }

    # カテゴリを追加
    if product.category
      # 親カテゴリがある場合は追加
      if product.category.parent_id
        parent_category = Category.find_by(id: product.category.parent_id)
        if parent_category
          breadcrumbs << { name: parent_category.name, url: "/categories/#{parent_category.id}" }
        end
      end

      # カテゴリを追加
      breadcrumbs << { name: product.category.name, url: "/categories/#{product.category.id}" }
    end

    # 商品を追加
    breadcrumbs << { name: product.name, url: "/products/#{product.id}" }

    breadcrumbs
  end

  # 関連商品を検索
  def find_related_products(product)
    return [] unless product.category

    # 同じカテゴリの商品を検索
    related = Product.where(category_id: product.category_id)
                    .where.not(id: product.id)
                    .where(is_active: true)
                    .limit(5)

    # 関連商品をシリアライズ
    ProductSerializer.new(related, { except: [:product_description, :product_specifications] }).serialize
  end

  # 最近見た商品を取得
  def get_recently_viewed(product)
    # 実際のアプリケーションでは、ユーザーのセッションや履歴から取得
    # ここではシミュレーションのみ
    []
  end
end

# BrandSerializer
class BrandSerializer < BaseSerializer
  attributes :id, :name, :description, :logo, :website, :country_of_origin, :year_established
end

# CategorySerializer
class CategorySerializer < BaseSerializer
  attributes :id, :name, :description, :slug, :position, :is_active

  # 親カテゴリ
  has_one :parent, serializer: CategorySerializer, method: :parent_category

  # 子カテゴリ
  has_many :children, serializer: CategorySerializer, method: :child_categories

  # 親カテゴリを取得
  def parent_category(category)
    Category.find_by(id: category.parent_id) if category.parent_id
  end

  # 子カテゴリを取得
  def child_categories(category)
    Category.where(parent_id: category.id)
  end
end

# SellerSerializer
class SellerSerializer < BaseSerializer
  attributes :id, :name, :description, :logo, :rating, :is_verified

  # 機密情報は除外
  attribute :email, if: ->(seller, options) { options[:include_private] }
  attribute :phone, if: ->(seller, options) { options[:include_private] }
end

# ProductVariantSerializer
class ProductVariantSerializer < BaseSerializer
  attributes :id, :sku, :name, :price, :compare_at_price, :color, :size, :material, :style, :weight, :is_active

  # 画像
  has_many :product_images, serializer: ProductImageSerializer

  # 在庫
  attribute :in_stock, method: :check_in_stock
  attribute :stock_quantity, method: :get_stock_quantity

  # 在庫があるかチェック
  def check_in_stock(variant)
    return false unless variant.respond_to?(:inventory)

    # 在庫があるかチェック
    variant.inventory&.quantity.to_i > 0
  end

  # 在庫数を取得
  def get_stock_quantity(variant)
    return 0 unless variant.respond_to?(:inventory)

    # 在庫数を取得
    variant.inventory&.quantity.to_i
  end
end

# ProductImageSerializer
class ProductImageSerializer < BaseSerializer
  attributes :id, :image_url, :alt_text, :position, :is_primary
end

# ProductVideoSerializer
class ProductVideoSerializer < BaseSerializer
  attributes :id, :video_url, :thumbnail_url, :title, :description, :position
end

# ProductDocumentSerializer
class ProductDocumentSerializer < BaseSerializer
  attributes :id, :document_url, :title, :document_type, :position
end

# ProductDescriptionSerializer
class ProductDescriptionSerializer < BaseSerializer
  attributes :id, :full_description, :features, :care_instructions, :warranty_info, :return_policy
end

# ProductSpecificationSerializer
class ProductSpecificationSerializer < BaseSerializer
  attributes :id, :name, :value, :unit, :position
end

# ProductTagSerializer
class ProductTagSerializer < BaseSerializer
  attributes :id

  # タグ
  has_one :tag, serializer: TagSerializer
end

# TagSerializer
class TagSerializer < BaseSerializer
  attributes :id, :name, :slug
end

# ReviewSerializer
class ReviewSerializer < BaseSerializer
  attributes :id, :title, :content, :rating, :created_at

  # ユーザー
  has_one :user, serializer: UserSerializer

  # 画像
  has_many :review_images, serializer: ReviewImageSerializer

  # 投票
  attribute :helpful_count, method: :calculate_helpful_count

  # 役立つ投票数を計算
  def calculate_helpful_count(review)
    review.review_votes.where(helpful: true).count
  end
end

# ReviewImageSerializer
class ReviewImageSerializer < BaseSerializer
  attributes :id, :image_url, :caption
end

# UserSerializer
class UserSerializer < BaseSerializer
  attributes :id, :first_name, :last_name

  # フルネーム
  attribute :full_name, method: :get_full_name

  # アバター
  attribute :avatar, method: :get_avatar

  # フルネームを取得
  def get_full_name(user)
    "#{user.first_name} #{user.last_name}".strip
  end

  # アバターを取得
  def get_avatar(user)
    user.profile&.avatar
  end
end
