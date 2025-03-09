module Api
  module V1
    class CouponsController < BaseController
      before_action :set_coupon, only: [:show, :update, :destroy]

      # GET /api/v1/coupons
      def index
        # 管理者のみ全てのクーポンを表示可能
        unless current_user.admin?
          render_forbidden
          return
        end

        @coupons = Coupon.all

        # アクティブなクーポンのみ表示
        @coupons = @coupons.where(active: true) if params[:active] == 'true'

        # タイプでフィルタリング
        @coupons = @coupons.where(coupon_type: params[:type]) if params[:type].present?

        render_success(@coupons)
      end

      # GET /api/v1/coupons/:id
      def show
        # 管理者のみ表示可能
        unless current_user.admin?
          render_forbidden
          return
        end

        render_success(@coupon)
      end

      # POST /api/v1/coupons
      def create
        # 管理者のみ作成可能
        unless current_user.admin?
          render_forbidden
          return
        end

        @coupon = Coupon.new(coupon_params)

        if @coupon.save
          render_success(@coupon, :created)
        else
          render_error(@coupon.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/coupons/:id
      def update
        # 管理者のみ更新可能
        unless current_user.admin?
          render_forbidden
          return
        end

        if @coupon.update(coupon_params)
          render_success(@coupon)
        else
          render_error(@coupon.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/coupons/:id
      def destroy
        # 管理者のみ削除可能
        unless current_user.admin?
          render_forbidden
          return
        end

        @coupon.destroy
        render_success({ message: 'Coupon deleted successfully' })
      end

      # POST /api/v1/coupons/validate
      def validate
        code = params[:code]

        unless code.present?
          render_error('Coupon code is required')
          return
        end

        @coupon = Coupon.find_by(code: code)

        if @coupon.nil?
          render_error('Invalid coupon code')
          return
        end

        # クーポンが有効かチェック
        unless @coupon.active && @coupon.start_date <= Time.current && (@coupon.end_date.nil? || @coupon.end_date >= Time.current)
          render_error('Coupon is not active')
          return
        end

        # 使用回数制限をチェック
        if @coupon.usage_limit.present? && @coupon.used_count >= @coupon.usage_limit
          render_error('Coupon usage limit reached')
          return
        end

        # ユーザーごとの使用回数制限をチェック
        if @coupon.per_user_limit.present?
          user_usage = OrderDiscount.joins(:order)
                                  .where(orders: { user_id: current_user.id })
                                  .where(code: code)
                                  .count

          if user_usage >= @coupon.per_user_limit
            render_error('You have reached the usage limit for this coupon')
            return
          end
        end

        # 最小注文金額をチェック
        if @coupon.minimum_order_amount.present?
          cart = current_user.cart

          if cart.nil? || cart.total < @coupon.minimum_order_amount
            render_error("Minimum order amount of #{@coupon.minimum_order_amount} required")
            return
          end
        end

        render_success({
          coupon: @coupon,
          valid: true,
          message: 'Coupon is valid'
        })
      end

      # POST /api/v1/coupons/apply
      def apply
        code = params[:code]

        unless code.present?
          render_error('Coupon code is required')
          return
        end

        @coupon = Coupon.find_by(code: code)

        if @coupon.nil?
          render_error('Invalid coupon code')
          return
        end

        # クーポンが有効かチェック
        unless @coupon.active && @coupon.start_date <= Time.current && (@coupon.end_date.nil? || @coupon.end_date >= Time.current)
          render_error('Coupon is not active')
          return
        end

        # 使用回数制限をチェック
        if @coupon.usage_limit.present? && @coupon.used_count >= @coupon.usage_limit
          render_error('Coupon usage limit reached')
          return
        end

        # ユーザーごとの使用回数制限をチェック
        if @coupon.per_user_limit.present?
          user_usage = OrderDiscount.joins(:order)
                                  .where(orders: { user_id: current_user.id })
                                  .where(code: code)
                                  .count

          if user_usage >= @coupon.per_user_limit
            render_error('You have reached the usage limit for this coupon')
            return
          end
        end

        # カートの取得
        cart = current_user.cart

        unless cart
          render_error('Cart not found')
          return
        end

        # 最小注文金額をチェック
        if @coupon.minimum_order_amount.present? && cart.total < @coupon.minimum_order_amount
          render_error("Minimum order amount of #{@coupon.minimum_order_amount} required")
          return
        end

        # 割引の計算
        discount_amount = calculate_discount(cart)

        # カートに割引を適用
        cart.update(
          discount: discount_amount,
          discount_code: code
        )

        render_success({
          coupon: @coupon,
          discount_amount: discount_amount,
          cart_total_before_discount: cart.total + discount_amount,
          cart_total_after_discount: cart.total,
          message: 'Coupon applied successfully'
        })
      end

      private

      def set_coupon
        @coupon = Coupon.find(params[:id])
      end

      def coupon_params
        params.require(:coupon).permit(
          :code, :description, :coupon_type, :discount_type, :discount_value,
          :minimum_order_amount, :active, :start_date, :end_date,
          :usage_limit, :used_count, :per_user_limit
        )
      end

      def calculate_discount(cart)
        case @coupon.discount_type
        when 'percentage'
          (cart.total * @coupon.discount_value / 100).round(2)
        when 'fixed_amount'
          [@coupon.discount_value, cart.total].min
        when 'free_shipping'
          cart.shipping_cost || 0
        else
          0
        end
      end
    end
  end
end
