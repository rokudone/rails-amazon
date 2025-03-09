module Metrics
  extend ActiveSupport::Concern

  included do
    # メトリクス関連の設定を定義するクラス変数
    class_attribute :metrics_options, default: {}

    # フィルターを設定
    around_action :collect_metrics, if: :metrics_enabled?
  end

  class_methods do
    # メトリクス設定を構成
    def configure_metrics(options = {})
      self.metrics_options = {
        enabled: true,
        collect_performance: true,
        collect_business: true,
        collect_errors: true,
        only: nil,
        except: [],
        custom_metrics: {},
        metrics_collector: nil
      }.merge(options)
    end

    # メトリクスを収集するアクションを設定
    def collect_metrics_only(*actions, **options)
      self.metrics_options[:only] = actions
      self.metrics_options.merge!(options)
    end

    # メトリクスを収集しないアクションを設定
    def skip_metrics(*actions)
      self.metrics_options[:except] = actions
    end

    # カスタムメトリクスを定義
    def custom_metric(name, collector)
      self.metrics_options[:custom_metrics][name.to_sym] = collector
    end
  end

  # メトリクスを収集
  def collect_metrics
    # 開始時間を記録
    start_time = Time.current

    # メモリ使用量を記録
    start_memory = memory_usage

    # パフォーマンスメトリクスを初期化
    @performance_metrics = {
      controller: controller_name,
      action: action_name,
      start_time: start_time,
      duration: nil,
      view_runtime: nil,
      db_runtime: nil,
      memory_usage: nil,
      memory_delta: nil
    }

    # ビジネスメトリクスを初期化
    @business_metrics = {
      controller: controller_name,
      action: action_name,
      user_id: respond_to?(:current_user) && current_user ? current_user.id : nil,
      remote_ip: request.remote_ip,
      user_agent: request.user_agent,
      path: request.fullpath,
      method: request.method,
      format: request.format.to_s,
      status: nil
    }

    # アクションを実行
    yield

    # 終了時間を記録
    end_time = Time.current

    # メモリ使用量を記録
    end_memory = memory_usage

    # パフォーマンスメトリクスを更新
    @performance_metrics.merge!(
      end_time: end_time,
      duration: (end_time - start_time) * 1000, # ミリ秒単位
      view_runtime: view_runtime,
      db_runtime: db_runtime,
      memory_usage: end_memory,
      memory_delta: end_memory - start_memory
    )

    # ビジネスメトリクスを更新
    @business_metrics.merge!(
      status: response.status
    )

    # メトリクスを記録
    record_metrics
  rescue => e
    # エラーメトリクスを記録
    record_error_metrics(e)

    # エラーを再発生
    raise
  end

  # メトリクスを記録
  def record_metrics
    # パフォーマンスメトリクスを記録
    if metrics_options[:collect_performance]
      record_performance_metrics
    end

    # ビジネスメトリクスを記録
    if metrics_options[:collect_business]
      record_business_metrics
    end

    # カスタムメトリクスを記録
    record_custom_metrics
  end

  # パフォーマンスメトリクスを記録
  def record_performance_metrics
    # メトリクスコレクターが設定されている場合
    if metrics_collector.present?
      metrics_collector.record_performance_metrics(@performance_metrics)
    else
      # デフォルトの記録方法
      log_metrics('Performance', @performance_metrics)
    end
  end

  # ビジネスメトリクスを記録
  def record_business_metrics
    # メトリクスコレクターが設定されている場合
    if metrics_collector.present?
      metrics_collector.record_business_metrics(@business_metrics)
    else
      # デフォルトの記録方法
      log_metrics('Business', @business_metrics)
    end
  end

  # エラーメトリクスを記録
  def record_error_metrics(exception)
    # エラーメトリクスの収集が無効な場合
    return unless metrics_options[:collect_errors]

    # エラーメトリクスを構築
    error_metrics = {
      controller: controller_name,
      action: action_name,
      error: exception.class.name,
      message: exception.message,
      backtrace: exception.backtrace&.first(10),
      user_id: respond_to?(:current_user) && current_user ? current_user.id : nil,
      remote_ip: request.remote_ip,
      path: request.fullpath,
      method: request.method,
      timestamp: Time.current
    }

    # メトリクスコレクターが設定されている場合
    if metrics_collector.present?
      metrics_collector.record_error_metrics(error_metrics)
    else
      # デフォルトの記録方法
      log_metrics('Error', error_metrics, :error)
    end
  end

  # カスタムメトリクスを記録
  def record_custom_metrics
    # カスタムメトリクスが設定されていない場合
    return if metrics_options[:custom_metrics].empty?

    # 各カスタムメトリクスを処理
    metrics_options[:custom_metrics].each do |name, collector|
      # コレクターがProcの場合
      if collector.is_a?(Proc)
        metric_data = collector.call(self)
      # コレクターがシンボルまたは文字列の場合
      elsif collector.is_a?(Symbol) || collector.is_a?(String)
        metric_data = send(collector)
      else
        next
      end

      # メトリクスコレクターが設定されている場合
      if metrics_collector.present?
        metrics_collector.record_custom_metrics(name, metric_data)
      else
        # デフォルトの記録方法
        log_metrics("Custom:#{name}", metric_data)
      end
    end
  end

  # メトリクスをログに記録
  def log_metrics(type, data, level = :info)
    # ログメッセージを生成
    message = "#{type} Metrics: #{data.to_json}"

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

  # メトリクスコレクターを取得
  def metrics_collector
    # メトリクスコレクターが設定されている場合
    if metrics_options[:metrics_collector].present?
      collector = metrics_options[:metrics_collector]

      # コレクターがProcの場合
      if collector.is_a?(Proc)
        collector.call
      # コレクターがシンボルまたは文字列の場合
      elsif collector.is_a?(Symbol) || collector.is_a?(String)
        send(collector)
      # コレクターがクラスの場合
      else
        collector
      end
    # MetricsCollectorが定義されている場合
    elsif defined?(MetricsCollector)
      MetricsCollector
    else
      nil
    end
  end

  # ビュー実行時間を取得
  def view_runtime
    # ビュー実行時間が記録されている場合
    if defined?(@view_runtime)
      @view_runtime
    else
      nil
    end
  end

  # DB実行時間を取得
  def db_runtime
    # DB実行時間が記録されている場合
    if defined?(@db_runtime)
      @db_runtime
    else
      nil
    end
  end

  # メモリ使用量を取得
  def memory_usage
    # Linuxの場合
    if File.exist?('/proc/self/status')
      mem = File.read('/proc/self/status').match(/VmRSS:\s+(\d+)\s+kB/)
      return mem[1].to_i if mem
    end

    # その他の場合
    0
  rescue
    0
  end

  # メトリクスが有効かどうかをチェック
  def metrics_enabled?
    # メトリクスが無効な場合
    return false unless metrics_options[:enabled]

    # 特定のアクションのみメトリクスを収集する場合
    if metrics_options[:only].present?
      return false unless metrics_options[:only].include?(action_name.to_sym)
    end

    # 特定のアクションにメトリクスを収集しない場合
    if metrics_options[:except].present?
      return false if metrics_options[:except].include?(action_name.to_sym)
    end

    true
  end
end
