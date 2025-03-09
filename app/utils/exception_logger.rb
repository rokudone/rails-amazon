module ExceptionLogger
  class << self
    # 例外をログに記録
    def log(exception, error_info = nil, context = {})
      # エラー情報がない場合は生成
      error_info ||= classify_error(exception)

      # ログエントリを作成
      log_entry = create_log_entry(exception, error_info, context)

      # ログに記録
      write_to_log(log_entry, error_info[:severity])

      # 通知が必要な場合は通知
      notify_if_needed(log_entry, error_info)

      log_entry
    end

    # エラーを分類
    def classify_error(exception)
      ErrorHandler.classify_error(exception)
    end

    # ログエントリを作成
    def create_log_entry(exception, error_info, context)
      {
        timestamp: Time.current,
        error_type: exception.class.name,
        error_message: exception.message,
        error_code: error_info[:code],
        severity: error_info[:severity],
        status_code: error_info[:status],
        backtrace: format_backtrace(exception),
        context: sanitize_context(context),
        environment: Rails.env,
        request_info: extract_request_info(context),
        user_info: extract_user_info(context)
      }
    end

    # ログに書き込み
    def write_to_log(log_entry, severity = :error)
      # ログレベルを決定
      level = case severity
              when :warning
                :warn
              when :error
                :error
              when :fatal
                :fatal
              else
                :error
              end

      # ログメッセージを整形
      message = format_log_message(log_entry)

      # Railsロガーに記録
      Rails.logger.send(level, message)

      # 専用のエラーログファイルにも記録
      write_to_error_log(log_entry)

      # データベースにも記録
      write_to_database(log_entry) if should_log_to_database?(log_entry)
    end

    # 通知が必要かどうかを判断し、必要なら通知
    def notify_if_needed(log_entry, error_info)
      # 重大なエラーの場合のみ通知
      return unless [:error, :fatal].include?(error_info[:severity])

      # 通知頻度を制限（同じエラーが短時間に複数回発生した場合）
      return if throttle_notification?(log_entry)

      # 通知を送信
      send_notification(log_entry)
    end

    private

    # バックトレースを整形
    def format_backtrace(exception)
      return [] unless exception.backtrace

      # アプリケーションコードに関連する行のみ抽出
      app_backtrace = exception.backtrace.select { |line| line.include?(Rails.root.to_s) }

      # 行数を制限
      app_backtrace = app_backtrace.first(20) if app_backtrace.length > 20

      # バックトレースが空の場合は元のバックトレースの一部を使用
      if app_backtrace.empty?
        exception.backtrace.first(20)
      else
        app_backtrace
      end
    end

    # コンテキストを整形（機密情報を削除）
    def sanitize_context(context)
      return {} unless context.is_a?(Hash)

      # 機密情報をフィルタリング
      filtered_context = context.dup

      # パスワードなどの機密情報をフィルタリング
      %w[password password_confirmation credit_card token secret key].each do |key|
        if filtered_context.key?(key)
          filtered_context[key] = '[FILTERED]'
        end
      end

      # パラメータ内の機密情報もフィルタリング
      if filtered_context[:params].is_a?(Hash)
        %w[password password_confirmation credit_card token secret key].each do |key|
          if filtered_context[:params].key?(key)
            filtered_context[:params][key] = '[FILTERED]'
          end
        end
      end

      filtered_context
    end

    # リクエスト情報を抽出
    def extract_request_info(context)
      return {} unless context[:request].is_a?(ActionDispatch::Request)

      request = context[:request]

      {
        url: request.url,
        method: request.method,
        ip: request.ip,
        user_agent: request.user_agent,
        referer: request.referer,
        format: request.format.to_s,
        parameters: sanitize_parameters(request.parameters)
      }
    rescue => e
      { error: "Failed to extract request info: #{e.message}" }
    end

    # ユーザー情報を抽出
    def extract_user_info(context)
      return {} unless context[:current_user].present?

      user = context[:current_user]

      {
        id: user.id,
        email: user.email,
        name: "#{user.first_name} #{user.last_name}".strip
      }
    rescue => e
      { error: "Failed to extract user info: #{e.message}" }
    end

    # パラメータを整形（機密情報を削除）
    def sanitize_parameters(parameters)
      return {} unless parameters.is_a?(Hash)

      # パラメータをコピー
      filtered_params = parameters.dup

      # ActionController::Parametersの場合はハッシュに変換
      filtered_params = filtered_params.to_unsafe_h if filtered_params.respond_to?(:to_unsafe_h)

      # 機密情報をフィルタリング
      %w[password password_confirmation credit_card token secret key].each do |key|
        if filtered_params.key?(key)
          filtered_params[key] = '[FILTERED]'
        end
      end

      filtered_params
    end

    # ログメッセージを整形
    def format_log_message(log_entry)
      message = "[#{log_entry[:severity].to_s.upcase}] #{log_entry[:error_type]}: #{log_entry[:error_message]}"

      # リクエスト情報がある場合は追加
      if log_entry[:request_info].present? && log_entry[:request_info][:url].present?
        message += " (#{log_entry[:request_info][:method]} #{log_entry[:request_info][:url]})"
      end

      # ユーザー情報がある場合は追加
      if log_entry[:user_info].present? && log_entry[:user_info][:id].present?
        message += " [User: #{log_entry[:user_info][:id]}]"
      end

      # バックトレースを追加
      if log_entry[:backtrace].present?
        message += "\nBacktrace:\n  #{log_entry[:backtrace].join("\n  ")}"
      end

      message
    end

    # エラーログファイルに書き込み
    def write_to_error_log(log_entry)
      # エラーログファイルのパスを取得
      log_file = Rails.root.join('log', "error_#{Rails.env}.log")

      # ログエントリをJSON形式に変換
      json_entry = log_entry.to_json

      # ファイルに書き込み
      File.open(log_file, 'a') do |file|
        file.puts(json_entry)
      end
    rescue => e
      Rails.logger.error("Failed to write to error log: #{e.message}")
    end

    # データベースに書き込み
    def write_to_database(log_entry)
      # EventLogモデルが定義されている場合のみ実行
      return unless defined?(EventLog)

      # イベントログを作成
      EventLog.create(
        event_type: 'error',
        severity: log_entry[:severity].to_s,
        message: log_entry[:error_message],
        details: {
          error_type: log_entry[:error_type],
          error_code: log_entry[:error_code],
          backtrace: log_entry[:backtrace],
          context: log_entry[:context],
          request_info: log_entry[:request_info],
          user_info: log_entry[:user_info]
        }
      )
    rescue => e
      Rails.logger.error("Failed to write error to database: #{e.message}")
    end

    # データベースに記録すべきかどうかを判断
    def should_log_to_database?(log_entry)
      # 開発環境では記録しない
      return false if Rails.env.development?

      # 重大なエラーのみ記録
      [:error, :fatal].include?(log_entry[:severity])
    end

    # 通知頻度を制限
    def throttle_notification?(log_entry)
      # キャッシュキーを生成
      cache_key = "error_notification:#{log_entry[:error_type]}:#{log_entry[:error_code]}"

      # キャッシュをチェック
      if Rails.cache.exist?(cache_key)
        # 既に通知済みの場合はスロットリング
        true
      else
        # キャッシュに保存（5分間）
        Rails.cache.write(cache_key, true, expires_in: 5.minutes)
        false
      end
    end

    # 通知を送信
    def send_notification(log_entry)
      # 実際のアプリケーションでは、Slack、メール、SMSなどに通知
      # ここではシミュレーションのみ
      Rails.logger.info("Error notification would be sent: #{log_entry[:error_type]} - #{log_entry[:error_message]}")
    end
  end
end
