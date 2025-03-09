module Api
  module V1
    class CartsController < BaseController
      before_action :set_cart, only: [:show, :update, :destroy, :add_item, :update_item, :remove_item, :calculate, :sync]

      # GET /api/v1/carts
      def index
        @carts = current_user.carts
        render_success(@carts)
      end

      # GET /api/v1/carts/:id
      def show
        render_success({
          cart: @cart,
          items: @cart.cart_items.includes(:product),
          total: calculate_cart_total(@cart)
        })
      end

      # POST /api/v1/carts
      def create
        @cart = Cart.new(cart_params)
        @cart.user_id = current_user.id

        if @cart.save
          render_success(@cart, :created)
        else
          render_error(@cart.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/carts/:id
      def update
        if @cart.update(cart_params)
          render_success(@cart)
        else
          render_error(@cart.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/carts/:id
      def destroy
        @cart.destroy
        render_success({ message: 'Cart deleted successfully' })
      end

      # POST /api/v1/carts/:id/add_item
      def add_item
        product = Product.find(params[:product_id])

        # 商品が存在し、アクティブかチェック
        unless product && product.active
          render_error('Product not found or inactive')
          return
        end

        # 在庫があるかチェック
        inventory = Inventory.where(product_id: product.id).sum(:quantity)

        if inventory < params[:quantity].to_i
          render_error('Not enough inventory')
          return
        end

        # 既存のカートアイテムを検索
        cart_item = @cart.cart_items.find_by(product_id: product.id)

        if cart_item
          # 既存のアイテムを更新
          new_quantity = cart_item.quantity + params[:quantity].to_i

          if cart_item.update(quantity: new_quantity)
            render_success({
              cart_item: cart_item,
              message: 'Item quantity updated in cart'
            })
          else
            render_error(cart_item.errors.full_messages.join(', '))
          end
        else
          # 新しいアイテムを追加
          cart_item = @cart.cart_items.new(
            product_id: product.id,
            quantity: params[:quantity],
            price: product.price
          )

          if cart_item.save
            render_success({
              cart_item: cart_item,
              message: 'Item added to cart'
            })
          else
            render_error(cart_item.errors.full_messages.join(', '))
          end
        end
      end

      # PUT /api/v1/carts/:id/update_item
      def update_item
        cart_item = @cart.cart_items.find_by(id: params[:cart_item_id])

        unless cart_item
          render_error('Cart item not found')
          return
        end

        # 在庫があるかチェック
        inventory = Inventory.where(product_id: cart_item.product_id).sum(:quantity)

        if inventory < params[:quantity].to_i
          render_error('Not enough inventory')
          return
        end

        if params[:quantity].to_i <= 0
          # 数量が0以下の場合はアイテムを削除
          cart_item.destroy
          render_success({ message: 'Item removed from cart' })
        else
          # アイテムを更新
          if cart_item.update(quantity: params[:quantity])
            render_success({
              cart_item: cart_item,
              message: 'Cart item updated'
            })
          else
            render_error(cart_item.errors.full_messages.join(', '))
          end
        end
      end

      # DELETE /api/v1/carts/:id/remove_item
      def remove_item
        cart_item = @cart.cart_items.find_by(id: params[:cart_item_id])

        unless cart_item
          render_error('Cart item not found')
          return
        end

        cart_item.destroy
        render_success({ message: 'Item removed from cart' })
      end

      # GET /api/v1/carts/:id/calculate
      def calculate
        subtotal = @cart.cart_items.sum { |item| item.price * item.quantity }

        # 配送料の計算
        shipping_cost = calculate_shipping_cost(@cart)

        # 税金の計算
        tax = calculate_tax(@cart)

        # 割引の適用
        discount = @cart.discount || 0

        # 合計の計算
        total = subtotal + shipping_cost + tax - discount

        # カートの更新
        @cart.update(
          subtotal: subtotal,
          shipping_cost: shipping_cost,
          tax: tax,
          total: total
        )

        render_success({
          cart: @cart,
          items: @cart.cart_items.includes(:product),
          subtotal: subtotal,
          shipping_cost: shipping_cost,
          tax: tax,
          discount: discount,
          total: total
        })
      end

      # POST /api/v1/carts/:id/sync
      def sync
        # クライアントから送信されたカートアイテム
        client_items = params[:items] || []

        # サーバー上のカートアイテム
        server_items = @cart.cart_items.to_a

        # クライアントアイテムの同期
        client_items.each do |client_item|
          product = Product.find_by(id: client_item[:product_id])

          next unless product && product.active

          server_item = server_items.find { |item| item.product_id == client_item[:product_id].to_i }

          if server_item
            # 既存のアイテムを更新
            server_item.update(quantity: client_item[:quantity], price: product.price)
          else
            # 新しいアイテムを追加
            @cart.cart_items.create(
              product_id: product.id,
              quantity: client_item[:quantity],
              price: product.price
            )
          end
        end

        # クライアントに存在しないサーバーアイテムを削除
        server_items.each do |server_item|
          client_item = client_items.find { |item| item[:product_id].to_i == server_item.product_id }
          server_item.destroy unless client_item
        end

        # カートを再計算
        calculate
      end

      private

      def set_cart
        @cart = current_user.carts.find_by(id: params[:id])

        unless @cart
          # カートが存在しない場合は新規作成
          @cart = current_user.carts.create
        end
      end

      def cart_params
        params.require(:cart).permit(
          :user_id, :subtotal, :shipping_cost, :tax, :discount, :total,
          :discount_code, :notes
        )
      end

      def calculate_cart_total(cart)
        subtotal = cart.cart_items.sum { |item| item.price * item.quantity }
        shipping_cost = calculate_shipping_cost(cart)
        tax = calculate_tax(cart)
        discount = cart.discount || 0

        subtotal + shipping_cost + tax - discount
      end

      def calculate_shipping_cost(cart)
        # 配送料の計算ロジック
        # 実際の実装では、配送先や商品の重量などに基づいて計算
        base_shipping = 5.0

        # 商品数に応じて配送料を増加
        item_count = cart.cart_items.sum(:quantity)
        additional_shipping = [item_count - 1, 0].max * 0.5

        base_shipping + additional_shipping
      end

      def calculate_tax(cart)
        # 税金の計算ロジック
        # 実際の実装では、配送先の税率に基づいて計算
        tax_rate = 0.1 # 10%

        subtotal = cart.cart_items.sum { |item| item.price * item.quantity }
        (subtotal * tax_rate).round(2)
      end
    end
  end
end
