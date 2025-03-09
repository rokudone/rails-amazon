module ErrorResponseBuilder
  class << self
    # エラーレスポンスを構築
    def build(error, error_info = nil, context = {})
      # エラー情報がない場合は生成
      error_info ||= ErrorHandler.classify_error(error)

      # レスポンスを構築
      {
        status: error_info[:status],
        json: build_error_json(error, error_info, context),
        headers: build_error_headers(error, error_info)
      }
    end

    # エラーJSONを構築
    def build_error_json(error, error_info, context = {})
      {
        error: {
          code: error_info[:code],
          message: get_error_message(error, error_info, context),
          details: get_error_details(error, error_info, context),
          status: error_info[:status],
          type: error_info[:type],
          request_id: context[:request_id]
        }
      }
    end

    # エラーヘッダーを構築
    def build_error_headers(error, error_info)
      headers = {}

      # レート制限エラーの場合はレート制限ヘッダーを追加
      if error_info[:type] == :rate_limit
        headers['X-RateLimit-Limit'] = get_rate_limit_limit(error)
        headers['X-RateLimit-Remaining'] = get_rate_limit_remaining(error)
        headers['X-RateLimit-Reset'] = get_rate_limit_reset(error)
      end

      # リクエストIDがある場合は追加
      if error.respond_to?(:request_id) && error.request_id
        headers['X-Request-ID'] = error.request_id
      end

      headers
    end

    # エラーメッセージを取得
    def get_error_message(error, error_info, context = {})
      # カスタム例外の場合はそのメッセージを使用
      if error.is_a?(CustomExceptions::BaseError)
        return error.message
      end

      # ActiveRecordのバリデーションエラーの場合
      if error.is_a?(ActiveRecord::RecordInvalid)
        return error.record.errors.full_messages.join(', ')
      end

      # エラーコードに基づいてメッセージを取得
      message = translate_error_message(error_info[:code], context[:locale])

      # 翻訳がない場合はエラーメッセージを使用
      message || error.message
    end

    # エラー詳細を取得
    def get_error_details(error, error_info, context = {})
      # カスタム例外の場合はその詳細を使用
      if error.is_a?(CustomExceptions::BaseError) && error.details
        return error.details
      end

      # ActiveRecordのバリデーションエラーの場合
      if error.is_a?(ActiveRecord::RecordInvalid)
        return error.record.errors.messages
      end

      # パラメータ不足エラーの場合
      if error.is_a?(ActionController::ParameterMissing)
        return { parameter: error.param }
      end

      # その他のエラーの場合は空のハッシュを返す
      {}
    end

    # エラーメッセージを翻訳
    def translate_error_message(error_code, locale = nil)
      locale ||= I18n.locale

      # エラーコードに基づいて翻訳を取得
      I18n.t("errors.#{error_code}", default: nil, locale: locale)
    end

    # レート制限の上限を取得
    def get_rate_limit_limit(error)
      # レート制限エラーの場合は上限を取得
      if error.respond_to?(:limit)
        error.limit.to_s
      else
        '60'
      end
    end

    # レート制限の残り回数を取得
    def get_rate_limit_remaining(error)
      # レート制限エラーの場合は残り回数を取得
      if error.respond_to?(:remaining)
        error.remaining.to_s
      else
        '0'
      end
    end

    # レート制限のリセット時間を取得
    def get_rate_limit_reset(error)
      # レート制限エラーの場合はリセット時間を取得
      if error.respond_to?(:reset_at)
        error.reset_at.to_i.to_s
      else
        (Time.current + 1.hour).to_i.to_s
      end
    end
  end

  # エラーコード定義
  module ErrorCodes
    # 認証関連
    AUTHENTICATION_FAILED = 'authentication_failed'
    INVALID_TOKEN = 'invalid_token'
    INVALID_CREDENTIALS = 'invalid_credentials'
    ACCOUNT_LOCKED = 'account_locked'
    ACCOUNT_DISABLED = 'account_disabled'

    # 認可関連
    AUTHORIZATION_FAILED = 'authorization_failed'
    FORBIDDEN = 'forbidden'
    INSUFFICIENT_PERMISSIONS = 'insufficient_permissions'

    # リソース関連
    RESOURCE_NOT_FOUND = 'resource_not_found'
    RESOURCE_ALREADY_EXISTS = 'resource_already_exists'
    RESOURCE_CONFLICT = 'resource_conflict'

    # バリデーション関連
    VALIDATION_FAILED = 'validation_failed'
    INVALID_PARAMETERS = 'invalid_parameters'
    PARAMETER_MISSING = 'parameter_missing'
    INVALID_FORMAT = 'invalid_format'

    # ビジネスロジック関連
    BUSINESS_LOGIC_ERROR = 'business_logic_error'
    INSUFFICIENT_STOCK = 'insufficient_stock'
    PAYMENT_FAILED = 'payment_failed'
    ORDER_CANCELLATION_FAILED = 'order_cancellation_failed'
    SHIPPING_NOT_AVAILABLE = 'shipping_not_available'
    INVALID_COUPON = 'invalid_coupon'

    # 外部サービス関連
    EXTERNAL_SERVICE_ERROR = 'external_service_error'
    API_CONNECTION_ERROR = 'api_connection_error'
    API_RESPONSE_ERROR = 'api_response_error'
    PAYMENT_GATEWAY_ERROR = 'payment_gateway_error'
    SHIPPING_API_ERROR = 'shipping_api_error'
    EMAIL_DELIVERY_ERROR = 'email_delivery_error'
    SMS_DELIVERY_ERROR = 'sms_delivery_error'

    # レート制限関連
    RATE_LIMIT_EXCEEDED = 'rate_limit_exceeded'

    # サーバーエラー関連
    INTERNAL_SERVER_ERROR = 'internal_server_error'
    DATABASE_CONNECTION_ERROR = 'database_connection_error'
    CACHE_CONNECTION_ERROR = 'cache_connection_error'
    FILE_SYSTEM_ERROR = 'file_system_error'
    BACKGROUND_JOB_ERROR = 'background_job_error'

    # その他
    UNKNOWN_ERROR = 'unknown_error'
    FEATURE_DISABLED = 'feature_disabled'
    CONFIGURATION_ERROR = 'configuration_error'
    DEPENDENCY_ERROR = 'dependency_error'
  end

  # HTTPステータスコード定義
  module StatusCodes
    OK = 200
    CREATED = 201
    ACCEPTED = 202
    NO_CONTENT = 204

    BAD_REQUEST = 400
    UNAUTHORIZED = 401
    PAYMENT_REQUIRED = 402
    FORBIDDEN = 403
    NOT_FOUND = 404
    METHOD_NOT_ALLOWED = 405
    NOT_ACCEPTABLE = 406
    CONFLICT = 409
    GONE = 410
    UNPROCESSABLE_ENTITY = 422
    TOO_MANY_REQUESTS = 429

    INTERNAL_SERVER_ERROR = 500
    NOT_IMPLEMENTED = 501
    BAD_GATEWAY = 502
    SERVICE_UNAVAILABLE = 503
    GATEWAY_TIMEOUT = 504
  end
end
