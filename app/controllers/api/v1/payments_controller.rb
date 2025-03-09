module Api
  module V1
    class PaymentsController < BaseController
      before_action :set_payment, only: [:show, :update, :destroy]

      # GET /api/v1/payments
      def index
        @payments = Payment.all

        # 注文IDでフィルタリング
        @payments = @payments.where(order_id: params[:order_id]) if params[:order_id].present?

        # ユーザーIDでフィルタリング
        @payments = @payments.joins(:order).where(orders: { user_id: params[:user_id] }) if params[:user_id].present?

        # ステータスでフィルタリング
        @payments = @payments.where(status: params[:status]) if params[:status].present?

        # 日付範囲でフィルタリング
        @payments = @payments.where('created_at >= ?', params[:start_date]) if params[:start_date].present?
        @payments = @payments.where('created_at <= ?', params[:end_date]) if params[:end_date].present?

        render_success(@payments)
      end

      # GET /api/v1/payments/:id
      def show
        render_success(@payment)
      end

      # POST /api/v1/payments
      def create
        @payment = Payment.new(payment_params)

        if @payment.save
          # 支払い処理の記録
          PaymentTransaction.create(
            payment_id: @payment.id,
            amount: @payment.amount,
            transaction_type: 'payment',
            status: @payment.status,
            transaction_id: SecureRandom.hex(10),
            provider_response: { success: true }.to_json
          )

          # 注文ステータスの更新
          if @payment.order && @payment.status == 'completed'
            @payment.order.update(status: 'paid')

            # 注文ログの作成
            @payment.order.order_logs.create(
              status: 'paid',
              notes: "Payment completed: #{@payment.payment_method}",
              user_id: current_user&.id
            )
          end

          render_success(@payment, :created)
        else
          render_error(@payment.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/payments/:id
      def update
        if @payment.update(payment_params)
          render_success(@payment)
        else
          render_error(@payment.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/payments/:id
      def destroy
        @payment.destroy
        render_success({ message: 'Payment deleted successfully' })
      end

      # POST /api/v1/payments/process_payment
      def process_payment
        # 支払い処理のシミュレーション
        order = Order.find(params[:order_id])

        if order
          # 支払い方法の検証
          payment_method = params[:payment_method_id] ? PaymentMethod.find(params[:payment_method_id]) : nil

          if payment_method || params[:payment_method]
            # 支払いの作成
            @payment = Payment.new(
              order_id: order.id,
              amount: order.total,
              payment_method: payment_method ? payment_method.payment_type : params[:payment_method],
              payment_method_id: payment_method&.id,
              status: 'processing',
              currency: order.currency || 'USD'
            )

            if @payment.save
              # 支払い処理のシミュレーション
              success = rand > 0.1 # 90%の確率で成功

              if success
                # 支払い成功
                @payment.update(status: 'completed')

                # 支払い処理の記録
                transaction = PaymentTransaction.create(
                  payment_id: @payment.id,
                  amount: @payment.amount,
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
                  notes: "Payment completed: #{@payment.payment_method}",
                  user_id: current_user&.id
                )

                render_success({
                  payment: @payment,
                  transaction: transaction,
                  message: 'Payment processed successfully'
                })
              else
                # 支払い失敗
                @payment.update(status: 'failed')

                # 支払い処理の記録
                transaction = PaymentTransaction.create(
                  payment_id: @payment.id,
                  amount: @payment.amount,
                  transaction_type: 'payment',
                  status: 'failed',
                  transaction_id: SecureRandom.hex(10),
                  provider_response: { success: false, error: 'Payment declined' }.to_json
                )

                render_error('Payment processing failed', :payment_required)
              end
            else
              render_error(@payment.errors.full_messages.join(', '))
            end
          else
            render_error('Payment method is required')
          end
        else
          render_error('Order not found')
        end
      end

      # PUT /api/v1/payments/update_status
      def update_status
        @payment = Payment.find(params[:id])
        old_status = @payment.status

        if @payment.update(status: params[:status])
          # 支払い処理の記録
          PaymentTransaction.create(
            payment_id: @payment.id,
            amount: @payment.amount,
            transaction_type: 'status_update',
            status: @payment.status,
            transaction_id: SecureRandom.hex(10),
            provider_response: { success: true, status_change: "#{old_status} to #{@payment.status}" }.to_json
          )

          # 注文ステータスの更新
          if @payment.order && @payment.status == 'completed'
            @payment.order.update(status: 'paid')

            # 注文ログの作成
            @payment.order.order_logs.create(
              status: 'paid',
              notes: "Payment status updated to completed",
              user_id: current_user&.id
            )
          elsif @payment.order && @payment.status == 'refunded'
            @payment.order.update(status: 'refunded')

            # 注文ログの作成
            @payment.order.order_logs.create(
              status: 'refunded',
              notes: "Payment refunded",
              user_id: current_user&.id
            )
          end

          render_success({
            payment: @payment,
            old_status: old_status,
            new_status: @payment.status
          })
        else
          render_error(@payment.errors.full_messages.join(', '))
        end
      end

      private

      def set_payment
        @payment = Payment.find(params[:id])
      end

      def payment_params
        params.require(:payment).permit(
          :order_id, :amount, :payment_method, :payment_method_id, :status,
          :transaction_id, :currency, :notes
        )
      end
    end
  end
end
