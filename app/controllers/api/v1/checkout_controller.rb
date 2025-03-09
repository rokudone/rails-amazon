module Api
  module V1
    class CheckoutController < BaseController
      # POST /api/v1/checkout/process
      def process_checkout
        # カートの取得
        cart = current_user.carts.find(params[:cart_id])

        unless cart
          render_error('Cart not found')
          return
        end

        # カートが空でないことを確認
        if cart.cart_items.empty?
          render_error('Cart is empty')
          return
        end

        # 在庫の確認
        inventory_check = check_inventory(cart)

        unless inventory_check[:success]
          render_error("Inventory check failed: #{inventory_check[:message]}")
          return
        end

        # 配送先住所の確認
        shipping_address = current_user.addresses.find_by(id: params[:shipping_address_id])

        unless shipping_address
          render_error('Shipping address not found')
          return
        end

        # 請求先住所の確認
        billing_address = if params[:billing_address_id] == params[:shipping_address_id]
                          shipping_address
                        else
                          current_user.addresses.find_by(id: params[:billing_address_id])
                        end

        unless billing_address
          render_error('Billing address not found')
          return
        end

        # 支払い方法の確認
        payment_method = current_user.payment_methods.find_by(id: params[:payment_method_id])

        unless payment_method
          render_error('Payment method not found')
          return
        end

        # 注文の作成
        order = Order.new(
          user_id: current_user.id,
          status: 'pending',
          subtotal: cart.subtotal,
          shipping_cost: cart.shipping_cost,
          tax: cart.tax,
          discount: cart.discount,
          total: cart.total,
          shipping_address_id: shipping_address.id,
          billing_address_id: billing_address.id,
          payment_method_id: payment_method.id,
          notes: params[:notes],
          currency: params[:currency] || 'USD'
        )

        if order.save
          # 注文アイテムの作成
          cart.cart_items.each do |item|
            order.order_items.create(
              product_id: item.product_id,
              quantity: item.quantity,
              price: item.price,
              total: item.price * item.quantity
            )
          end

          # 注文ログの作成
          order.order_logs.create(
            status: 'pending',
            notes: 'Order created',
            user_id: current_user.id
          )

          # 在庫の更新
          update_inventory(order)

          # 注文割引の作成（クーポンコードがある場合）
          if cart.discount_code.present? && cart.discount > 0
            OrderDiscount.create(
              order_id: order.id,
              code: cart.discount_code,
              amount: cart.discount,
              discount_type: 'coupon'
            )

            # クーポンの使用回数を更新
            coupon = Coupon.find_by(code: cart.discount_code)
            coupon.update(used_count: coupon.used_count + 1) if coupon
          end

          # カートをクリア
          cart.cart_items.destroy_all
          cart.update(
            subtotal: 0,
            shipping_cost: 0,
            tax: 0,
            discount: 0,
            total: 0,
            discount_code: nil
          )

          render_success({
            order: order,
            message: 'Order created successfully'
          })
        else
          render_error(order.errors.full_messages.join(', '))
        end
      end

      # POST /api/v1/checkout/confirm
      def confirm
        order = Order.find(params[:order_id])

        # 注文がユーザーのものであることを確認
        unless order.user_id == current_user.id
          render_forbidden
          return
        end

        # 注文のステータスを確認
        unless order.status == 'pending'
          render_error('Order cannot be confirmed')
          return
        end

        # 注文のステータスを更新
        if order.update(status: 'confirmed')
          # 注文ログの作成
          order.order_logs.create(
            status: 'confirmed',
            notes: 'Order confirmed by customer',
            user_id: current_user.id
          )

          render_success({
            order: order,
            message: 'Order confirmed successfully'
          })
        else
          render_error(order.errors.full_messages.join(', '))
        end
      end

      # POST /api/v1/checkout/payment
      def payment
        order = Order.find(params[:order_id])

        # 注文がユーザーのものであることを確認
        unless order.user_id == current_user.id
          render_forbidden
          return
        end

        # 注文のステータスを確認
        unless ['pending', 'confirmed'].include?(order.status)
          render_error('Payment cannot be processed')
          return
        end

        # 支払い処理のシミュレーション
        success = rand > 0.1 # 90%の確率で成功

        if success
          # 支払いの作成
          payment = Payment.create(
            order_id: order.id,
            amount: order.total,
            payment_method: order.payment_method.payment_type,
            payment_method_id: order.payment_method_id,
            status: 'completed',
            transaction_id: SecureRandom.hex(10),
            currency: order.currency
          )

          # 支払い処理の記録
          PaymentTransaction.create(
            payment_id: payment.id,
            amount: payment.amount,
            transaction_type: 'payment',
            status: 'completed',
            transaction_id: SecureRandom.hex(10),
            provider_response: { success: true }.to_json
          )

          # 注文ステータスの更新
          order.update(status: 'paid')

          # 注文ログの作成
          order.order_logs.create(
            status: 'paid',
            notes: "Payment completed: #{payment.payment_method}",
            user_id: current_user.id
          )

          render_success({
            order: order,
            payment: payment,
            message: 'Payment processed successfully'
          })
        else
          # 支払い失敗
          payment = Payment.create(
            order_id: order.id,
            amount: order.total,
            payment_method: order.payment_method.payment_type,
            payment_method_id: order.payment_method_id,
            status: 'failed',
            currency: order.currency
          )

          # 支払い処理の記録
          PaymentTransaction.create(
            payment_id: payment.id,
            amount: payment.amount,
            transaction_type: 'payment',
            status: 'failed',
            transaction_id: SecureRandom.hex(10),
            provider_response: { success: false, error: 'Payment declined' }.to_json
          )

          render_error('Payment processing failed', :payment_required)
        end
      end

      private

      def check_inventory(cart)
        cart.cart_items.each do |item|
          inventory = Inventory.where(product_id: item.product_id).sum(:quantity)

          if inventory < item.quantity
            product = Product.find(item.product_id)
            return {
              success: false,
              message: "Not enough inventory for product: #{product.name}. Available: #{inventory}, Requested: #{item.quantity}"
            }
          end
        end

        { success: true }
      end

      def update_inventory(order)
        order.order_items.each do |item|
          inventories = Inventory.where(product_id: item.product_id).order(quantity: :desc)
          remaining_quantity = item.quantity

          inventories.each do |inventory|
            if inventory.quantity >= remaining_quantity
              # 在庫が十分にある場合
              inventory.update(quantity: inventory.quantity - remaining_quantity)

              # 在庫移動の記録
              StockMovement.create(
                product_id: item.product_id,
                warehouse_id: inventory.warehouse_id,
                quantity: -remaining_quantity,
                movement_type: 'out',
                reference: "Order ##{order.id}",
                notes: "Stock reduced due to order"
              )

              break
            else
              # 在庫が不足している場合、利用可能な分だけ減らす
              remaining_quantity -= inventory.quantity

              # 在庫移動の記録
              StockMovement.create(
                product_id: item.product_id,
                warehouse_id: inventory.warehouse_id,
                quantity: -inventory.quantity,
                movement_type: 'out',
                reference: "Order ##{order.id}",
                notes: "Stock reduced due to order"
              )

              inventory.update(quantity: 0)
            end
          end
        end
      end
    end
  end
end
