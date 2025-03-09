module CustomExceptions
  # 基本例外クラス
  class BaseError < StandardError
    attr_reader :code, :details, :severity

    def initialize(message = nil, code = nil, details = nil, severity = :warning)
      @code = code
      @details = details
      @severity = severity
      super(message)
    end

    def to_hash
      {
        error: {
          type: self.class.name,
          code: @code,
          message: message,
          details: @details,
          severity: @severity
        }
      }
    end
  end

  # 認証関連の例外
  class AuthenticationError < BaseError
    def initialize(message = 'Authentication failed', code = 'authentication_failed', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # 認可関連の例外
  class AuthorizationError < BaseError
    def initialize(message = 'Authorization failed', code = 'authorization_failed', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # リソースが見つからない例外
  class ResourceNotFoundError < BaseError
    def initialize(message = 'Resource not found', code = 'resource_not_found', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # バリデーション関連の例外
  class ValidationError < BaseError
    def initialize(message = 'Validation failed', code = 'validation_failed', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # ビジネスロジック関連の例外
  class BusinessLogicError < BaseError
    def initialize(message = 'Business logic error', code = 'business_logic_error', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # 外部サービス関連の例外
  class ExternalServiceError < BaseError
    def initialize(message = 'External service error', code = 'external_service_error', details = nil, severity = :error)
      super(message, code, details, severity)
    end
  end

  # レート制限関連の例外
  class RateLimitError < BaseError
    def initialize(message = 'Rate limit exceeded', code = 'rate_limit_exceeded', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # ドメイン例外

  # 在庫不足例外
  class InsufficientStockError < BusinessLogicError
    def initialize(message = 'Insufficient stock', code = 'insufficient_stock', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # 支払い失敗例外
  class PaymentFailedError < BusinessLogicError
    def initialize(message = 'Payment failed', code = 'payment_failed', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # 注文キャンセル例外
  class OrderCancellationError < BusinessLogicError
    def initialize(message = 'Order cancellation failed', code = 'order_cancellation_failed', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # 配送不可例外
  class ShippingNotAvailableError < BusinessLogicError
    def initialize(message = 'Shipping not available', code = 'shipping_not_available', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # クーポン無効例外
  class InvalidCouponError < ValidationError
    def initialize(message = 'Invalid coupon', code = 'invalid_coupon', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # アカウント無効例外
  class AccountDisabledError < AuthenticationError
    def initialize(message = 'Account is disabled', code = 'account_disabled', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # インフラ例外

  # データベース接続例外
  class DatabaseConnectionError < BaseError
    def initialize(message = 'Database connection error', code = 'database_connection_error', details = nil, severity = :error)
      super(message, code, details, severity)
    end
  end

  # キャッシュ接続例外
  class CacheConnectionError < BaseError
    def initialize(message = 'Cache connection error', code = 'cache_connection_error', details = nil, severity = :error)
      super(message, code, details, severity)
    end
  end

  # 外部API接続例外
  class ApiConnectionError < ExternalServiceError
    def initialize(message = 'API connection error', code = 'api_connection_error', details = nil, severity = :error)
      super(message, code, details, severity)
    end
  end

  # 外部API応答例外
  class ApiResponseError < ExternalServiceError
    def initialize(message = 'API response error', code = 'api_response_error', details = nil, severity = :error)
      super(message, code, details, severity)
    end
  end

  # ファイルシステム例外
  class FileSystemError < BaseError
    def initialize(message = 'File system error', code = 'file_system_error', details = nil, severity = :error)
      super(message, code, details, severity)
    end
  end

  # メール送信例外
  class EmailDeliveryError < ExternalServiceError
    def initialize(message = 'Email delivery error', code = 'email_delivery_error', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # SMS送信例外
  class SmsDeliveryError < ExternalServiceError
    def initialize(message = 'SMS delivery error', code = 'sms_delivery_error', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # 決済ゲートウェイ例外
  class PaymentGatewayError < ExternalServiceError
    def initialize(message = 'Payment gateway error', code = 'payment_gateway_error', details = nil, severity = :error)
      super(message, code, details, severity)
    end
  end

  # 配送API例外
  class ShippingApiError < ExternalServiceError
    def initialize(message = 'Shipping API error', code = 'shipping_api_error', details = nil, severity = :error)
      super(message, code, details, severity)
    end
  end

  # 検索エンジン例外
  class SearchEngineError < ExternalServiceError
    def initialize(message = 'Search engine error', code = 'search_engine_error', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # バックグラウンドジョブ例外
  class BackgroundJobError < BaseError
    def initialize(message = 'Background job error', code = 'background_job_error', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # 設定エラー例外
  class ConfigurationError < BaseError
    def initialize(message = 'Configuration error', code = 'configuration_error', details = nil, severity = :error)
      super(message, code, details, severity)
    end
  end

  # 機能無効例外
  class FeatureDisabledError < BaseError
    def initialize(message = 'Feature is disabled', code = 'feature_disabled', details = nil, severity = :warning)
      super(message, code, details, severity)
    end
  end

  # 依存関係エラー例外
  class DependencyError < BaseError
    def initialize(message = 'Dependency error', code = 'dependency_error', details = nil, severity = :error)
      super(message, code, details, severity)
    end
  end
end
