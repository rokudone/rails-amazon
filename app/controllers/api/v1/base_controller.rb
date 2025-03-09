module Api
  module V1
    class BaseController < ApplicationController
      before_action :set_default_format
      before_action :authenticate_user, except: [:health_check]

      def health_check
        render_success({ status: 'ok', version: '1.0.0' })
      end

      private

      def set_default_format
        request.format = :json
      end
    end
  end
end
