module Api
  module V1
    class ShipmentsController < BaseController
      before_action :set_shipment, only: [:show, :update, :destroy, :track]

      # GET /api/v1/shipments
      def index
        @shipments = Shipment.all

        # 注文IDでフィルタリング
        @shipments = @shipments.where(order_id: params[:order_id]) if params[:order_id].present?

        # ユーザーIDでフィルタリング
        @shipments = @shipments.joins(:order).where(orders: { user_id: params[:user_id] }) if params[:user_id].present?

        # ステータスでフィルタリング
        @shipments = @shipments.where(status: params[:status]) if params[:status].present?

        # 日付範囲でフィルタリング
        @shipments = @shipments.where('created_at >= ?', params[:start_date]) if params[:start_date].present?
        @shipments = @shipments.where('created_at <= ?', params[:end_date]) if params[:end_date].present?

        render_success(@shipments)
      end

      # GET /api/v1/shipments/:id
      def show
        render_success(@shipment)
      end

      # POST /api/v1/shipments
      def create
        @shipment = Shipment.new(shipment_params)

        if @shipment.save
          # 配送追跡の作成
          @shipment.create_shipment_tracking(
            tracking_number: @shipment.tracking_number,
            carrier: @shipment.carrier,
            status: 'pending',
            estimated_delivery_date: @shipment.estimated_delivery_date
          )

          # 注文ステータスの更新
          if @shipment.order
            @shipment.order.update(status: 'shipped')

            # 注文ログの作成
            @shipment.order.order_logs.create(
              status: 'shipped',
              notes: "Order shipped via #{@shipment.carrier} with tracking number #{@shipment.tracking_number}",
              user_id: current_user&.id
            )
          end

          render_success(@shipment, :created)
        else
          render_error(@shipment.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/shipments/:id
      def update
        if @shipment.update(shipment_params)
          # 配送追跡の更新
          if @shipment.shipment_tracking
            @shipment.shipment_tracking.update(
              tracking_number: @shipment.tracking_number,
              carrier: @shipment.carrier,
              estimated_delivery_date: @shipment.estimated_delivery_date
            )
          end

          render_success(@shipment)
        else
          render_error(@shipment.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/shipments/:id
      def destroy
        @shipment.destroy
        render_success({ message: 'Shipment deleted successfully' })
      end

      # GET /api/v1/shipments/:id/track
      def track
        if @shipment.shipment_tracking
          # 配送追跡情報の取得（実際にはキャリアのAPIを呼び出す）
          # ここではシミュレーションのみ

          # 配送ステータスの更新
          current_status = @shipment.shipment_tracking.status

          # 配送ステータスの進行をシミュレーション
          new_status = case current_status
                      when 'pending'
                        'picked_up'
                      when 'picked_up'
                        'in_transit'
                      when 'in_transit'
                        rand > 0.7 ? 'out_for_delivery' : 'in_transit'
                      when 'out_for_delivery'
                        rand > 0.8 ? 'delivered' : 'out_for_delivery'
                      else
                        current_status
                      end

          # ステータスが変更された場合のみ更新
          if new_status != current_status
            @shipment.shipment_tracking.update(status: new_status)

            # 注文ステータスの更新
            if new_status == 'delivered' && @shipment.order
              @shipment.order.update(status: 'delivered')

              # 注文ログの作成
              @shipment.order.order_logs.create(
                status: 'delivered',
                notes: "Order delivered",
                user_id: current_user&.id
              )
            end
          end

          # 配送履歴の生成
          tracking_history = [
            {
              status: 'pending',
              location: 'Warehouse',
              timestamp: (@shipment.created_at + 1.hour).iso8601,
              description: 'Shipment created'
            }
          ]

          if ['picked_up', 'in_transit', 'out_for_delivery', 'delivered'].include?(@shipment.shipment_tracking.status)
            tracking_history << {
              status: 'picked_up',
              location: 'Carrier Facility',
              timestamp: (@shipment.created_at + 6.hours).iso8601,
              description: 'Shipment picked up by carrier'
            }
          end

          if ['in_transit', 'out_for_delivery', 'delivered'].include?(@shipment.shipment_tracking.status)
            tracking_history << {
              status: 'in_transit',
              location: 'Sorting Facility',
              timestamp: (@shipment.created_at + 1.day).iso8601,
              description: 'Shipment in transit'
            }
          end

          if ['out_for_delivery', 'delivered'].include?(@shipment.shipment_tracking.status)
            tracking_history << {
              status: 'out_for_delivery',
              location: 'Local Delivery Facility',
              timestamp: (@shipment.created_at + 2.days).iso8601,
              description: 'Shipment out for delivery'
            }
          end

          if @shipment.shipment_tracking.status == 'delivered'
            tracking_history << {
              status: 'delivered',
              location: 'Delivery Address',
              timestamp: (@shipment.created_at + 2.days + 6.hours).iso8601,
              description: 'Shipment delivered'
            }
          end

          render_success({
            shipment: @shipment,
            tracking: @shipment.shipment_tracking,
            history: tracking_history
          })
        else
          render_error('Tracking information not found')
        end
      end

      private

      def set_shipment
        @shipment = Shipment.find(params[:id])
      end

      def shipment_params
        params.require(:shipment).permit(
          :order_id, :carrier, :tracking_number, :status, :shipped_at,
          :estimated_delivery_date, :actual_delivery_date, :shipping_method,
          :shipping_cost, :warehouse_id, :notes
        )
      end
    end
  end
end
