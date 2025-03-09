module Api
  module V1
    class UsersController < BaseController
      skip_before_action :authenticate_user, only: [:create]
      before_action :set_user, only: [:show, :update, :destroy, :activate, :deactivate]

      # GET /api/v1/users
      def index
        @users = User.all
        render_success(@users)
      end

      # GET /api/v1/users/1
      def show
        render_success(@user)
      end

      # GET /api/v1/users/me
      def me
        render_success(current_user)
      end

      # POST /api/v1/users
      def create
        @user = User.new(user_params)
        if @user.save
          # プロフィールの作成
          @user.create_profile(profile_params) if profile_params.present?
          render_success(@user, :created)
        else
          render_error(@user.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/users/1
      def update
        if @user.update(user_params)
          render_success(@user)
        else
          render_error(@user.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/users/update_profile
      def update_profile
        @profile = current_user.profile || current_user.build_profile
        if @profile.update(profile_params)
          render_success(@profile)
        else
          render_error(@profile.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/users/update_password
      def update_password
        if current_user.authenticate(params[:current_password])
          if current_user.update(password: params[:new_password], password_confirmation: params[:password_confirmation])
            render_success({ message: 'Password updated successfully' })
          else
            render_error(current_user.errors.full_messages.join(', '))
          end
        else
          render_error('Current password is incorrect')
        end
      end

      # DELETE /api/v1/users/1
      def destroy
        @user.destroy
        render_success({ message: 'User deleted successfully' })
      end

      # PUT /api/v1/users/1/activate
      def activate
        if @user.update(active: true)
          render_success({ message: 'User activated successfully' })
        else
          render_error(@user.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/users/1/deactivate
      def deactivate
        if @user.update(active: false)
          render_success({ message: 'User deactivated successfully' })
        else
          render_error(@user.errors.full_messages.join(', '))
        end
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(
          :email, :password, :password_confirmation, :first_name, :last_name,
          :phone_number, :active, :role
        )
      end

      def profile_params
        params.permit(
          :nickname, :avatar, :bio, :gender, :birth_date, :website,
          :company, :position, :language, :timezone, :currency
        )
      end
    end
  end
end
