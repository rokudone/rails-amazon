module ErrorHandling
  extend ActiveSupport::Concern

  included do
    # エラーハンドリングを設定
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_authenticity_token
    rescue_from ActionController::UnknownFormat, with: :handle_unknown_format
    rescue_from ActionController::RoutingError, with: :handle_routing_error

    # カスタム例外を定義している場合は追加
    if defined?(CustomExceptions)
      rescue_from CustomExceptions::AuthenticationError, with: :handle_authentication_error
      rescue_from CustomExceptions::AuthorizationError, with: :handle_authorization_error
      rescue_from CustomExceptions::ValidationError, with: :handle_validation_error
      rescue_from CustomExceptions::ResourceNotFound, with: :handle_resource_not_found
      rescue_from CustomExceptions::InvalidOperation, with: :handle_invalid_operation
      rescue_from CustomExceptions::ServiceUnavailable, with: :handle_service_unavailable
    end
  end

  # 標準エラーを処理
  def handle_standard_error(exception)
    # エラーをログに記録
    log_error(exception)

    # 開発環境またはテスト環境の場合はエラーを再発生
    if Rails.env.development? || Rails.env.test?
      raise exception
    end

    # エラーレスポンスを返す
    respond_with_error(
      status: :internal_server_error,
      code: 'internal_server_error',
      message: 'An unexpected error occurred',
      details: Rails.env.production? ? nil : exception.message
    )
  end

  # レコードが見つからない場合のエラーを処理
  def handle_not_found(exception)
    # エラーをログに記録
    log_error(exception)

    # エラーレスポンスを返す
    respond_with_error(
      status: :not_found,
      code: 'record_not_found',
      message: exception.message,
      details: exception.message
    )
  end

  # レコードが無効な場合のエラーを処理
  def handle_record_invalid(exception)
    # エラーをログに記録
    log_error(exception)

    # エラーレスポンスを返す
    respond_with_error(
      status: :unprocessable_entity,
      code: 'record_invalid',
      message: 'Validation failed',
      details: exception.record.errors.full_messages
    )
  end

  # パラメータが不足している場合のエラーを処理
  def handle_parameter_missing(exception)
    # エラーをログに記録
    log_error(exception)

    # エラーレスポンスを返す
    respond_with_error(
      status: :bad_request,
      code: 'parameter_missing',
      message: exception.message,
      details: exception.message
    )
  end

  # 不正な認証トークンの場合のエラーを処理
  def handle_invalid_authenticity_token(exception)
    # エラーをログに記録
    log_error(exception)

    # エラーレスポンスを返す
    respond_with_error(
      status: :unprocessable_entity,
      code: 'invalid_authenticity_token',
      message: 'Invalid authenticity token',
      details: exception.message
    )
  end

  # 不明なフォーマットの場合のエラーを処理
  def handle_unknown_format(exception)
    # エラーをログに記録
    log_error(exception)

    # エラーレスポンスを返す
    respond_with_error(
      status: :not_acceptable,
      code: 'unknown_format',
      message: 'Unknown format',
      details: exception.message
    )
  end

  # ルーティングエラーの場合のエラーを処理
  def handle_routing_error(exception)
    # エラーをログに記録
    log_error(exception)

    # エラーレスポンスを返す
    respond_with_error(
      status: :not_found,
      code: 'routing_error',
      message: 'Route not found',
      details: exception.message
    )
  end

  # 認証エラーの場合のエラーを処理
  def handle_authentication_error(exception)
    # エラーをログに記録
    log_error(exception)

    # エラーレスポンスを返す
    respond_with_error(
      status: :unauthorized,
      code: 'authentication_error',
      message: 'Authentication failed',
      details: exception.message
    )
  end

  # 認可エラーの場合のエラーを処理
  def handle_authorization_error(exception)
    # エラーをログに記録
    log_error(exception)

    # エラーレスポンスを返す
    respond_with_error(
      status: :forbidden,
      code: 'authorization_error',
      message: 'You are not authorized to perform this action',
      details: exception.message
    )
  end

  # バリデーションエラーの場合のエラーを処理
  def handle_validation_error(exception)
    # エラーをログに記録
    log_error(exception)

    # エラーレスポンスを返す
    respond_with_error(
      status: :unprocessable_entity,
      code: 'validation_error',
      message: 'Validation failed',
      details: exception.errors
    )
  end

  # リソースが見つからない場合のエラーを処理
  def handle_resource_not_found(exception)
    # エラーをログに記録
    log_error(exception)

    # エラーレスポンスを返す
    respond_with_error(
      status: :not_found,
      code: 'resource_not_found',
      message: 'Resource not found',
      details: exception.message
    )
  end

  # 無効な操作の場合のエラーを処理
  def handle_invalid_operation(exception)
    # エラーをログに記録
    log_error(exception)

    # エラーレスポンスを返す
    respond_with_error(
      status: :unprocessable_entity,
      code: 'invalid_operation',
      message: 'Invalid operation',
      details: exception.message
    )
  end

  # サービスが利用できない場合のエラーを処理
  def handle_service_unavailable(exception)
    # エラーをログに記録
    log_error(exception)

    # エラーレスポンスを返す
    respond_with_error(
      status: :service_unavailable,
      code: 'service_unavailable',
      message: 'Service unavailable',
      details: exception.message
    )
  end

  # エラーをログに記録
  def log_error(exception)
    # ExceptionLoggerが定義されている場合は使用
    if defined?(ExceptionLogger) && ExceptionLogger.respond_to?(:log)
      ExceptionLogger.log(exception, {
        controller: controller_name,
        action: action_name,
        params: params.to_unsafe_h,
        user_id: current_user&.id
      })
    else
      # 標準のログに記録
      Rails.logger.error("#{exception.class.name}: #{exception.message}")
      Rails.logger.error(exception.backtrace.join("\n")) if exception.backtrace
    end
  end

  # エラーレスポンスを返す
  def respond_with_error(status:, code:, message:, details: nil)
    # ErrorResponseBuilderが定義されている場合は使用
    if defined?(ErrorResponseBuilder) && ErrorResponseBuilder.respond_to?(:build)
      response_data = ErrorResponseBuilder.build(
        code: code,
        message: message,
        details: details,
        status: status
      )
    else
      # 標準のエラーレスポンスを構築
      response_data = {
        error: {
          code: code,
          message: message,
          details: details
        }
      }
    end

    # レスポンスを返す
    respond_to do |format|
      format.html { render 'errors/error', locals: { error: response_data[:error] }, status: status }
      format.json { render json: response_data, status: status }
      format.xml { render xml: response_data, status: status }
      format.any { head status }
    end
  end
end
