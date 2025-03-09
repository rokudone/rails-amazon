module Api
  module V1
    class OrdersController < BaseController
      before_action :set_order, only: [:show, :update, :destroy, :details, :update_status]

      # GET /api/v1/orders
      def index
        @orders = Order.all

        # ユーザーIDでフィルタリング
        @orders = @orders.where(user_id: params[:user_id]) if params[:user_id].present?

        # ステータスでフィルタリング
        @orders = @orders.where(status: params[:status]) if params[:status].present?

        # 日付範囲でフィルタリング
        @orders = @orders.where('created_at >= ?', params[:start_date]) if params[:start_date].present?
        @orders = @orders.where('created_at <= ?', params[:end_date]) if params[:end_date].present?

        # ページネーション
        @orders = @orders.page(params[:page] || 1).per(params[:per_page] || 20)

        render_success({
          orders: @orders,
          total: @orders.total_count,
          total_pages: @orders.total_pages,
          current_page: @orders.current_page
        })
      end

      # GET /api/v1/orders/:id
      def show
        render_success(@order)
      end

      # POST /api/v1/orders
      def create
        @order = Order.new(order_params)
        @order.user_id = current_user.id if current_user

        if @order.save
          # 注文アイテムの作成
          if params[:order_items].present?
            params[:order_items].each do |item|
              @order.order_items.create(
                product_id: item[:product_id],
                quantity: item[:quantity],
                price: item[:price],
                total: item[:price] * item[:quantity]
              )
            end
          end

          # 注文ログの作成
          @order.order_logs.create(
            status: @order.status,
            notes: 'Order created',
            user_id: current_user&.id
          )

          render_success(@order, :created)
        else
          render_error(@order.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/orders/:id
      def update
        if @order.update(order_params)
          # 注文ログの作成
          @order.order_logs.create(
            status: @order.status,
            notes: 'Order updated',
            user_id: current_user&.id
          )

          render_success(@order)
        else
          render_error(@order.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/orders/:id
      def destroy
        @order.destroy
        render_success({ message: 'Order deleted successfully' })
      end

      # GET /api/v1/orders/history
      def history
        if current_user
          @orders = current_user.orders.order(created_at: :desc)

          # ステータスでフィルタリング
          @orders = @orders.where(status: params[:status]) if params[:status].present?

          # 日付範囲でフィルタリング
          @orders = @orders.where('created_at >= ?', params[:start_date]) if params[:start_date].present?
          @orders = @orders.where('created_at <= ?', params[:end_date]) if params[:end_date].present?

          # ページネーション
          @orders = @orders.page(params[:page] || 1).per(params[:per_page] || 20)

          render_success({
            orders: @orders,
            total: @orders.total_count,
            total_pages: @orders.total_pages,
            current_page: @orders.current_page
          })
        else
          render_unauthorized
        end
      end

      # GET /api/v1/orders/:id/details
      def details
        render_success({
          order: @order,
          items: @order.order_items.includes(:product),
          logs: @order.order_logs,
          shipping: @order.shipment,
          payment: @order.payment
        })
      end

      # PUT /api/v1/orders/:id/update_status
      def update_status
        old_status = @order.status

        if @order.update(status: params[:status])
          # 注文ログの作成
          @order.order_logs.create(
            status: @order.status,
            notes: "Status changed from #{old_status} to #{@order.status}",
            user_id: current_user&.id
          )

          # 在庫の更新（キャンセル時）
          if params[:status] == 'cancelled' && old_status != 'cancelled'
            @order.order_items.each do |item|
              inventory = Inventory.find_by(product_id: item.product_id)
              if inventory
                inventory.update(quantity: inventory.quantity + item.quantity)

                # 在庫移動の記録
                StockMovement.create(
                  product_id: item.product_id,
                  warehouse_id: inventory.warehouse_id,
                  quantity: item.quantity,
                  movement_type: 'in',
                  reference: "Order ##{@order.id} cancelled",
                  notes: "Stock returned from cancelled order"
                )
              end
            end
          end

          render_success({
            order: @order,
            old_status: old_status,
            new_status: @order.status
          })
        else
          render_error(@order.errors.full_messages.join(', '))
        end
      end

      private

      def set_order
        @order = Order.find(params[:id])
      end

      def order_params
        params.require(:order).permit(
          :user_id, :status, :total, :subtotal, :tax, :shipping_cost,
          :discount, :shipping_address_id, :billing_address_id, :payment_method_id,
          :notes, :tracking_number, :estimated_delivery_date, :currency
        )
      end
    end
  end
end
