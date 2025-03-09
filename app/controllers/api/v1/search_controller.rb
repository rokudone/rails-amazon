module Api
  module V1
    class SearchController < BaseController
      skip_before_action :authenticate_user

      # GET /api/v1/search
      def index
        query = params[:q]

        unless query.present?
          render_error('Search query is required')
          return
        end

        # 検索履歴の保存
        save_search_history(query) if current_user

        # 商品検索
        @products = search_products(query)

        # カテゴリ検索
        @categories = search_categories(query)

        # ブランド検索
        @brands = search_brands(query)

        # セラー検索
        @sellers = search_sellers(query)

        render_success({
          query: query,
          products: {
            items: @products,
            total: @products.total_count,
            total_pages: @products.total_pages,
            current_page: @products.current_page
          },
          categories: @categories,
          brands: @brands,
          sellers: @sellers
        })
      end

      # GET /api/v1/search/advanced
      def advanced
        # 高度な検索機能
        @products = Product.all

        # キーワード検索
        @products = @products.where('name LIKE ? OR description LIKE ?', "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?

        # カテゴリフィルタ
        @products = @products.where(category_id: params[:category_id]) if params[:category_id].present?

        # ブランドフィルタ
        @products = @products.where(brand_id: params[:brand_id]) if params[:brand_id].present?

        # 価格範囲フィルタ
        @products = @products.where('price >= ?', params[:min_price]) if params[:min_price].present?
        @products = @products.where('price <= ?', params[:max_price]) if params[:max_price].present?

        # 評価フィルタ
        if params[:min_rating].present?
          @products = @products.joins(:reviews)
                             .group('products.id')
                             .having('AVG(reviews.rating) >= ?', params[:min_rating])
        end

        # 在庫フィルタ
        if params[:in_stock] == 'true'
          @products = @products.joins(:inventories)
                             .group('products.id')
                             .having('SUM(inventories.quantity) > 0')
        end

        # 検索履歴の保存
        save_search_history(params[:q]) if current_user && params[:q].present?

        # ページネーション
        @products = @products.page(params[:page] || 1).per(params[:per_page] || 20)

        render_success({
          products: @products,
          total: @products.total_count,
          total_pages: @products.total_pages,
          current_page: @products.current_page,
          filters: {
            query: params[:q],
            category_id: params[:category_id],
            brand_id: params[:brand_id],
            min_price: params[:min_price],
            max_price: params[:max_price],
            min_rating: params[:min_rating],
            in_stock: params[:in_stock]
          }
        })
      end

      # GET /api/v1/search/filter
      def filter
        # フィルタリング機能
        @products = Product.all

        # アクティブな商品のみ
        @products = @products.where(active: true)

        # フィルタの適用
        @products = apply_filters(@products)

        # ページネーション
        @products = @products.page(params[:page] || 1).per(params[:per_page] || 20)

        render_success({
          products: @products,
          total: @products.total_count,
          total_pages: @products.total_pages,
          current_page: @products.current_page,
          filters: params.permit(:category_id, :brand_id, :min_price, :max_price, :min_rating, :in_stock)
        })
      end

      # GET /api/v1/search/sort
      def sort
        # ソート機能
        @products = Product.where(active: true)

        # フィルタの適用
        @products = apply_filters(@products)

        # ソートの適用
        @products = apply_sort(@products)

        # ページネーション
        @products = @products.page(params[:page] || 1).per(params[:per_page] || 20)

        render_success({
          products: @products,
          total: @products.total_count,
          total_pages: @products.total_pages,
          current_page: @products.current_page,
          sort: params[:sort]
        })
      end

      # GET /api/v1/search/facets
      def facets
        # ファセット検索
        @products = Product.where(active: true)

        # キーワード検索
        @products = @products.where('name LIKE ? OR description LIKE ?', "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?

        # カテゴリファセット
        @category_facets = Category.joins(:products)
                                 .where(products: { id: @products })
                                 .group('categories.id')
                                 .select('categories.id, categories.name, COUNT(products.id) as product_count')
                                 .order('product_count DESC')

        # ブランドファセット
        @brand_facets = Brand.joins(:products)
                           .where(products: { id: @products })
                           .group('brands.id')
                           .select('brands.id, brands.name, COUNT(products.id) as product_count')
                           .order('product_count DESC')

        # 価格範囲ファセット
        @price_ranges = [
          { min: 0, max: 50, count: @products.where('price BETWEEN ? AND ?', 0, 50).count },
          { min: 50, max: 100, count: @products.where('price BETWEEN ? AND ?', 50, 100).count },
          { min: 100, max: 200, count: @products.where('price BETWEEN ? AND ?', 100, 200).count },
          { min: 200, max: 500, count: @products.where('price BETWEEN ? AND ?', 200, 500).count },
          { min: 500, max: nil, count: @products.where('price >= ?', 500).count }
        ]

        # 評価ファセット
        @rating_facets = [5, 4, 3, 2, 1].map do |rating|
          {
            rating: rating,
            count: @products.joins(:reviews)
                          .group('products.id')
                          .having('AVG(reviews.rating) >= ? AND AVG(reviews.rating) < ?', rating, rating + 1)
                          .count
          }
        end

        render_success({
          query: params[:q],
          total_products: @products.count,
          facets: {
            categories: @category_facets,
            brands: @brand_facets,
            price_ranges: @price_ranges,
            ratings: @rating_facets
          }
        })
      end

      private

      def search_products(query)
        products = Product.where(active: true)
                        .where('name LIKE ? OR description LIKE ?', "%#{query}%", "%#{query}%")

        # フィルタの適用
        products = apply_filters(products)

        # ソートの適用
        products = apply_sort(products)

        # ページネーション
        products.page(params[:page] || 1).per(params[:per_page] || 20)
      end

      def search_categories(query)
        Category.where('name LIKE ? OR description LIKE ?', "%#{query}%", "%#{query}%")
              .limit(5)
      end

      def search_brands(query)
        Brand.where('name LIKE ? OR description LIKE ?', "%#{query}%", "%#{query}%")
            .limit(5)
      end

      def search_sellers(query)
        Seller.where(active: true, verified: true)
             .where('business_name LIKE ? OR description LIKE ?', "%#{query}%", "%#{query}%")
             .limit(5)
      end

      def apply_filters(products)
        # カテゴリフィルタ
        products = products.where(category_id: params[:category_id]) if params[:category_id].present?

        # ブランドフィルタ
        products = products.where(brand_id: params[:brand_id]) if params[:brand_id].present?

        # 価格範囲フィルタ
        products = products.where('price >= ?', params[:min_price]) if params[:min_price].present?
        products = products.where('price <= ?', params[:max_price]) if params[:max_price].present?

        # 評価フィルタ
        if params[:min_rating].present?
          products = products.joins(:reviews)
                           .group('products.id')
                           .having('AVG(reviews.rating) >= ?', params[:min_rating])
        end

        # 在庫フィルタ
        if params[:in_stock] == 'true'
          products = products.joins(:inventories)
                           .group('products.id')
                           .having('SUM(inventories.quantity) > 0')
        end

        products
      end

      def apply_sort(products)
        case params[:sort]
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

      def save_search_history(query)
        current_user.search_histories.create(
          query: query,
          results_count: @products&.total_count || 0
        )
      end
    end
  end
end
