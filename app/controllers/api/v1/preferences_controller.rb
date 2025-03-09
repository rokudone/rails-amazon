module Api
  module V1
    class PreferencesController < BaseController
      before_action :set_user

      # GET /api/v1/users/:user_id/preferences
      def index
        @preference = @user.user_preference || @user.build_user_preference
        render_success(@preference)
      end

      # PUT /api/v1/users/:user_id/preferences
      def update
        @preference = @user.user_preference || @user.build_user_preference

        if @preference.update(preference_params)
          render_success(@preference)
        else
          render_error(@preference.errors.full_messages.join(', '))
        end
      end

      private

      def set_user
        @user = params[:user_id] == 'me' ? current_user : User.find(params[:user_id])
        render_forbidden unless @user == current_user || current_user.admin?
      end

      def preference_params
        params.require(:preference).permit(
          :language, :currency, :timezone, :notification_email, :notification_push,
          :notification_sms, :marketing_email, :marketing_push, :marketing_sms,
          :theme, :display_mode, :items_per_page, :default_view, :accessibility_mode
        )
      end
    end
  end
end
