module Api
  module V1
    class AddressesController < BaseController
      before_action :set_user
      before_action :set_address, only: [:show, :update, :destroy]

      # GET /api/v1/users/:user_id/addresses
      def index
        @addresses = @user.addresses
        render_success(@addresses)
      end

      # GET /api/v1/users/:user_id/addresses/:id
      def show
        render_success(@address)
      end

      # POST /api/v1/users/:user_id/addresses
      def create
        @address = @user.addresses.new(address_params)

        # デフォルトアドレスの設定
        if params[:default] && params[:default] == true
          @user.addresses.update_all(default: false)
          @address.default = true
        end

        if @address.save
          render_success(@address, :created)
        else
          render_error(@address.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/users/:user_id/addresses/:id
      def update
        # デフォルトアドレスの設定
        if params[:default] && params[:default] == true
          @user.addresses.update_all(default: false)
          @address.default = true
        end

        if @address.update(address_params)
          render_success(@address)
        else
          render_error(@address.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/users/:user_id/addresses/:id
      def destroy
        @address.destroy
        render_success({ message: 'Address deleted successfully' })
      end

      private

      def set_user
        @user = params[:user_id] == 'me' ? current_user : User.find(params[:user_id])
        render_forbidden unless @user == current_user || current_user.admin?
      end

      def set_address
        @address = @user.addresses.find(params[:id])
      end

      def address_params
        params.require(:address).permit(
          :address_type, :first_name, :last_name, :company, :address_line1,
          :address_line2, :city, :state, :postal_code, :country, :phone_number,
          :default, :delivery_instructions
        )
      end
    end
  end
end
