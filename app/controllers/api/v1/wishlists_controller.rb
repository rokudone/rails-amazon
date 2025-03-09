module Api
  module V1
    class WishlistsController < BaseController
      before_action :set_wishlist, only: [:show, :update, :destroy]

      # GET /api/v1/wishlists
      def index
        @wishlists = current_user.wishlists
        render_success(@wishlists)
      end

      # GET /api/v1/wishlists/:id
      def show
        render_success({
          wishlist: @wishlist,
          products: @wishlist.products
        })
      end

      # POST /api/v1/wishlists
      def create
        @wishlist = Wishlist.new(wishlist_params)
        @wishlist.user_id = current_user.id

        if @wishlist.save
          # 商品の追加
          if params[:product_ids].present?
            params[:product_ids].each do |product_id|
              @wishlist.wishlist_items.create(product_id: product_id)
            end
          end

          render_success(@wishlist, :created)
        else
          render_error(@wishlist.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/wishlists/:id
      def update
        if @wishlist.update(wishlist_params)
          render_success(@wishlist)
        else
          render_error(@wishlist.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/wishlists/:id
      def destroy
        @wishlist.destroy
        render_success({ message: 'Wishlist deleted successfully' })
      end

      # POST /api/v1/wishlists/:id/add_item
      def add_item
        @wishlist = current_user.wishlists.find(params[:id])
        product = Product.find(params[:product_id])

        # 商品が存在し、アクティブかチェック
        unless product && product.active
          render_error('Product not found or inactive')
          return
        end

        # 既に追加されていないかチェック
        if @wishlist.wishlist_items.exists?(product_id: product.id)
          render_error('Product already in wishlist')
          return
        end

        wishlist_item = @wishlist.wishlist_items.new(product_id: product.id)

        if wishlist_item.save
          render_success({
            wishlist_item: wishlist_item,
            message: 'Product added to wishlist'
          })
        else
          render_error(wishlist_item.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/wishlists/:id/remove_item
      def remove_item
        @wishlist = current_user.wishlists.find(params[:id])
        wishlist_item = @wishlist.wishlist_items.find_by(product_id: params[:product_id])

        unless wishlist_item
          render_error('Product not found in wishlist')
          return
        end

        wishlist_item.destroy
        render_success({ message: 'Product removed from wishlist' })
      end

      # POST /api/v1/wishlists/:id/move_to_cart
      def move_to_cart
        @wishlist = current_user.wishlists.find(params[:id])
        product = Product.find(params[:product_id])

        # 商品が存在し、アクティブかチェック
        unless product && product.active
          render_error('Product not found or inactive')
          return
        end

        # ウィッシュリストから商品を検索
        wishlist_item = @wishlist.wishlist_items.find_by(product_id: product.id)

        unless wishlist_item
          render_error('Product not found in wishlist')
          return
        end

        # カートを取得または作成
        cart = current_user.carts.first || current_user.carts.create

        # 在庫があるかチェック
        inventory = Inventory.where(product_id: product.id).sum(:quantity)

        if inventory < 1
          render_error('Not enough inventory')
          return
        end

        # カートに商品を追加
        cart_item = cart.cart_items.find_by(product_id: product.id)

        if cart_item
          # 既存のアイテムを更新
          cart_item.update(quantity: cart_item.quantity + 1)
        else
          # 新しいアイテムを追加
          cart.cart_items.create(
            product_id: product.id,
            quantity: 1,
            price: product.price
          )
        end

        # ウィッシュリストから商品を削除（オプション）
        if params[:remove_from_wishlist]
          wishlist_item.destroy
        end

        render_success({
          message: 'Product moved to cart',
          remove_from_wishlist: params[:remove_from_wishlist] ? true : false
        })
      end

      private

      def set_wishlist
        @wishlist = current_user.wishlists.find(params[:id])
      end

      def wishlist_params
        params.require(:wishlist).permit(:name, :description, :is_public)
      end
    end
  end
end
