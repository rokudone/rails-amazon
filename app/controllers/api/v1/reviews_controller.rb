module Api
  module V1
    class ReviewsController < BaseController
      skip_before_action :authenticate_user, only: [:index, :show]
      before_action :set_review, only: [:show, :update, :destroy, :approve, :vote]
      before_action :set_product, only: [:index, :create]

      # GET /api/v1/products/:product_id/reviews
      # GET /api/v1/reviews
      def index
        if @product
          @reviews = @product.reviews
        else
          @reviews = Review.all
        end

        # 承認済みのレビューのみ表示（管理者以外）
        @reviews = @reviews.where(approved: true) unless current_user&.admin?

        # 評価でフィルタリング
        @reviews = @reviews.where(rating: params[:rating]) if params[:rating].present?

        # ソート
        case params[:sort]
        when 'newest'
          @reviews = @reviews.order(created_at: :desc)
        when 'oldest'
          @reviews = @reviews.order(created_at: :asc)
        when 'highest_rating'
          @reviews = @reviews.order(rating: :desc)
        when 'lowest_rating'
          @reviews = @reviews.order(rating: :asc)
        when 'most_helpful'
          @reviews = @reviews.left_joins(:review_votes)
                           .group('reviews.id')
                           .order('COUNT(review_votes.id) DESC')
        else
          @reviews = @reviews.order(created_at: :desc)
        end

        # ページネーション
        @reviews = @reviews.page(params[:page] || 1).per(params[:per_page] || 20)

        render_success({
          reviews: @reviews,
          total: @reviews.total_count,
          total_pages: @reviews.total_pages,
          current_page: @reviews.current_page,
          average_rating: @reviews.average(:rating)&.round(1)
        })
      end

      # GET /api/v1/reviews/:id
      def show
        # 承認済みのレビューのみ表示（管理者以外）
        unless @review.approved || current_user&.admin?
          render_forbidden
          return
        end

        render_success(@review)
      end

      # POST /api/v1/products/:product_id/reviews
      def create
        # ユーザーが商品を購入したかチェック
        unless current_user.admin? || has_purchased_product?(@product.id)
          render_error('You can only review products you have purchased', :forbidden)
          return
        end

        # 既にレビューを投稿していないかチェック
        if Review.exists?(user_id: current_user.id, product_id: @product.id)
          render_error('You have already reviewed this product', :unprocessable_entity)
          return
        end

        @review = @product.reviews.new(review_params)
        @review.user_id = current_user.id
        @review.approved = current_user.admin? # 管理者の場合は自動承認

        if @review.save
          # レビュー画像の保存
          if params[:images].present?
            params[:images].each do |image|
              @review.review_images.create(image: image)
            end
          end

          render_success(@review, :created)
        else
          render_error(@review.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/reviews/:id
      def update
        # レビュー作成者または管理者のみ更新可能
        unless @review.user_id == current_user.id || current_user.admin?
          render_forbidden
          return
        end

        if @review.update(review_params)
          # 管理者以外が更新した場合は承認ステータスをリセット
          @review.update(approved: false) unless current_user.admin?

          render_success(@review)
        else
          render_error(@review.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/reviews/:id
      def destroy
        # レビュー作成者または管理者のみ削除可能
        unless @review.user_id == current_user.id || current_user.admin?
          render_forbidden
          return
        end

        @review.destroy
        render_success({ message: 'Review deleted successfully' })
      end

      # PUT /api/v1/reviews/:id/approve
      def approve
        # 管理者のみ承認可能
        unless current_user.admin?
          render_forbidden
          return
        end

        if @review.update(approved: params[:approved])
          render_success({
            review: @review,
            message: params[:approved] ? 'Review approved successfully' : 'Review disapproved successfully'
          })
        else
          render_error(@review.errors.full_messages.join(', '))
        end
      end

      # POST /api/v1/reviews/:id/vote
      def vote
        # 既に投票していないかチェック
        existing_vote = @review.review_votes.find_by(user_id: current_user.id)

        if existing_vote
          # 既存の投票を削除
          existing_vote.destroy
          render_success({ message: 'Vote removed successfully' })
        else
          # 新しい投票を作成
          vote = @review.review_votes.new(user_id: current_user.id)

          if vote.save
            render_success({ message: 'Vote added successfully' })
          else
            render_error(vote.errors.full_messages.join(', '))
          end
        end
      end

      private

      def set_review
        @review = Review.find(params[:id])
      end

      def set_product
        @product = Product.find(params[:product_id]) if params[:product_id].present?
      end

      def review_params
        params.require(:review).permit(
          :title, :content, :rating, :pros, :cons, :verified_purchase
        )
      end

      def has_purchased_product?(product_id)
        # ユーザーが商品を購入したかチェック
        OrderItem.joins(:order)
                .where(orders: { user_id: current_user.id, status: ['delivered', 'completed'] })
                .where(product_id: product_id)
                .exists?
      end
    end
  end
end
