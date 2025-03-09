module Logging
  extend ActiveSupport::Concern

  included do
    # ログ関連の設定を定義するクラス変数
    class_attribute :logging_options, default: {}

    # フィルターを設定
    around_action :log_request, if: :logging_enabled?
    after_action :log_response, if: :logging_enabled?
  end

  class_methods do
    # ログ設定を構成
    def configure_logging(options = {})
      self.logging_options = {
        enabled: true,
        log_request: true,
        log_response: true,
        log_params: true,
        log_headers: false,
        log_body: false,
        log_format: :json,
        log_level: :info,
        exclude_params: %w[password password_confirmation token credit_card_number],
        exclude_headers: %w[Authorization Cookie],
        only: nil,
        except: [],
        custom_logger: nil
      }.merge(options)
    end

    # ログを記録するアクションを設定
    def log_only(*actions, **options)
      self.logging_options[:only] = actions
      self.logging_options.merge!(options)
    end

    # ログを記録しないアクションを設定
    def skip_logging(*actions)
      self.logging_options[:except] = actions
    end
  end

  # リクエストをログに記録
  def log_request
    # 開始時間を記録
    start_time = Time.current

    # リクエスト情報を取得
    request_info = {
      controller: controller_name,
      action: action_name,
      method: request.method,
      path: request.fullpath,
      format: request.format.to_s,
      remote_ip: request.remote_ip,
      user_agent: request.user_agent
    }

    # パラメータをログに記録
    if logging_options[:log_params]
      # パラメータをフィルタリング
      filtered_params = filter_sensitive_params(params.to_unsafe_h)
      request_info[:params] = filtered_params
    end

    # ヘッダーをログに記録
    if logging_options[:log_headers]
      # ヘッダーをフィルタリング
      filtered_headers = filter_sensitive_headers(request.headers)
      request_info[:headers] = filtered_headers
    end

    # ボディをログに記録
    if logging_options[:log_body] && request.body.present?
      request_info[:body] = request.body.read
      request.body.rewind
    end

    # ユーザー情報をログに記録
    if respond_to?(:current_user) && current_user
      request_info[:user_id] = current_user.id
    end

    # リクエスト情報をログに記録
    log_message('Request', request_info)

    # アクションを実行
    yield

    # 終了時間を記録
    @request_duration = Time.current - start_time
  rescue => e
    # エラー情報をログに記録
    log_error(e)

    # エラーを再発生
    raise
  end

  # レスポンスをログに記録
  def log_response
    # レスポンス情報を取得
    response_info = {
      controller: controller_name,
      action: action_name,
      status: response.status,
      duration: @request_duration,
      content_type: response.content_type
    }

    # ヘッダーをログに記録
    if logging_options[:log_headers]
      # ヘッダーをフィルタリング
      filtered_headers = filter_sensitive_headers(response.headers)
      response_info[:headers] = filtered_headers
    end

    # ボディをログに記録
    if logging_options[:log_body] && response.body.present?
      response_info[:body] = response.body
    end

    # レスポンス情報をログに記録
    log_message('Response', response_info)
  end

  # エラーをログに記録
  def log_error(exception)
    # エラー情報を取得
    error_info = {
      controller: controller_name,
      action: action_name,
      error: exception.class.name,
      message: exception.message,
      backtrace: exception.backtrace&.first(10)
    }

    # エラー情報をログに記録
    log_message('Error', error_info, :error)
  end

  # メッセージをログに記録
  def log_message(type, data, level = nil)
    # ログレベルを取得
    level ||= logging_options[:log_level]

    # カスタムロガーが設定されている場合
    if logging_options[:custom_logger].present?
      # カスタムロガーを取得
      logger = logging_options[:custom_logger]

      # カスタムロガーがProcの場合
      if logger.is_a?(Proc)
        logger.call(type, data, level)
        return
      # カスタムロガーがシンボルまたは文字列の場合
      elsif logger.is_a?(Symbol) || logger.is_a?(String)
        if respond_to?(logger)
          send(logger, type, data, level)
          return
        end
      end
    end

    # ログフォーマットを取得
    format = logging_options[:log_format]

    # ログメッセージを生成
    message = case format
              when :json
                "#{type}: #{data.to_json}"
              when :pretty_json
                "#{type}:\n#{JSON.pretty_generate(data)}"
              when :yaml
                "#{type}:\n#{data.to_yaml}"
              else
                "#{type}: #{data.inspect}"
              end

    # ログに記録
    case level.to_sym
    when :debug
      Rails.logger.debug(message)
    when :info
      Rails.logger.info(message)
    when :warn
      Rails.logger.warn(message)
    when :error
      Rails.logger.error(message)
    when :fatal
      Rails.logger.fatal(message)
    else
      Rails.logger.info(message)
    end
  end

  # 機密パラメータをフィルタリング
  def filter_sensitive_params(params)
    # パラメータをコピー
    filtered = params.deep_dup

    # 除外パラメータを取得
    exclude_params = logging_options[:exclude_params]

    # 除外パラメータをフィルタリング
    exclude_params.each do |param|
      filter_param_recursive(filtered, param)
    end

    filtered
  end

  # パラメータを再帰的にフィルタリング
  def filter_param_recursive(params, param)
    # パラメータがハッシュの場合
    if params.is_a?(Hash)
      # パラメータをフィルタリング
      if params.key?(param)
        params[param] = '[FILTERED]'
      end

      # 子パラメータを再帰的にフィルタリング
      params.each do |key, value|
        if value.is_a?(Hash) || value.is_a?(Array)
          filter_param_recursive(value, param)
        end
      end
    # パラメータが配列の場合
    elsif params.is_a?(Array)
      # 各要素を再帰的にフィルタリング
      params.each do |value|
        if value.is_a?(Hash) || value.is_a?(Array)
          filter_param_recursive(value, param)
        end
      end
    end
  end

  # 機密ヘッダーをフィルタリング
  def filter_sensitive_headers(headers)
    # ヘッダーをハッシュに変換
    headers_hash = headers.to_h

    # 除外ヘッダーを取得
    exclude_headers = logging_options[:exclude_headers]

    # 除外ヘッダーをフィルタリング
    exclude_headers.each do |header|
      # ヘッダー名を正規化
      normalized_header = header.to_s.downcase.gsub('-', '_')

      # ヘッダーをフィルタリング
      headers_hash.each do |key, value|
        if key.to_s.downcase.gsub('-', '_') == normalized_header
          headers_hash[key] = '[FILTERED]'
        end
      end
    end

    headers_hash
  end

  # ログが有効かどうかをチェック
  def logging_enabled?
    # ログが無効な場合
    return false unless logging_options[:enabled]

    # 特定のアクションのみログを記録する場合
    if logging_options[:only].present?
      return false unless logging_options[:only].include?(action_name.to_sym)
    end

    # 特定のアクションにログを記録しない場合
    if logging_options[:except].present?
      return false if logging_options[:except].include?(action_name.to_sym)
    end

    true
  end
end
