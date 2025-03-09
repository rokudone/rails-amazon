module Api
  module V1
    class BrandsController < BaseController
      skip_before_action :authenticate_user, only: [:index, :show, :products]
      before_action :set_brand, only: [:show, :update, :destroy, :products]

      # GET /api/v1/brands
      def index
        @brands = Brand.all
        render_success(@brands)
      end

      # GET /api/v1/brands/:id
      def show
        render_success(@brand)
      end

      # POST /api/v1/brands
      def create
        @brand = Brand.new(brand_params)

        if @brand.save
          render_success(@brand, :created)
        else
          render_error(@brand.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/brands/:id
      def update
        if @brand.update(brand_params)
          render_success(@brand)
        else
          render_error(@brand.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/brands/:id
      def destroy
        @brand.destroy
        render_success({ message: 'Brand deleted successfully' })
      end

      # GET /api/v1/brands/:id/products
      def products
        @products = @brand.products

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

      private

      def set_brand
        @brand = Brand.find(params[:id])
      end

      def brand_params
        params.require(:brand).permit(
          :name, :description, :logo, :website, :active,
          :meta_title, :meta_description, :meta_keywords, :country_id
        )
      end

      def filter_products(products)
        # カテゴリフィルタ
        products = products.where(category_id: params[:category_id]) if params[:category_id].present?

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
    end
  end
end
