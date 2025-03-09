module Api
  module V1
    class CategoriesController < BaseController
      skip_before_action :authenticate_user, only: [:index, :show, :tree, :products]
      before_action :set_category, only: [:show, :update, :destroy, :products]

      # GET /api/v1/categories
      def index
        @categories = Category.all
        render_success(@categories)
      end

      # GET /api/v1/categories/:id
      def show
        render_success(@category)
      end

      # POST /api/v1/categories
      def create
        @category = Category.new(category_params)

        if @category.save
          render_success(@category, :created)
        else
          render_error(@category.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/categories/:id
      def update
        if @category.update(category_params)
          render_success(@category)
        else
          render_error(@category.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/categories/:id
      def destroy
        @category.destroy
        render_success({ message: 'Category deleted successfully' })
      end

      # GET /api/v1/categories/tree
      def tree
        @categories = Category.where(parent_id: nil).includes(:sub_categories)
        render_success(build_category_tree(@categories))
      end

      # GET /api/v1/categories/:id/products
      def products
        @products = @category.products

        # サブカテゴリの商品も含める
        if params[:include_subcategories] == 'true'
          sub_category_ids = @category.sub_categories.pluck(:id)
          @products = Product.where(category_id: [@category.id] + sub_category_ids)
        end

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

      def set_category
        @category = Category.find(params[:id])
      end

      def category_params
        params.require(:category).permit(
          :name, :description, :parent_id, :active, :display_order,
          :meta_title, :meta_description, :meta_keywords, :image
        )
      end

      def build_category_tree(categories)
        categories.map do |category|
          {
            id: category.id,
            name: category.name,
            description: category.description,
            active: category.active,
            display_order: category.display_order,
            children: build_category_tree(category.sub_categories)
          }
        end
      end

      def filter_products(products)
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
    end
  end
end
