class ProductService
  attr_reader :product

  def initialize(product = nil)
    @product = product
  end

  # 商品作成
  def create(params)
    @product = Product.new(params)

    if @product.save
      # 価格履歴の記録
      PriceHistory.create(
        product_id: @product.id,
        old_price: nil,
        new_price: @product.price,
        changed_by: params[:changed_by] || 'system'
      )

      # 在庫の初期化
      initialize_inventory(params[:quantity], params[:warehouse_id])

      # 商品画像の処理
      process_images(params[:images]) if params[:images].present?

      # 商品属性の処理
      process_attributes(params[:attributes]) if params[:attributes].present?

      # 商品タグの処理
      process_tags(params[:tags]) if params[:tags].present?

      true
    else
      false
    end
  end

  # 商品更新
  def update(params)
    return false unless @product

    # 価格変更の場合は履歴を記録
    old_price = @product.price

    if @product.update(params)
      # 価格が変更された場合は履歴を記録
      if params[:price].present? && old_price != params[:price].to_f
        PriceHistory.create(
          product_id: @product.id,
          old_price: old_price,
          new_price: @product.price,
          changed_by: params[:changed_by] || 'system'
        )
      end

      # 在庫の更新
      update_inventory(params[:quantity], params[:warehouse_id]) if params[:quantity].present?

      # 商品画像の処理
      process_images(params[:images]) if params[:images].present?

      # 商品属性の処理
      process_attributes(params[:attributes]) if params[:attributes].present?

      # 商品タグの処理
      process_tags(params[:tags]) if params[:tags].present?

      true
    else
      false
    end
  end

  # 商品検索
  def search(query, options = {})
    products = Product.all

    # キーワード検索
    if query.present?
      products = products.where('name LIKE ? OR description LIKE ?', "%#{query}%", "%#{query}%")
    end

    # フィルタリング
    products = apply_filters(products, options)

    # ソート
    products = apply_sort(products, options[:sort])

    # ページネーション
    page = options[:page] || 1
    per_page = options[:per_page] || 20

    products.page(page).per(per_page)
  end

  # 商品フィルタリング
  def filter(options = {})
    products = Product.all

    # フィルタリング
    products = apply_filters(products, options)

    # ソート
    products = apply_sort(products, options[:sort])

    # ページネーション
    page = options[:page] || 1
    per_page = options[:per_page] || 20

    products.page(page).per(per_page)
  end

  # 関連商品の取得
  def related_products(limit = 10)
    return [] unless @product

    # 同じカテゴリの商品
    category_products = Product.where(category_id: @product.category_id)
                              .where.not(id: @product.id)
                              .limit(limit / 2)

    # 同じブランドの商品
    brand_products = Product.where(brand_id: @product.brand_id)
                           .where.not(id: @product.id)
                           .limit(limit / 2)

    # 結果を結合
    (category_products + brand_products).uniq.take(limit)
  end

  # 商品の平均評価を計算
  def calculate_average_rating
    return 0 unless @product

    @product.reviews.where(approved: true).average(:rating) || 0
  end

  # 商品の在庫状況を確認
  def check_inventory
    return { available: false, quantity: 0 } unless @product

    total_quantity = Inventory.where(product_id: @product.id).sum(:quantity)

    {
      available: total_quantity > 0,
      quantity: total_quantity
    }
  end

  # エラーメッセージの取得
  def error_message
    @product&.errors&.full_messages&.join(', ')
  end

  private

  # 在庫の初期化
  def initialize_inventory(quantity, warehouse_id = nil)
    return unless @product && quantity.present?

    warehouse = if warehouse_id.present?
                  Warehouse.find(warehouse_id)
                else
                  Warehouse.first || Warehouse.create(name: 'Default Warehouse', code: 'DEFAULT')
                end

    Inventory.create(
      product_id: @product.id,
      warehouse_id: warehouse.id,
      quantity: quantity
    )

    # 在庫移動の記録
    StockMovement.create(
      product_id: @product.id,
      warehouse_id: warehouse.id,
      quantity: quantity,
      movement_type: 'in',
      reference: 'Initial stock',
      notes: 'Product creation'
    )
  end

  # 在庫の更新
  def update_inventory(quantity, warehouse_id = nil)
    return unless @product && quantity.present?

    warehouse = if warehouse_id.present?
                  Warehouse.find(warehouse_id)
                else
                  Warehouse.first || Warehouse.create(name: 'Default Warehouse', code: 'DEFAULT')
                end

    inventory = Inventory.find_or_initialize_by(
      product_id: @product.id,
      warehouse_id: warehouse.id
    )

    old_quantity = inventory.quantity || 0
    inventory.quantity = quantity
    inventory.save

    # 在庫移動の記録
    quantity_diff = quantity - old_quantity

    if quantity_diff != 0
      StockMovement.create(
        product_id: @product.id,
        warehouse_id: warehouse.id,
        quantity: quantity_diff,
        movement_type: quantity_diff > 0 ? 'in' : 'out',
        reference: 'Stock update',
        notes: 'Product update'
      )
    end
  end

  # 商品画像の処理
  def process_images(images)
    return unless @product && images.present?

    images.each do |image|
      @product.product_images.create(
        image: image[:image],
        alt_text: image[:alt_text],
        display_order: image[:display_order],
        is_primary: image[:is_primary] || false
      )
    end
  end

  # 商品属性の処理
  def process_attributes(attributes)
    return unless @product && attributes.present?

    attributes.each do |attribute|
      @product.product_attributes.create(
        name: attribute[:name],
        value: attribute[:value]
      )
    end
  end

  # 商品タグの処理
  def process_tags(tags)
    return unless @product && tags.present?

    tags.each do |tag_name|
      tag = Tag.find_or_create_by(name: tag_name)

      ProductTag.create(
        product_id: @product.id,
        tag_id: tag.id
      )
    end
  end

  # フィルタの適用
  def apply_filters(products, options)
    # カテゴリフィルタ
    products = products.where(category_id: options[:category_id]) if options[:category_id].present?

    # ブランドフィルタ
    products = products.where(brand_id: options[:brand_id]) if options[:brand_id].present?

    # 価格範囲フィルタ
    products = products.where('price >= ?', options[:min_price]) if options[:min_price].present?
    products = products.where('price <= ?', options[:max_price]) if options[:max_price].present?

    # アクティブ商品のみ
    products = products.where(active: true) unless options[:include_inactive] == true

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
