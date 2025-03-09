module Api
  module V1
    class PromotionsController < BaseController
      skip_before_action :authenticate_user, only: [:index, :show]
      before_action :set_promotion, only: [:show, :update, :destroy, :apply]

      # GET /api/v1/promotions
      def index
        @promotions = Promotion.all

        # アクティブなプロモーションのみ表示（管理者以外）
        unless current_user&.admin?
          @promotions = @promotions.where(active: true)
                                  .where('start_date <= ?', Time.current)
                                  .where('end_date >= ? OR end_date IS NULL', Time.current)
        end

        # タイプでフィルタリング
        @promotions = @promotions.where(promotion_type: params[:type]) if params[:type].present?

        render_success(@promotions)
      end

      # GET /api/v1/promotions/:id
      def show
        # アクティブなプロモーションのみ表示（管理者以外）
        unless current_user&.admin? || (@promotion.active && @promotion.start_date <= Time.current && (@promotion.end_date.nil? || @promotion.end_date >= Time.current))
          render_forbidden
          return
        end

        render_success(@promotion)
      end

      # POST /api/v1/promotions
      def create
        # 管理者のみ作成可能
        unless current_user.admin?
          render_forbidden
          return
        end

        @promotion = Promotion.new(promotion_params)

        if @promotion.save
          # プロモーションルールの作成
          if params[:rules].present?
            params[:rules].each do |rule|
              @promotion.promotion_rules.create(
                rule_type: rule[:rule_type],
                value: rule[:value],
                operator: rule[:operator]
              )
            end
          end

          render_success(@promotion, :created)
        else
          render_error(@promotion.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/promotions/:id
      def update
        # 管理者のみ更新可能
        unless current_user.admin?
          render_forbidden
          return
        end

        if @promotion.update(promotion_params)
          render_success(@promotion)
        else
          render_error(@promotion.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/promotions/:id
      def destroy
        # 管理者のみ削除可能
        unless current_user.admin?
          render_forbidden
          return
        end

        @promotion.destroy
        render_success({ message: 'Promotion deleted successfully' })
      end

      # POST /api/v1/promotions/:id/apply
      def apply
        # プロモーションが有効かチェック
        unless @promotion.active && @promotion.start_date <= Time.current && (@promotion.end_date.nil? || @promotion.end_date >= Time.current)
          render_error('Promotion is not active')
          return
        end

        # カートの取得
        cart = current_user.cart

        unless cart
          render_error('Cart not found')
          return
        end

        # プロモーションルールの検証
        valid = true

        @promotion.promotion_rules.each do |rule|
          case rule.rule_type
          when 'minimum_order_amount'
            valid = false if cart.total < rule.value.to_f
          when 'minimum_quantity'
            valid = false if cart.cart_items.sum(:quantity) < rule.value.to_i
          when 'specific_product'
            valid = false unless cart.cart_items.joins(:product).where(products: { id: rule.value }).exists?
          when 'specific_category'
            valid = false unless cart.cart_items.joins(:product).where(products: { category_id: rule.value }).exists?
          end
        end

        if valid
          # 割引の計算
          discount_amount = calculate_discount(cart)

          render_success({
            promotion: @promotion,
            discount_amount: discount_amount,
            message: 'Promotion applied successfully'
          })
        else
          render_error('Cart does not meet promotion requirements')
        end
      end

      private

      def set_promotion
        @promotion = Promotion.find(params[:id])
      end

      def promotion_params
        params.require(:promotion).permit(
          :name, :description, :promotion_type, :discount_type, :discount_value,
          :code, :active, :start_date, :end_date, :usage_limit, :used_count
        )
      end

      def calculate_discount(cart)
        case @promotion.discount_type
        when 'percentage'
          (cart.total * @promotion.discount_value / 100).round(2)
        when 'fixed_amount'
          [@promotion.discount_value, cart.total].min
        when 'free_shipping'
          cart.shipping_cost || 0
        else
          0
        end
      end
    end
  end
end
