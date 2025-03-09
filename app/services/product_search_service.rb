class ProductSearchService
  attr_reader :query, :options, :results

  def initialize(query = nil, options = {})
    @query = query
    @options = options
    @results = nil
  end

  # 検索実行
  def search
    products = Product.all

    # アクティブな商品のみ
    products = products.where(active: true) unless @options[:include_inactive]

    # キーワード検索
    if @query.present?
      products = search_by_keyword(products, @query)
    end

    # フィルタリング
    products = apply_filters(products)

    # ファセット検索
    facets = generate_facets(products) if @options[:facets]

    # ソート
    products = apply_sort(products)

    # ページネーション
    page = @options[:page] || 1
    per_page = @options[:per_page] || 20

    @results = products.page(page).per(per_page)

    # 検索履歴の保存
    save_search_history if @options[:user_id] && @query.present?

    {
      products: @results,
      total: @results.total_count,
      total_pages: @results.total_pages,
      current_page: @results.current_page,
      facets: facets
    }
  end

  # 高度な検索
  def advanced_search
    products = Product.all

    # アクティブな商品のみ
    products = products.where(active: true) unless @options[:include_inactive]

    # キーワード検索（複数フィールド）
    if @query.present?
      products = search_by_keyword(products, @query)
    end

    # 詳細フィルタリング
    products = apply_advanced_filters(products)

    # ファセット検索
    facets = generate_facets(products) if @options[:facets]

    # ソート
    products = apply_sort(products)

    # ページネーション
    page = @options[:page] || 1
    per_page = @options[:per_page] || 20

    @results = products.page(page).per(per_page)

    # 検索履歴の保存
    save_search_history if @options[:user_id] && @query.present?

    {
      products: @results,
      total: @results.total_count,
      total_pages: @results.total_pages,
      current_page: @results.current_page,
      facets: facets,
      applied_filters: extract_applied_filters
    }
  end

  # フィルタリング
  def filter
    products = Product.where(active: true)

    # フィルタリング
    products = apply_filters(products)

    # ファセット検索
    facets = generate_facets(products) if @options[:facets]

    # ソート
    products = apply_sort(products)

    # ページネーション
    page = @options[:page] || 1
    per_page = @options[:per_page] || 20

    @results = products.page(page).per(per_page)

    {
      products: @results,
      total: @results.total_count,
      total_pages: @results.total_pages,
      current_page: @results.current_page,
      facets: facets,
      applied_filters: extract_applied_filters
    }
  end

  # ソート
  def sort
    return {} unless @results

    # ソート
    sorted_products = apply_sort(@results)

    # ページネーション
    page = @options[:page] || 1
    per_page = @options[:per_page] || 20

    sorted_results = sorted_products.page(page).per(per_page)

    {
      products: sorted_results,
      total: sorted_results.total_count,
      total_pages: sorted_results.total_pages,
      current_page: sorted_results.current_page,
      sort: @options[:sort]
    }
  end

  # ファセット検索
  def facets
    products = Product.where(active: true)

    # キーワード検索
    if @query.present?
      products = search_by_keyword(products, @query)
    end

    # フィルタリング
    products = apply_filters(products)

    # ファセット生成
    generate_facets(products)
  end

  private

  # キーワードによる検索
  def search_by_keyword(products, keyword)
    # 複数のフィールドで検索
    products.where(
      'name LIKE :query OR description LIKE :query OR sku LIKE :query',
      query: "%#{keyword}%"
    )
  end

  # フィルタの適用
  def apply_filters(products)
    # カテゴリフィルタ
    if @options[:category_id].present?
      if @options[:include_subcategories]
        category = Category.find_by(id: @options[:category_id])
        if category
          subcategory_ids = category.sub_categories.pluck(:id)
          products = products.where(category_id: [@options[:category_id]] + subcategory_ids)
        else
          products = products.where(category_id: @options[:category_id])
        end
      else
        products = products.where(category_id: @options[:category_id])
      end
    end

    # ブランドフィルタ
    products = products.where(brand_id: @options[:brand_id]) if @options[:brand_id].present?

    # 価格範囲フィルタ
    products = products.where('price >= ?', @options[:min_price]) if @options[:min_price].present?
    products = products.where('price <= ?', @options[:max_price]) if @options[:max_price].present?

    # 評価フィルタ
    if @options[:min_rating].present?
      products = products.joins(:reviews)
                       .group('products.id')
                       .having('AVG(reviews.rating) >= ?', @options[:min_rating])
    end

    # 在庫フィルタ
    if @options[:in_stock] == true
      products = products.joins(:inventories)
                       .group('products.id')
                       .having('SUM(inventories.quantity) > 0')
    end

    # タグフィルタ
    if @options[:tags].present?
      tag_ids = Tag.where(name: @options[:tags]).pluck(:id)
      products = products.joins(:product_tags)
                       .where(product_tags: { tag_id: tag_ids })
                       .group('products.id')
                       .having('COUNT(DISTINCT product_tags.tag_id) = ?', tag_ids.size)
    end

    products
  end

  # 高度なフィルタの適用
  def apply_advanced_filters(products)
    # 基本フィルタを適用
    products = apply_filters(products)

    # 属性フィルタ
    if @options[:attributes].present?
      @options[:attributes].each do |attr_name, attr_value|
        products = products.joins(:product_attributes)
                         .where(product_attributes: { name: attr_name, value: attr_value })
      end
    end

    # 新着商品フィルタ
    if @options[:new_arrivals]
      products = products.where('created_at >= ?', 30.days.ago)
    end

    # セール商品フィルタ
    if @options[:on_sale]
      products = products.where('sale_price IS NOT NULL AND sale_price > 0')
                       .where('sale_start_date IS NULL OR sale_start_date <= ?', Time.current)
                       .where('sale_end_date IS NULL OR sale_end_date >= ?', Time.current)
    end

    # 特定のセラーの商品フィルタ
    if @options[:seller_id].present?
      products = products.joins(:seller_products)
                       .where(seller_products: { seller_id: @options[:seller_id] })
    end

    products
  end

  # ソートの適用
  def apply_sort(products)
    case @options[:sort]
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
    when 'relevance'
      # キーワード検索の場合は関連性でソート
      if @query.present?
        products.order(Arel.sql("CASE WHEN name LIKE '%#{@query}%' THEN 1 ELSE 2 END"))
      else
        products.order(created_at: :desc)
      end
    else
      products.order(created_at: :desc)
    end
  end

  # ファセットの生成
  def generate_facets(products)
    # カテゴリファセット
    category_facets = Category.joins(:products)
                            .where(products: { id: products })
                            .group('categories.id')
                            .select('categories.id, categories.name, COUNT(products.id) as product_count')
                            .order('product_count DESC')
                            .limit(10)

    # ブランドファセット
    brand_facets = Brand.joins(:products)
                       .where(products: { id: products })
                       .group('brands.id')
                       .select('brands.id, brands.name, COUNT(products.id) as product_count')
                       .order('product_count DESC')
                       .limit(10)

    # 価格範囲ファセット
    price_ranges = [
      { min: 0, max: 50, count: products.where('price BETWEEN ? AND ?', 0, 50).count },
      { min: 50, max: 100, count: products.where('price BETWEEN ? AND ?', 50, 100).count },
      { min: 100, max: 200, count: products.where('price BETWEEN ? AND ?', 100, 200).count },
      { min: 200, max: 500, count: products.where('price BETWEEN ? AND ?', 200, 500).count },
      { min: 500, max: nil, count: products.where('price >= ?', 500).count }
    ]

    # 評価ファセット
    rating_facets = [5, 4, 3, 2, 1].map do |rating|
      {
        rating: rating,
        count: products.joins(:reviews)
                      .group('products.id')
                      .having('AVG(reviews.rating) >= ? AND AVG(reviews.rating) < ?', rating, rating + 1)
                      .count
      }
    end

    # タグファセット
    tag_facets = Tag.joins(:products)
                   .where(products: { id: products })
                   .group('tags.id')
                   .select('tags.id, tags.name, COUNT(products.id) as product_count')
                   .order('product_count DESC')
                   .limit(10)

    {
      categories: category_facets,
      brands: brand_facets,
      price_ranges: price_ranges,
      ratings: rating_facets,
      tags: tag_facets
    }
  end

  # 適用されたフィルタの抽出
  def extract_applied_filters
    applied_filters = {}

    applied_filters[:query] = @query if @query.present?
    applied_filters[:category_id] = @options[:category_id] if @options[:category_id].present?
    applied_filters[:brand_id] = @options[:brand_id] if @options[:brand_id].present?
    applied_filters[:min_price] = @options[:min_price] if @options[:min_price].present?
    applied_filters[:max_price] = @options[:max_price] if @options[:max_price].present?
    applied_filters[:min_rating] = @options[:min_rating] if @options[:min_rating].present?
    applied_filters[:in_stock] = @options[:in_stock] if @options[:in_stock].present?
    applied_filters[:tags] = @options[:tags] if @options[:tags].present?
    applied_filters[:attributes] = @options[:attributes] if @options[:attributes].present?
    applied_filters[:sort] = @options[:sort] if @options[:sort].present?

    applied_filters
  end

  # 検索履歴の保存
  def save_search_history
    user = User.find_by(id: @options[:user_id])
    return unless user

    user.search_histories.create(
      query: @query,
      results_count: @results&.total_count || 0,
      filters: extract_applied_filters.to_json
    )
  end
end
