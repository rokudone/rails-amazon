module Api
  module V1
    class ReturnsController < BaseController
      before_action :set_return, only: [:show, :update, :destroy]

      # GET /api/v1/returns
      def index
        @returns = Return.all

        # 注文IDでフィルタリング
        @returns = @returns.where(order_id: params[:order_id]) if params[:order_id].present?

        # ユーザーIDでフィルタリング
        @returns = @returns.joins(:order).where(orders: { user_id: params[:user_id] }) if params[:user_id].present?

        # ステータスでフィルタリング
        @returns = @returns.where(status: params[:status]) if params[:status].present?

        # 日付範囲でフィルタリング
        @returns = @returns.where('created_at >= ?', params[:start_date]) if params[:start_date].present?
        @returns = @returns.where('created_at <= ?', params[:end_date]) if params[:end_date].present?

        render_success(@returns)
      end

      # GET /api/v1/returns/:id
      def show
        render_success(@return)
      end

      # POST /api/v1/returns
      def create
        @return = Return.new(return_params)

        if @return.save
          # 注文ログの作成
          if @return.order
            @return.order.order_logs.create(
              status: 'return_requested',
              notes: "Return requested: #{@return.reason}",
              user_id: current_user&.id
            )
          end

          render_success(@return, :created)
        else
          render_error(@return.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/returns/:id
      def update
        if @return.update(return_params)
          # 注文ステータスの更新
          if @return.order && @return.status == 'approved'
            @return.order.update(status: 'return_approved')

            # 注文ログの作成
            @return.order.order_logs.create(
              status: 'return_approved',
              notes: "Return approved",
              user_id: current_user&.id
            )
          elsif @return.order && @return.status == 'completed'
            @return.order.update(status: 'returned')

            # 注文ログの作成
            @return.order.order_logs.create(
              status: 'returned',
              notes: "Return completed",
              user_id: current_user&.id
            )

            # 在庫の更新
            @return.order.order_items.each do |item|
              if item.product_id.present? && item.quantity.present?
                inventory = Inventory.find_by(product_id: item.product_id)
                if inventory
                  inventory.update(quantity: inventory.quantity + item.quantity)

                  # 在庫移動の記録
                  StockMovement.create(
                    product_id: item.product_id,
                    warehouse_id: inventory.warehouse_id,
                    quantity: item.quantity,
                    movement_type: 'in',
                    reference: "Return ##{@return.id}",
                    notes: "Stock returned from order ##{@return.order_id}"
                  )
                end
              end
            end
          end

          render_success(@return)
        else
          render_error(@return.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/returns/:id
      def destroy
        @return.destroy
        render_success({ message: 'Return deleted successfully' })
      end

      # POST /api/v1/returns/process_return
      def process_return
        order = Order.find(params[:order_id])

        if order
          # 返品の作成
          @return = Return.new(
            order_id: order.id,
            reason: params[:reason],
            status: 'pending',
            requested_amount: params[:requested_amount] || order.total,
            notes: params[:notes]
          )

          if @return.save
            # 注文ログの作成
            order.order_logs.create(
              status: 'return_requested',
              notes: "Return requested: #{@return.reason}",
              user_id: current_user&.id
            )

            render_success(@return, :created)
          else
            render_error(@return.errors.full_messages.join(', '))
          end
        else
          render_error('Order not found')
        end
      end

      # POST /api/v1/returns/process_refund
      def process_refund
        @return = Return.find(params[:id])

        if @return
          # 返金処理のシミュレーション
          success = rand > 0.1 # 90%の確率で成功

          if success
            # 返金成功
            @return.update(
              status: 'completed',
              refunded_amount: params[:refunded_amount] || @return.requested_amount,
              refunded_at: Time.current
            )

            # 注文ステータスの更新
            if @return.order
              @return.order.update(status: 'refunded')

              # 注文ログの作成
              @return.order.order_logs.create(
                status: 'refunded',
                notes: "Refund processed: #{@return.refunded_amount}",
                user_id: current_user&.id
              )

              # 支払いの更新
              payment = @return.order.payment
              if payment
                payment.update(status: 'refunded')

                # 支払い処理の記録
                PaymentTransaction.create(
                  payment_id: payment.id,
                  amount: @return.refunded_amount,
                  transaction_type: 'refund',
                  status: 'completed',
                  transaction_id: SecureRandom.hex(10),
                  provider_response: { success: true }.to_json
                )
              end
            end

            render_success({
              return: @return,
              message: 'Refund processed successfully'
            })
          else
            # 返金失敗
            render_error('Refund processing failed')
          end
        else
          render_error('Return not found')
        end
      end

      private

      def set_return
        @return = Return.find(params[:id])
      end

      def return_params
        params.require(:return).permit(
          :order_id, :reason, :status, :requested_amount, :refunded_amount,
          :refunded_at, :return_tracking_number, :notes
        )
      end
    end
  end
end
