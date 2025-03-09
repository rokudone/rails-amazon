class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  # エラーハンドリング
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  rescue_from StandardError, with: :internal_server_error

  # 認証フィルタ
  def authenticate_user
    authenticate_with_http_token do |token, options|
      @current_user = User.joins(:user_sessions)
                          .where(user_sessions: { token: token, expired_at: nil })
                          .or(User.joins(:user_sessions).where('user_sessions.expired_at > ?', Time.current))
                          .first
    end
    render_unauthorized unless @current_user
  end

  def current_user
    @current_user
  end

  # パラメータサニタイズ
  def sanitize_params
    params.permit!
  end

  # レスポンスフォーマット
  def render_success(data = {}, status = :ok)
    render json: { success: true, data: data }, status: status
  end

  def render_error(message, status = :unprocessable_entity)
    render json: { success: false, error: message }, status: status
  end

  def render_unauthorized
    render json: { success: false, error: 'Unauthorized' }, status: :unauthorized
  end

  def render_forbidden
    render json: { success: false, error: 'Forbidden' }, status: :forbidden
  end

  private

  def record_not_found(exception)
    render_error("Record not found: #{exception.message}", :not_found)
  end

  def record_invalid(exception)
    render_error(exception.record.errors.full_messages.join(', '), :unprocessable_entity)
  end

  def parameter_missing(exception)
    render_error("Parameter missing: #{exception.message}", :bad_request)
  end

  def internal_server_error(exception)
    Rails.logger.error("Internal server error: #{exception.message}\n#{exception.backtrace.join("\n")}")
    render_error('Internal server error', :internal_server_error)
  end
end
