class CategoryService
  attr_reader :category

  def initialize(category = nil)
    @category = category
  end

  # カテゴリ作成
  def create(params)
    @category = Category.new(params)

    if @category.save
      true
    else
      false
    end
  end

  # カテゴリ更新
  def update(params)
    return false unless @category

    if @category.update(params)
      true
    else
      false
    end
  end

  # カテゴリツリーの取得
  def category_tree
    # ルートカテゴリを取得
    root_categories = Category.where(parent_id: nil).order(:display_order)

    # カテゴリツリーを構築
    build_tree(root_categories)
  end

  # カテゴリ階層の取得
  def category_hierarchy
    return [] unless @category

    hierarchy = []
    current = @category

    # 親カテゴリを辿ってルートまで遡る
    while current
      hierarchy.unshift(current)
      current = current.parent
    end

    hierarchy
  end

  # サブカテゴリの取得
  def subcategories(include_inactive = false)
    return [] unless @category

    subcategories = @category.sub_categories

    # アクティブなカテゴリのみ取得
    subcategories = subcategories.where(active: true) unless include_inactive

    subcategories.order(:display_order)
  end

  # カテゴリに属する商品の取得
  def products(options = {})
    return [] unless @category

    # 基本クエリ
    products = @category.products

    # サブカテゴリの商品も含める
    if options[:include_subcategories]
      subcategory_ids = @category.sub_categories.pluck(:id)
      products = Product.where(category_id: [@category.id] + subcategory_ids)
    end

    # アクティブな商品のみ取得
    products = products.where(active: true) unless options[:include_inactive]

    # フィルタリング
    products = apply_filters(products, options)

    # ソート
    products = apply_sort(products, options[:sort])

    # ページネーション
    page = options[:page] || 1
    per_page = options[:per_page] || 20

    products.page(page).per(per_page)
  end

  # カテゴリの移動
  def move(new_parent_id, new_display_order = nil)
    return false unless @category

    # 親カテゴリの変更
    @category.parent_id = new_parent_id

    # 表示順の変更
    @category.display_order = new_display_order if new_display_order

    @category.save
  end

  # カテゴリの有効化/無効化
  def toggle_active
    return false unless @category

    @category.update(active: !@category.active)
  end

  # カテゴリのパンくずリストの取得
  def breadcrumbs
    return [] unless @category

    hierarchy = category_hierarchy

    hierarchy.map do |category|
      {
        id: category.id,
        name: category.name,
        slug: category.slug
      }
    end
  end

  # エラーメッセージの取得
  def error_message
    @category&.errors&.full_messages&.join(', ')
  end

  private

  # カテゴリツリーの構築
  def build_tree(categories)
    categories.map do |category|
      subcategories = category.sub_categories.order(:display_order)

      {
        id: category.id,
        name: category.name,
        description: category.description,
        active: category.active,
        display_order: category.display_order,
        image: category.image,
        product_count: category.products.count,
        children: build_tree(subcategories)
      }
    end
  end

  # フィルタの適用
  def apply_filters(products, options)
    # ブランドフィルタ
    products = products.where(brand_id: options[:brand_id]) if options[:brand_id].present?

    # 価格範囲フィルタ
    products = products.where('price >= ?', options[:min_price]) if options[:min_price].present?
    products = products.where('price <= ?', options[:max_price]) if options[:max_price].present?

    # 評価フィルタ
    if options[:min_rating].present?
      products = products.joins(:reviews)
                       .group('products.id')
                       .having('AVG(reviews.rating) >= ?', options[:min_rating])
    end

    # 在庫フィルタ
    if options[:in_stock] == true
      products = products.joins(:inventories)
                       .group('products.id')
                       .having('SUM(inventories.quantity) > 0')
    end

    products
  end

  # ソートの適用
  def apply_sort(products, sort)
    case sort
    when 'price_asc'
      products.order(price: :asc)
    when 'price_desc'
      products.order(price: :desc)
    when 'newest'
      products.order(created_at: :desc)
    when 'popularity'
      products.joins(:order_items)
            .select('products.*, COUNT(order_items.id) as order_count')
            .group('products.id')
            .order('order_count DESC')
    when 'rating'
      products.joins(:reviews)
            .select('products.*, AVG(reviews.rating) as avg_rating')
            .group('products.id')
            .order('avg_rating DESC')
    else
      products.order(created_at: :desc)
    end
  end
end
