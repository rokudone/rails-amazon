module MetricsCollector
  class << self
    # メトリクスを記録
    def record(name, value, tags = {})
      # メトリクス名を正規化
      normalized_name = normalize_metric_name(name)

      # メトリクスを作成
      metric = create_metric(normalized_name, value, tags)

      # メトリクスを保存
      store_metric(metric)

      # メトリクスを発行
      publish_metric(metric)

      metric
    end

    # カウンターメトリクスをインクリメント
    def increment(name, value = 1, tags = {})
      # カウンターの現在値を取得
      current_value = get_counter_value(name, tags)

      # カウンターをインクリメント
      new_value = current_value + value

      # メトリクスを記録
      record(name, new_value, tags.merge(type: 'counter'))
    end

    # ゲージメトリクスを設定
    def gauge(name, value, tags = {})
      # メトリクスを記録
      record(name, value, tags.merge(type: 'gauge'))
    end

    # ヒストグラムメトリクスを記録
    def histogram(name, value, tags = {})
      # メトリクスを記録
      record(name, value, tags.merge(type: 'histogram'))
    end

    # タイマーメトリクスを記録
    def timer(name, tags = {})
      # 開始時間を記録
      start_time = Time.now

      # ブロックを実行
      result = yield

      # 終了時間を記録
      end_time = Time.now

      # 経過時間を計算（ミリ秒）
      elapsed_time = ((end_time - start_time) * 1000).to_i

      # メトリクスを記録
      record(name, elapsed_time, tags.merge(type: 'timer'))

      # ブロックの結果を返す
      result
    end

    # メトリクスを集計
    def aggregate(name, aggregation = :avg, time_range = 1.hour, tags = {})
      # メトリクス名を正規化
      normalized_name = normalize_metric_name(name)

      # 時間範囲内のメトリクスを取得
      metrics = get_metrics(normalized_name, time_range, tags)

      # メトリクスが存在しない場合はnilを返す
      return nil if metrics.empty?

      # メトリクス値を抽出
      values = metrics.map { |m| m[:value] }

      # 集計方法に応じて集計
      case aggregation
      when :avg
        values.sum / values.size.to_f
      when :sum
        values.sum
      when :min
        values.min
      when :max
        values.max
      when :count
        values.size
      when :p50
        percentile(values, 50)
      when :p90
        percentile(values, 90)
      when :p95
        percentile(values, 95)
      when :p99
        percentile(values, 99)
      else
        nil
      end
    end

    # メトリクスを取得
    def get_metrics(name, time_range = 1.hour, tags = {})
      # メトリクス名を正規化
      normalized_name = normalize_metric_name(name)

      # 時間範囲の開始時間を計算
      start_time = Time.now - time_range

      # メトリクスストアからメトリクスを取得
      metrics_store.select do |metric|
        metric[:name] == normalized_name &&
          metric[:timestamp] >= start_time &&
          tags_match?(metric[:tags], tags)
      end
    end

    # メトリクスをクリア
    def clear_metrics
      # メトリクスストアをクリア
      metrics_store.clear
    end

    # メトリクスをファイルに出力
    def export_to_file(file_path, format = :json)
      # 全てのメトリクスを取得
      metrics = metrics_store.dup

      # ファイル形式に応じて出力
      case format.to_sym
      when :json
        File.write(file_path, JSON.pretty_generate(metrics))
      when :csv
        CSV.open(file_path, 'w') do |csv|
          # ヘッダー行を出力
          csv << ['name', 'value', 'timestamp', 'tags']

          # メトリクス行を出力
          metrics.each do |metric|
            csv << [
              metric[:name],
              metric[:value],
              metric[:timestamp],
              metric[:tags].to_json
            ]
          end
        end
      else
        raise "Unsupported export format: #{format}"
      end
    end

    # メトリクスをPrometheusフォーマットで出力
    def to_prometheus
      # 全てのメトリクスを取得
      metrics = metrics_store.dup

      # Prometheusフォーマットに変換
      prometheus_metrics = []

      # メトリクスをグループ化
      grouped_metrics = metrics.group_by { |m| [m[:name], m[:tags][:type]] }

      # 各グループを処理
      grouped_metrics.each do |(name, type), group_metrics|
        # メトリクスタイプに応じてフォーマット
        case type
        when 'counter'
          # カウンターの場合は最新の値を使用
          latest_metric = group_metrics.max_by { |m| m[:timestamp] }
          prometheus_metrics << format_prometheus_metric(name, latest_metric[:value], latest_metric[:tags], 'counter')
        when 'gauge'
          # ゲージの場合は最新の値を使用
          latest_metric = group_metrics.max_by { |m| m[:timestamp] }
          prometheus_metrics << format_prometheus_metric(name, latest_metric[:value], latest_metric[:tags], 'gauge')
        when 'histogram'
          # ヒストグラムの場合は分位数を計算
          values = group_metrics.map { |m| m[:value] }

          # ヒストグラムのバケットを計算
          buckets = calculate_histogram_buckets(values)

          # バケットをフォーマット
          buckets.each do |bucket, count|
            prometheus_metrics << format_prometheus_metric("#{name}_bucket", count, latest_metric[:tags].merge(le: bucket), 'histogram')
          end

          # 合計と数を追加
          prometheus_metrics << format_prometheus_metric("#{name}_sum", values.sum, latest_metric[:tags], 'histogram')
          prometheus_metrics << format_prometheus_metric("#{name}_count", values.size, latest_metric[:tags], 'histogram')
        end
      end

      # Prometheusフォーマットの文字列を返す
      prometheus_metrics.join("\n")
    end

    # メトリクスをDatadogフォーマットで出力
    def to_datadog
      # 全てのメトリクスを取得
      metrics = metrics_store.dup

      # Datadogフォーマットに変換
      datadog_metrics = []

      # 各メトリクスを処理
      metrics.each do |metric|
        # メトリクスをフォーマット
        datadog_metrics << {
          metric: metric[:name],
          points: [[metric[:timestamp].to_i, metric[:value]]],
          type: metric[:tags][:type] || 'gauge',
          tags: format_datadog_tags(metric[:tags])
        }
      end

      # Datadogフォーマットの文字列を返す
      JSON.generate(series: datadog_metrics)
    end

    private

    # メトリクス名を正規化
    def normalize_metric_name(name)
      name.to_s.downcase.gsub(/[^a-z0-9_.]/, '_')
    end

    # メトリクスを作成
    def create_metric(name, value, tags)
      {
        name: name,
        value: value.to_f,
        tags: tags,
        timestamp: Time.now
      }
    end

    # メトリクスを保存
    def store_metric(metric)
      # メトリクスストアに追加
      metrics_store << metric

      # メトリクスストアが大きすぎる場合は古いメトリクスを削除
      while metrics_store.size > max_metrics_store_size
        metrics_store.shift
      end
    end

    # メトリクスを発行
    def publish_metric(metric)
      # イベントディスパッチャーが定義されている場合はイベントを発行
      if defined?(EventDispatcher)
        EventDispatcher.publish('metrics.recorded', metric)
      end
    end

    # カウンターの現在値を取得
    def get_counter_value(name, tags)
      # メトリクス名を正規化
      normalized_name = normalize_metric_name(name)

      # カウンターメトリクスを検索
      counter_metrics = metrics_store.select do |metric|
        metric[:name] == normalized_name &&
          tags_match?(metric[:tags], tags) &&
          metric[:tags][:type] == 'counter'
      end

      # カウンターメトリクスが存在しない場合は0を返す
      return 0 if counter_metrics.empty?

      # 最新のカウンターメトリクスの値を返す
      counter_metrics.max_by { |m| m[:timestamp] }[:value]
    end

    # タグが一致するかチェック
    def tags_match?(metric_tags, query_tags)
      # クエリタグが空の場合は常に一致
      return true if query_tags.empty?

      # クエリタグの各キーと値が一致するかチェック
      query_tags.all? do |key, value|
        metric_tags[key] == value
      end
    end

    # パーセンタイルを計算
    def percentile(values, percentile)
      # 値をソート
      sorted_values = values.sort

      # パーセンタイルのインデックスを計算
      index = (sorted_values.size * percentile / 100.0).ceil - 1

      # パーセンタイルの値を返す
      sorted_values[index]
    end

    # ヒストグラムのバケットを計算
    def calculate_histogram_buckets(values)
      # デフォルトのバケット境界
      bucket_boundaries = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]

      # バケットを初期化
      buckets = {}

      # 各バケット境界に対してカウントを計算
      bucket_boundaries.each do |boundary|
        buckets[boundary] = values.count { |v| v <= boundary }
      end

      # 無限大のバケットを追加
      buckets['+Inf'] = values.size

      buckets
    end

    # Prometheusフォーマットのメトリクスを生成
    def format_prometheus_metric(name, value, tags, type)
      # タグをPrometheusフォーマットに変換
      prometheus_tags = tags.map { |k, v| "#{k}=\"#{v}\"" }.join(',')

      # メトリクスをフォーマット
      if prometheus_tags.empty?
        "#{name} #{value}"
      else
        "#{name}{#{prometheus_tags}} #{value}"
      end
    end

    # Datadogフォーマットのタグを生成
    def format_datadog_tags(tags)
      # タグをDatadogフォーマットに変換
      tags.map { |k, v| "#{k}:#{v}" }
    end

    # メトリクスストア
    def metrics_store
      @metrics_store ||= []
    end

    # メトリクスストアの最大サイズ
    def max_metrics_store_size
      10000
    end
  end
end
