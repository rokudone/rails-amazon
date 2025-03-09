module Api
  module V1
    class ProductsController < BaseController
      skip_before_action :authenticate_user, only: [:index, :show, :search, :featured, :bestsellers, :new_arrivals, :related]
      before_action :set_product, only: [:show, :update, :destroy, :related]

      # GET /api/v1/products
      def index
        @products = Product.all

        # フィルタリング
        @products = filter_products(@products)

        # ソート
        @products = sort_products(@products)

        # ページネーション
        @products = @products.page(params[:page] || 1).per(params[:per_page] || 20)

        render_success({
          products: @products,
          total: @products.total_count,
          total_pages: @products.total_pages,
          current_page: @products.current_page
        })
      end

      # GET /api/v1/products/:id
      def show
        # 最近閲覧した商品に追加
        add_to_recently_viewed(@product) if current_user

        render_success(@product)
      end

      # POST /api/v1/products
      def create
        @product = Product.new(product_params)

        if @product.save
          render_success(@product, :created)
        else
          render_error(@product.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/products/:id
      def update
        if @product.update(product_params)
          render_success(@product)
        else
          render_error(@product.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/products/:id
      def destroy
        @product.destroy
        render_success({ message: 'Product deleted successfully' })
      end

      # GET /api/v1/products/search
      def search
        @products = Product.all

        # 検索クエリ
        if params[:q].present?
          @products = @products.where('name LIKE ? OR description LIKE ?', "%#{params[:q]}%", "%#{params[:q]}%")
        end

        # フィルタリング
        @products = filter_products(@products)

        # ソート
        @products = sort_products(@products)

        # ページネーション
        @products = @products.page(params[:page] || 1).per(params[:per_page] || 20)

        # 検索履歴の保存
        save_search_history(params[:q]) if current_user && params[:q].present?

        render_success({
          products: @products,
          total: @products.total_count,
          total_pages: @products.total_pages,
          current_page: @products.current_page
        })
      end

      # GET /api/v1/products/featured
      def featured
        @products = Product.where(featured: true)

        # ページネーション
        @products = @products.page(params[:page] || 1).per(params[:per_page] || 20)

        render_success({
          products: @products,
          total: @products.total_count,
          total_pages: @products.total_pages,
          current_page: @products.current_page
        })
      end

      # GET /api/v1/products/bestsellers
      def bestsellers
        @products = Product.joins(:order_items)
                          .select('products.*, COUNT(order_items.id) as order_count')
                          .group('products.id')
                          .order('order_count DESC')

        # ページネーション
        @products = @products.page(params[:page] || 1).per(params[:per_page] || 20)

        render_success({
          products: @products,
          total: @products.total_count,
          total_pages: @products.total_pages,
          current_page: @products.current_page
        })
      end

      # GET /api/v1/products/new_arrivals
      def new_arrivals
        @products = Product.order(created_at: :desc)

        # ページネーション
        @products = @products.page(params[:page] || 1).per(params[:per_page] || 20)

        render_success({
          products: @products,
          total: @products.total_count,
          total_pages: @products.total_pages,
          current_page: @products.current_page
        })
      end

      # GET /api/v1/products/:id/related
      def related
        @related_products = @product.category.products.where.not(id: @product.id).limit(10)
        render_success(@related_products)
      end

      private

      def set_product
        @product = Product.find(params[:id])
      end

      def product_params
        params.require(:product).permit(
          :name, :description, :price, :sale_price, :cost_price, :sku, :barcode,
          :quantity, :featured, :active, :category_id, :brand_id, :tax_rate,
          :weight, :width, :height, :depth, :meta_title, :meta_description, :meta_keywords
        )
      end

      def filter_products(products)
        # カテゴリフィルタ
        products = products.where(category_id: params[:category_id]) if params[:category_id].present?

        # ブランドフィルタ
        products = products.where(brand_id: params[:brand_id]) if params[:brand_id].present?

        # 価格範囲フィルタ
        products = products.where('price >= ?', params[:min_price]) if params[:min_price].present?
        products = products.where('price <= ?', params[:max_price]) if params[:max_price].present?

        # アクティブ商品のみ
        products = products.where(active: true) unless params[:include_inactive] == 'true'

        products
      end

      def sort_products(products)
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

      def add_to_recently_viewed(product)
        recently_viewed = current_user.recently_vieweds.find_or_initialize_by(product_id: product.id)
        recently_viewed.viewed_at = Time.current
        recently_viewed.save
      end

      def save_search_history(query)
        current_user.search_histories.create(
          query: query,
          results_count: @products.total_count
        )
      end
    end
  end
end
