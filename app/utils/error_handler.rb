module ErrorHandler
  class << self
    # エラーを処理
    def handle_error(error, context = {})
      # エラーを分類
      error_info = classify_error(error)

      # エラーをログに記録
      log_error(error, error_info, context)

      # エラーレスポンスを生成
      generate_error_response(error, error_info, context)
    end

    # エラーを分類
    def classify_error(error)
      case error
      when ActiveRecord::RecordNotFound
        {
          type: :not_found,
          code: 'record_not_found',
          status: 404,
          severity: :warning
        }
      when ActiveRecord::RecordInvalid
        {
          type: :validation,
          code: 'record_invalid',
          status: 422,
          severity: :warning
        }
      when ActiveRecord::RecordNotUnique
        {
          type: :validation,
          code: 'record_not_unique',
          status: 422,
          severity: :warning
        }
      when ActiveRecord::RecordNotSaved
        {
          type: :validation,
          code: 'record_not_saved',
          status: 422,
          severity: :warning
        }
      when ActionController::ParameterMissing
        {
          type: :validation,
          code: 'parameter_missing',
          status: 400,
          severity: :warning
        }
      when ActionController::InvalidAuthenticityToken
        {
          type: :security,
          code: 'invalid_authenticity_token',
          status: 422,
          severity: :warning
        }
      when JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError
        {
          type: :authentication,
          code: 'invalid_token',
          status: 401,
          severity: :warning
        }
      when JWT::InvalidIssuerError, JWT::InvalidAudError
        {
          type: :authentication,
          code: 'invalid_token_claims',
          status: 401,
          severity: :warning
        }
      when CustomExceptions::AuthenticationError
        {
          type: :authentication,
          code: 'authentication_failed',
          status: 401,
          severity: :warning
        }
      when CustomExceptions::AuthorizationError
        {
          type: :authorization,
          code: 'authorization_failed',
          status: 403,
          severity: :warning
        }
      when CustomExceptions::ResourceNotFoundError
        {
          type: :not_found,
          code: 'resource_not_found',
          status: 404,
          severity: :warning
        }
      when CustomExceptions::ValidationError
        {
          type: :validation,
          code: 'validation_failed',
          status: 422,
          severity: :warning
        }
      when CustomExceptions::BusinessLogicError
        {
          type: :business_logic,
          code: 'business_logic_error',
          status: 422,
          severity: :warning
        }
      when CustomExceptions::ExternalServiceError
        {
          type: :external_service,
          code: 'external_service_error',
          status: 503,
          severity: :error
        }
      when CustomExceptions::RateLimitError
        {
          type: :rate_limit,
          code: 'rate_limit_exceeded',
          status: 429,
          severity: :warning
        }
      when StandardError
        {
          type: :internal_server_error,
          code: 'internal_server_error',
          status: 500,
          severity: :error
        }
      else
        {
          type: :unknown,
          code: 'unknown_error',
          status: 500,
          severity: :error
        }
      end
    end

    # エラーをログに記録
    def log_error(error, error_info, context)
      # エラーレベルを決定
      level = case error_info[:severity]
              when :warning
                :warn
              when :error
                :error
              when :fatal
                :fatal
              else
                :error
              end

      # コンテキスト情報を整形
      context_info = format_context(context)

      # エラーメッセージを整形
      message = format_error_message(error, error_info, context_info)

      # ログに記録
      Rails.logger.send(level, message)

      # 重大なエラーの場合は例外ロガーに記録
      if error_info[:severity] == :error || error_info[:severity] == :fatal
        ExceptionLogger.log(error, error_info, context)
      end
    end

    # エラーレスポンスを生成
    def generate_error_response(error, error_info, context)
      ErrorResponseBuilder.build(error, error_info, context)
    end

    private

    # コンテキスト情報を整形
    def format_context(context)
      return {} unless context.is_a?(Hash)

      # 機密情報をフィルタリング
      filtered_context = context.dup

      # パスワードなどの機密情報をフィルタリング
      %w[password password_confirmation credit_card token].each do |key|
        if filtered_context.key?(key)
          filtered_context[key] = '[FILTERED]'
        end
      end

      filtered_context
    end

    # エラーメッセージを整形
    def format_error_message(error, error_info, context_info)
      message = "[#{error_info[:type].to_s.upcase}] #{error.class.name}: #{error.message}"

      # バリデーションエラーの場合は詳細を追加
      if error.is_a?(ActiveRecord::RecordInvalid) && error.record.present?
        message += "\nValidation errors: #{error.record.errors.full_messages.join(', ')}"
      end

      # コンテキスト情報がある場合は追加
      unless context_info.empty?
        message += "\nContext: #{context_info.inspect}"
      end

      # スタックトレースを追加
      message += "\n#{error.backtrace.join("\n")}" if error.backtrace

      message
    end
  end
end
