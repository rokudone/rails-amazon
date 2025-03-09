module Api
  module V1
    class PaymentMethodsController < BaseController
      before_action :set_user
      before_action :set_payment_method, only: [:show, :update, :destroy]

      # GET /api/v1/users/:user_id/payment_methods
      def index
        @payment_methods = @user.payment_methods
        render_success(@payment_methods)
      end

      # GET /api/v1/users/:user_id/payment_methods/:id
      def show
        render_success(@payment_method)
      end

      # POST /api/v1/users/:user_id/payment_methods
      def create
        @payment_method = @user.payment_methods.new(payment_method_params)

        # デフォルト支払い方法の設定
        if params[:default] && params[:default] == true
          @user.payment_methods.update_all(default: false)
          @payment_method.default = true
        end

        if @payment_method.save
          render_success(@payment_method, :created)
        else
          render_error(@payment_method.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/users/:user_id/payment_methods/:id
      def update
        # デフォルト支払い方法の設定
        if params[:default] && params[:default] == true
          @user.payment_methods.update_all(default: false)
          @payment_method.default = true
        end

        if @payment_method.update(payment_method_params)
          render_success(@payment_method)
        else
          render_error(@payment_method.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/users/:user_id/payment_methods/:id
      def destroy
        @payment_method.destroy
        render_success({ message: 'Payment method deleted successfully' })
      end

      private

      def set_user
        @user = params[:user_id] == 'me' ? current_user : User.find(params[:user_id])
        render_forbidden unless @user == current_user || current_user.admin?
      end

      def set_payment_method
        @payment_method = @user.payment_methods.find(params[:id])
      end

      def payment_method_params
        params.require(:payment_method).permit(
          :payment_type, :provider, :account_number, :expiry_month, :expiry_year,
          :name_on_card, :billing_address_id, :default, :card_type, :last_four_digits
        )
      end
    end
  end
end
