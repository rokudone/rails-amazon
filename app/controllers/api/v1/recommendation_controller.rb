module Api
  module V1
    class RecommendationController < BaseController
      skip_before_action :authenticate_user, only: [:index]

      # GET /api/v1/recommendations
      def index
        # 一般的なレコメンデーション（ログインしていないユーザー向け）
        @popular_products = get_popular_products
        @new_arrivals = get_new_arrivals
        @trending_products = get_trending_products

        render_success({
          popular_products: @popular_products,
          new_arrivals: @new_arrivals,
          trending_products: @trending_products
        })
      end

      # GET /api/v1/recommendations/personalized
      def personalized
        unless current_user
          render_unauthorized
          return
        end

        # パーソナライズドレコメンデーション
        @recently_viewed = get_recently_viewed
        @based_on_purchase_history = get_based_on_purchase_history
        @based_on_wishlist = get_based_on_wishlist
        @based_on_cart = get_based_on_cart
        @similar_to_viewed = get_similar_to_viewed

        render_success({
          recently_viewed: @recently_viewed,
          based_on_purchase_history: @based_on_purchase_history,
          based_on_wishlist: @based_on_wishlist,
          based_on_cart: @based_on_cart,
          similar_to_viewed: @similar_to_viewed
        })
      end

      private

      def get_popular_products
        # 人気商品（注文数が多い商品）
        Product.where(active: true)
              .joins(:order_items)
              .select('products.*, COUNT(order_items.id) as order_count')
              .group('products.id')
              .order('order_count DESC')
              .limit(10)
      end

      def get_new_arrivals
        # 新着商品
        Product.where(active: true)
              .order(created_at: :desc)
              .limit(10)
      end

      def get_trending_products
        # トレンド商品（最近の注文で人気の商品）
        Product.where(active: true)
              .joins(:order_items => :order)
              .where('orders.created_at >= ?', 7.days.ago)
              .select('products.*, COUNT(order_items.id) as order_count')
              .group('products.id')
              .order('order_count DESC')
              .limit(10)
      end

      def get_recently_viewed
        # 最近閲覧した商品
        product_ids = current_user.recently_vieweds
                                .order(viewed_at: :desc)
                                .limit(10)
                                .pluck(:product_id)

        Product.where(id: product_ids, active: true)
      end

      def get_based_on_purchase_history
        # 購入履歴に基づくレコメンデーション
        # 1. ユーザーが購入した商品のカテゴリを取得
        purchased_category_ids = OrderItem.joins(:order, :product)
                                        .where(orders: { user_id: current_user.id })
                                        .pluck('DISTINCT products.category_id')

        # 2. 同じカテゴリの他の商品を取得
        Product.where(category_id: purchased_category_ids, active: true)
              .where.not(id: get_purchased_product_ids)
              .order(created_at: :desc)
              .limit(10)
      end

      def get_based_on_wishlist
        # ウィッシュリストに基づくレコメンデーション
        # 1. ユーザーのウィッシュリストにある商品のカテゴリとブランドを取得
        wishlist_items = WishlistItem.joins(:wishlist, :product)
                                   .where(wishlists: { user_id: current_user.id })

        wishlist_category_ids = wishlist_items.pluck('DISTINCT products.category_id')
        wishlist_brand_ids = wishlist_items.pluck('DISTINCT products.brand_id')
        wishlist_product_ids = wishlist_items.pluck('products.id')

        # 2. 同じカテゴリまたはブランドの他の商品を取得
        Product.where(active: true)
              .where('category_id IN (?) OR brand_id IN (?)', wishlist_category_ids, wishlist_brand_ids)
              .where.not(id: wishlist_product_ids)
              .order(created_at: :desc)
              .limit(10)
      end

      def get_based_on_cart
        # カートに基づくレコメンデーション
        # 1. ユーザーのカートにある商品を取得
        cart_items = CartItem.joins(:cart)
                           .where(carts: { user_id: current_user.id })

        cart_product_ids = cart_items.pluck(:product_id)

        # 2. カートにある商品と一緒に購入されることが多い商品を取得
        # （実際の実装では、より複雑な協調フィルタリングなどを使用）
        frequently_bought_together = OrderItem.joins(:order)
                                           .where(product_id: cart_product_ids)
                                           .where.not(orders: { user_id: current_user.id })
                                           .pluck(:order_id)

        related_product_ids = OrderItem.where(order_id: frequently_bought_together)
                                     .where.not(product_id: cart_product_ids)
                                     .group(:product_id)
                                     .order('COUNT(*) DESC')
                                     .limit(10)
                                     .pluck(:product_id)

        Product.where(id: related_product_ids, active: true)
      end

      def get_similar_to_viewed
        # 閲覧した商品に類似した商品
        # 1. 最近閲覧した商品を取得
        recently_viewed_ids = current_user.recently_vieweds
                                        .order(viewed_at: :desc)
                                        .limit(3)
                                        .pluck(:product_id)

        return [] if recently_viewed_ids.empty?

        # 2. 閲覧した商品と同じカテゴリまたはブランドの商品を取得
        recently_viewed_products = Product.where(id: recently_viewed_ids)
        category_ids = recently_viewed_products.pluck(:category_id)
        brand_ids = recently_viewed_products.pluck(:brand_id)

        Product.where(active: true)
              .where('category_id IN (?) OR brand_id IN (?)', category_ids, brand_ids)
              .where.not(id: recently_viewed_ids)
              .order(created_at: :desc)
              .limit(10)
      end

      def get_purchased_product_ids
        # ユーザーが購入した商品のIDを取得
        OrderItem.joins(:order)
                .where(orders: { user_id: current_user.id })
                .pluck(:product_id)
      end
    end
  end
end
