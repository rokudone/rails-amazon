module Api
  module V1
    class SellersController < BaseController
      skip_before_action :authenticate_user, only: [:index, :show]
      before_action :set_seller, only: [:show, :update, :destroy, :rate, :products]

      # GET /api/v1/sellers
      def index
        @sellers = Seller.all

        # アクティブなセラーのみ表示（管理者以外）
        @sellers = @sellers.where(active: true, verified: true) unless current_user&.admin?

        # 評価でフィルタリング
        @sellers = @sellers.where('average_rating >= ?', params[:min_rating]) if params[:min_rating].present?

        # 国でフィルタリング
        @sellers = @sellers.where(country_id: params[:country_id]) if params[:country_id].present?

        # ソート
        case params[:sort]
        when 'rating_desc'
          @sellers = @sellers.order(average_rating: :desc)
        when 'rating_asc'
          @sellers = @sellers.order(average_rating: :asc)
        when 'newest'
          @sellers = @sellers.order(created_at: :desc)
        when 'oldest'
          @sellers = @sellers.order(created_at: :asc)
        else
          @sellers = @sellers.order(average_rating: :desc)
        end

        # ページネーション
        @sellers = @sellers.page(params[:page] || 1).per(params[:per_page] || 20)

        render_success({
          sellers: @sellers,
          total: @sellers.total_count,
          total_pages: @sellers.total_pages,
          current_page: @sellers.current_page
        })
      end

      # GET /api/v1/sellers/:id
      def show
        # アクティブなセラーのみ表示（管理者以外）
        unless @seller.active && @seller.verified || current_user&.admin?
          render_forbidden
          return
        end

        render_success(@seller)
      end

      # POST /api/v1/sellers
      def create
        # 既にセラーとして登録されていないかチェック
        if Seller.exists?(user_id: current_user.id)
          render_error('You are already registered as a seller')
          return
        end

        @seller = Seller.new(seller_params)
        @seller.user_id = current_user.id
        @seller.active = false
        @seller.verified = false

        if @seller.save
          render_success(@seller, :created)
        else
          render_error(@seller.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/sellers/:id
      def update
        # セラー本人または管理者のみ更新可能
        unless @seller.user_id == current_user.id || current_user.admin?
          render_forbidden
          return
        end

        # 管理者以外は特定のフィールドのみ更新可能
        unless current_user.admin?
          params[:seller].delete(:active)
          params[:seller].delete(:verified)
          params[:seller].delete(:verification_status)
          params[:seller].delete(:rejection_reason)
        end

        if @seller.update(seller_params)
          render_success(@seller)
        else
          render_error(@seller.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/sellers/:id
      def destroy
        # セラー本人または管理者のみ削除可能
        unless @seller.user_id == current_user.id || current_user.admin?
          render_forbidden
          return
        end

        @seller.destroy
        render_success({ message: 'Seller deleted successfully' })
      end

      # POST /api/v1/sellers/authenticate
      def authenticate
        # セラー認証のシミュレーション
        # 実際の実装では、提供された書類の検証などが必要

        # 既にセラーとして登録されていないかチェック
        if Seller.exists?(user_id: current_user.id)
          render_error('You are already registered as a seller')
          return
        end

        @seller = Seller.new(seller_params)
        @seller.user_id = current_user.id
        @seller.active = false
        @seller.verified = false
        @seller.verification_status = 'pending'

        if @seller.save
          # セラー書類の保存
          if params[:documents].present?
            params[:documents].each do |document|
              @seller.seller_documents.create(
                document_type: document[:document_type],
                file: document[:file],
                description: document[:description]
              )
            end
          end

          render_success({
            seller: @seller,
            message: 'Seller registration submitted successfully. Your application is under review.'
          }, :created)
        else
          render_error(@seller.errors.full_messages.join(', '))
        end
      end

      # POST /api/v1/sellers/:id/rate
      def rate
        # アクティブなセラーのみ評価可能
        unless @seller.active && @seller.verified
          render_error('Seller is not active')
          return
        end

        # 既に評価していないかチェック
        if SellerRating.exists?(user_id: current_user.id, seller_id: @seller.id)
          render_error('You have already rated this seller')
          return
        end

        # セラーから購入したことがあるかチェック
        unless has_purchased_from_seller?(@seller.id)
          render_error('You can only rate sellers you have purchased from')
          return
        end

        @rating = @seller.seller_ratings.new(
          user_id: current_user.id,
          rating: params[:rating],
          comment: params[:comment]
        )

        if @rating.save
          # セラーの平均評価を更新
          update_seller_average_rating(@seller)

          render_success({
            rating: @rating,
            message: 'Seller rated successfully'
          })
        else
          render_error(@rating.errors.full_messages.join(', '))
        end
      end

      # GET /api/v1/sellers/:id/products
      def products
        # アクティブなセラーのみ表示（管理者以外）
        unless @seller.active && @seller.verified || current_user&.admin?
          render_forbidden
          return
        end

        @products = @seller.seller_products.joins(:product).includes(:product)

        # アクティブな商品のみ表示（管理者以外）
        @products = @products.where(active: true) unless current_user&.admin?

        # カテゴリでフィルタリング
        if params[:category_id].present?
          @products = @products.joins(product: :category).where(products: { category_id: params[:category_id] })
        end

        # 価格範囲でフィルタリング
        @products = @products.where('price >= ?', params[:min_price]) if params[:min_price].present?
        @products = @products.where('price <= ?', params[:max_price]) if params[:max_price].present?

        # ソート
        case params[:sort]
        when 'price_asc'
          @products = @products.order(price: :asc)
        when 'price_desc'
          @products = @products.order(price: :desc)
        when 'newest'
          @products = @products.order(created_at: :desc)
        else
          @products = @products.order(created_at: :desc)
        end

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

      def set_seller
        @seller = Seller.find(params[:id])
      end

      def seller_params
        params.require(:seller).permit(
          :business_name, :description, :logo, :banner, :website, :email,
          :phone_number, :address_line1, :address_line2, :city, :state,
          :postal_code, :country_id, :tax_id, :business_type, :year_established,
          :return_policy, :shipping_policy, :active, :verified, :verification_status,
          :rejection_reason, :commission_rate, :payout_method, :payout_details
        )
      end

      def has_purchased_from_seller?(seller_id)
        # ユーザーがセラーから購入したことがあるかチェック
        OrderItem.joins(:order, :product)
                .where(orders: { user_id: current_user.id, status: ['delivered', 'completed'] })
                .joins('INNER JOIN seller_products ON seller_products.product_id = products.id')
                .where(seller_products: { seller_id: seller_id })
                .exists?
      end

      def update_seller_average_rating(seller)
        average = seller.seller_ratings.average(:rating)
        seller.update(average_rating: average)
      end
    end
  end
end
