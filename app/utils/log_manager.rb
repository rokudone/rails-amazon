module LogManager
  class << self
    # ログを記録
    def log(message, level = :info, context = {})
      # ログレベルを決定
      log_level = normalize_log_level(level)

      # コンテキスト情報を整形
      context_info = format_context(context)

      # ログメッセージを整形
      formatted_message = format_log_message(message, context_info)

      # ログに記録
      Rails.logger.send(log_level, formatted_message)

      # データベースにも記録
      log_to_database(message, level, context) if should_log_to_database?(level)

      true
    end

    # デバッグログを記録
    def debug(message, context = {})
      log(message, :debug, context)
    end

    # 情報ログを記録
    def info(message, context = {})
      log(message, :info, context)
    end

    # 警告ログを記録
    def warn(message, context = {})
      log(message, :warn, context)
    end

    # エラーログを記録
    def error(message, context = {})
      log(message, :error, context)
    end

    # 致命的エラーログを記録
    def fatal(message, context = {})
      log(message, :fatal, context)
    end

    # 例外をログに記録
    def exception(exception, context = {})
      # 例外情報を整形
      message = format_exception(exception)

      # エラーログとして記録
      error(message, context.merge(exception: exception.class.name))

      # 重大な例外の場合は例外ロガーにも記録
      ExceptionLogger.log(exception, nil, context) if defined?(ExceptionLogger)
    end

    # アプリケーションイベントをログに記録
    def event(event_type, event_data = {}, level = :info)
      # イベント情報を整形
      message = "Event: #{event_type}"
      context = { event_type: event_type, event_data: event_data }

      # ログに記録
      log(message, level, context)

      # イベントログにも記録
      log_event(event_type, event_data, level)
    end

    # ユーザーアクションをログに記録
    def user_action(user_id, action, data = {}, level = :info)
      # ユーザーアクション情報を整形
      message = "User #{user_id}: #{action}"
      context = { user_id: user_id, action: action, data: data }

      # ログに記録
      log(message, level, context)

      # ユーザーログにも記録
      log_user_action(user_id, action, data)
    end

    # APIリクエストをログに記録
    def api_request(request, response = nil, level = :info)
      # リクエスト情報を整形
      message = "API Request: #{request[:method]} #{request[:path]}"
      context = {
        request: filter_sensitive_data(request),
        response: response.nil? ? nil : filter_sensitive_data(response)
      }

      # ログに記録
      log(message, level, context)
    end

    # パフォーマンスメトリクスをログに記録
    def performance(operation, duration, metadata = {}, level = :info)
      # パフォーマンス情報を整形
      message = "Performance: #{operation} took #{duration}ms"
      context = { operation: operation, duration: duration, metadata: metadata }

      # ログに記録
      log(message, level, context)
    end

    # ログレベルを設定
    def set_log_level(level)
      # ログレベルを正規化
      log_level = normalize_log_level(level)

      # Railsロガーのログレベルを設定
      Rails.logger.level = Logger.const_get(log_level.to_s.upcase)
    end

    # 現在のログレベルを取得
    def log_level
      # Railsロガーのログレベルを取得
      Logger::SEV_LABEL[Rails.logger.level].downcase.to_sym
    end

    # ログファイルをローテーション
    def rotate_logs
      # 実際のアプリケーションでは、logrotateなどの外部ツールを使用
      # ここではシミュレーションのみ
      Rails.logger.info("Log rotation would be performed")
    end

    # ログファイルをクリア
    def clear_logs
      # 実際のアプリケーションでは、ログファイルを空にする
      # ここではシミュレーションのみ
      Rails.logger.info("Log clearing would be performed")
    end

    # ログファイルのパスを取得
    def log_file_path
      # Railsロガーのログファイルパスを取得
      Rails.logger.instance_variable_get(:@logdev)&.filename
    end

    private

    # ログレベルを正規化
    def normalize_log_level(level)
      case level.to_s.downcase.to_sym
      when :debug, :info, :warn, :error, :fatal
        level.to_s.downcase.to_sym
      else
        :info
      end
    end

    # コンテキスト情報を整形（機密情報を削除）
    def format_context(context)
      return {} unless context.is_a?(Hash)

      # 機密情報をフィルタリング
      filter_sensitive_data(context)
    end

    # 機密情報をフィルタリング
    def filter_sensitive_data(data)
      return data unless data.is_a?(Hash)

      # データをコピー
      filtered_data = data.dup

      # パスワードなどの機密情報をフィルタリング
      %w[password password_confirmation credit_card token secret key].each do |key|
        if filtered_data.key?(key)
          filtered_data[key] = '[FILTERED]'
        end
      end

      # ネストされたハッシュも処理
      filtered_data.each do |key, value|
        if value.is_a?(Hash)
          filtered_data[key] = filter_sensitive_data(value)
        end
      end

      filtered_data
    end

    # ログメッセージを整形
    def format_log_message(message, context)
      # コンテキストがある場合は追加
      if context.present?
        "#{message} #{context.inspect}"
      else
        message
      end
    end

    # 例外情報を整形
    def format_exception(exception)
      message = "#{exception.class.name}: #{exception.message}"

      # バックトレースがある場合は追加
      if exception.backtrace
        message += "\n#{exception.backtrace.join("\n")}"
      end

      message
    end

    # データベースにログを記録
    def log_to_database(message, level, context)
      # EventLogモデルが定義されている場合のみ実行
      return unless defined?(EventLog)

      # イベントログを作成
      EventLog.create(
        event_type: 'log',
        severity: level.to_s,
        message: message,
        details: context
      )
    rescue => e
      # データベースへの記録に失敗した場合はログに記録
      Rails.logger.error("Failed to log to database: #{e.message}")
    end

    # データベースに記録すべきかどうかを判断
    def should_log_to_database?(level)
      # 開発環境では記録しない
      return false if Rails.env.development?

      # 重大なログのみ記録
      [:error, :fatal].include?(normalize_log_level(level))
    end

    # イベントログを記録
    def log_event(event_type, event_data, level)
      # EventLogモデルが定義されている場合のみ実行
      return unless defined?(EventLog)

      # イベントログを作成
      EventLog.create(
        event_type: event_type,
        severity: level.to_s,
        message: "Event: #{event_type}",
        details: event_data
      )
    rescue => e
      # データベースへの記録に失敗した場合はログに記録
      Rails.logger.error("Failed to log event: #{e.message}")
    end

    # ユーザーログを記録
    def log_user_action(user_id, action, data)
      # UserLogモデルが定義されている場合のみ実行
      return unless defined?(UserLog)

      # ユーザーログを作成
      UserLog.create(
        user_id: user_id,
        action: action,
        details: data
      )
    rescue => e
      # データベースへの記録に失敗した場合はログに記録
      Rails.logger.error("Failed to log user action: #{e.message}")
    end
  end

  # ログフォーマッター
  module Formatters
    # JSONフォーマッター
    class JsonFormatter
      def call(severity, time, progname, msg)
        # ログエントリをJSONに変換
        log_entry = {
          timestamp: time.iso8601,
          level: severity,
          message: msg,
          program: progname
        }

        # 環境情報を追加
        log_entry[:environment] = Rails.env

        # リクエスト情報を追加
        if Thread.current[:request_id]
          log_entry[:request_id] = Thread.current[:request_id]
        end

        # ユーザー情報を追加
        if Thread.current[:current_user_id]
          log_entry[:user_id] = Thread.current[:current_user_id]
        end

        # JSONに変換して改行を追加
        "#{log_entry.to_json}\n"
      end
    end

    # テキストフォーマッター
    class TextFormatter
      def call(severity, time, progname, msg)
        # ログエントリをテキストに変換
        timestamp = time.strftime('%Y-%m-%d %H:%M:%S.%L')
        program = progname.nil? ? '' : " [#{progname}]"
        request_id = Thread.current[:request_id] ? " request_id=#{Thread.current[:request_id]}" : ''
        user_id = Thread.current[:current_user_id] ? " user_id=#{Thread.current[:current_user_id]}" : ''

        "[#{timestamp}] #{severity}#{program}#{request_id}#{user_id}: #{msg}\n"
      end
    end
  end

  # ログフィルター
  module Filters
    # 機密情報フィルター
    class SensitiveDataFilter
      def initialize(sensitive_keys = nil)
        @sensitive_keys = sensitive_keys || %w[password password_confirmation credit_card token secret key]
      end

      def filter(data)
        return data unless data.is_a?(Hash)

        # データをコピー
        filtered_data = data.dup

        # 機密情報をフィルタリング
        @sensitive_keys.each do |key|
          if filtered_data.key?(key)
            filtered_data[key] = '[FILTERED]'
          end
        end

        # ネストされたハッシュも処理
        filtered_data.each do |key, value|
          if value.is_a?(Hash)
            filtered_data[key] = filter(value)
          end
        end

        filtered_data
      end
    end

    # IPアドレスフィルター
    class IpAddressFilter
      def filter(data)
        return data unless data.is_a?(Hash)

        # データをコピー
        filtered_data = data.dup

        # IPアドレスをフィルタリング
        if filtered_data.key?(:ip) || filtered_data.key?('ip')
          key = filtered_data.key?(:ip) ? :ip : 'ip'
          ip = filtered_data[key]
          filtered_data[key] = anonymize_ip(ip)
        end

        # リクエスト情報内のIPアドレスもフィルタリング
        if filtered_data.key?(:request) && filtered_data[:request].is_a?(Hash)
          if filtered_data[:request].key?(:ip) || filtered_data[:request].key?('ip')
            key = filtered_data[:request].key?(:ip) ? :ip : 'ip'
            ip = filtered_data[:request][key]
            filtered_data[:request][key] = anonymize_ip(ip)
          end
        end

        filtered_data
      end

      private

      # IPアドレスを匿名化
      def anonymize_ip(ip)
        return ip unless ip.is_a?(String)

        # IPv4アドレスの場合
        if ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
          parts = ip.split('.')
          "#{parts[0]}.#{parts[1]}.0.0"
        # IPv6アドレスの場合
        elsif ip =~ /^[0-9a-f:]+$/i
          parts = ip.split(':')
          "#{parts[0]}:#{parts[1]}:#{parts[2]}:#{parts[3]}:0:0:0:0"
        else
          ip
        end
      end
    end
  end
end
