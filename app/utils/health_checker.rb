module HealthChecker
  class << self
    # システム全体の健全性をチェック
    def check_health
      # 各コンポーネントの健全性をチェック
      results = {
        database: check_database,
        cache: check_cache,
        storage: check_storage,
        external_services: check_external_services,
        background_jobs: check_background_jobs,
        memory: check_memory,
        cpu: check_cpu,
        disk: check_disk
      }

      # 全体の健全性を判定
      overall_status = results.values.all? { |r| r[:status] == 'ok' } ? 'ok' : 'error'

      # 結果を返す
      {
        status: overall_status,
        timestamp: Time.current,
        components: results
      }
    end

    # データベースの健全性をチェック
    def check_database
      begin
        # データベース接続をチェック
        ActiveRecord::Base.connection.execute('SELECT 1')

        # データベースの統計情報を取得
        stats = database_stats

        # 結果を返す
        {
          status: 'ok',
          message: 'Database is operational',
          stats: stats
        }
      rescue => e
        # エラーが発生した場合
        {
          status: 'error',
          message: "Database error: #{e.message}",
          error: e.class.name
        }
      end
    end

    # キャッシュの健全性をチェック
    def check_cache
      begin
        # キャッシュ接続をチェック
        test_key = "health_check_#{SecureRandom.hex(8)}"
        test_value = SecureRandom.hex(8)

        # キャッシュに値を書き込み
        Rails.cache.write(test_key, test_value, expires_in: 1.minute)

        # キャッシュから値を読み込み
        cached_value = Rails.cache.read(test_key)

        # キャッシュから値を削除
        Rails.cache.delete(test_key)

        # 値が一致するかチェック
        if cached_value == test_value
          # キャッシュの統計情報を取得
          stats = cache_stats

          # 結果を返す
          {
            status: 'ok',
            message: 'Cache is operational',
            stats: stats
          }
        else
          # 値が一致しない場合
          {
            status: 'error',
            message: 'Cache read/write test failed'
          }
        end
      rescue => e
        # エラーが発生した場合
        {
          status: 'error',
          message: "Cache error: #{e.message}",
          error: e.class.name
        }
      end
    end

    # ストレージの健全性をチェック
    def check_storage
      begin
        # ストレージ接続をチェック
        if defined?(ActiveStorage::Blob)
          # Active Storageが利用可能な場合

          # ストレージの統計情報を取得
          stats = storage_stats

          # 結果を返す
          {
            status: 'ok',
            message: 'Storage is operational',
            stats: stats
          }
        else
          # Active Storageが利用できない場合
          {
            status: 'unknown',
            message: 'Active Storage is not available'
          }
        end
      rescue => e
        # エラーが発生した場合
        {
          status: 'error',
          message: "Storage error: #{e.message}",
          error: e.class.name
        }
      end
    end

    # 外部サービスの健全性をチェック
    def check_external_services
      # 外部サービスのリスト
      services = external_services

      # 各サービスの健全性をチェック
      results = {}
      services.each do |service_name, service_config|
        results[service_name] = check_external_service(service_name, service_config)
      end

      # 全体の健全性を判定
      overall_status = results.values.all? { |r| r[:status] == 'ok' } ? 'ok' : 'error'

      # 結果を返す
      {
        status: overall_status,
        message: overall_status == 'ok' ? 'All external services are operational' : 'Some external services are not operational',
        services: results
      }
    end

    # バックグラウンドジョブの健全性をチェック
    def check_background_jobs
      begin
        # バックグラウンドジョブの統計情報を取得
        stats = background_job_stats

        # 結果を返す
        {
          status: 'ok',
          message: 'Background jobs are operational',
          stats: stats
        }
      rescue => e
        # エラーが発生した場合
        {
          status: 'error',
          message: "Background job error: #{e.message}",
          error: e.class.name
        }
      end
    end

    # メモリ使用量をチェック
    def check_memory
      begin
        # メモリ使用量を取得
        memory_usage = get_memory_usage

        # メモリ使用量が閾値を超えているかチェック
        if memory_usage[:used_percent] < 90
          # 正常な場合
          {
            status: 'ok',
            message: 'Memory usage is normal',
            stats: memory_usage
          }
        else
          # 異常な場合
          {
            status: 'warning',
            message: 'Memory usage is high',
            stats: memory_usage
          }
        end
      rescue => e
        # エラーが発生した場合
        {
          status: 'unknown',
          message: "Memory check error: #{e.message}",
          error: e.class.name
        }
      end
    end

    # CPU使用率をチェック
    def check_cpu
      begin
        # CPU使用率を取得
        cpu_usage = get_cpu_usage

        # CPU使用率が閾値を超えているかチェック
        if cpu_usage[:used_percent] < 90
          # 正常な場合
          {
            status: 'ok',
            message: 'CPU usage is normal',
            stats: cpu_usage
          }
        else
          # 異常な場合
          {
            status: 'warning',
            message: 'CPU usage is high',
            stats: cpu_usage
          }
        end
      rescue => e
        # エラーが発生した場合
        {
          status: 'unknown',
          message: "CPU check error: #{e.message}",
          error: e.class.name
        }
      end
    end

    # ディスク使用量をチェック
    def check_disk
      begin
        # ディスク使用量を取得
        disk_usage = get_disk_usage

        # ディスク使用量が閾値を超えているかチェック
        if disk_usage[:used_percent] < 90
          # 正常な場合
          {
            status: 'ok',
            message: 'Disk usage is normal',
            stats: disk_usage
          }
        else
          # 異常な場合
          {
            status: 'warning',
            message: 'Disk usage is high',
            stats: disk_usage
          }
        end
      rescue => e
        # エラーが発生した場合
        {
          status: 'unknown',
          message: "Disk check error: #{e.message}",
          error: e.class.name
        }
      end
    end

    # 健全性レポートを生成
    def generate_report
      # システム全体の健全性をチェック
      health = check_health

      # レポートを生成
      {
        application: Rails.application.class.name.split('::').first,
        environment: Rails.env,
        version: Rails.application.config.version,
        ruby_version: RUBY_VERSION,
        rails_version: Rails.version,
        database_adapter: ActiveRecord::Base.connection.adapter_name,
        timestamp: Time.current,
        health: health
      }
    end

    # 健全性レポートをJSONで出力
    def report_as_json
      JSON.pretty_generate(generate_report)
    end

    # 健全性レポートをHTMLで出力
    def report_as_html
      report = generate_report

      # HTMLを生成
      html = <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>Health Check Report</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            h1 { color: #333; }
            .status-ok { color: green; }
            .status-warning { color: orange; }
            .status-error { color: red; }
            .status-unknown { color: gray; }
            table { border-collapse: collapse; width: 100%; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background-color: #f2f2f2; }
          </style>
        </head>
        <body>
          <h1>Health Check Report</h1>
          <p><strong>Application:</strong> #{report[:application]}</p>
          <p><strong>Environment:</strong> #{report[:environment]}</p>
          <p><strong>Version:</strong> #{report[:version]}</p>
          <p><strong>Ruby Version:</strong> #{report[:ruby_version]}</p>
          <p><strong>Rails Version:</strong> #{report[:rails_version]}</p>
          <p><strong>Database Adapter:</strong> #{report[:database_adapter]}</p>
          <p><strong>Timestamp:</strong> #{report[:timestamp]}</p>
          <h2>Health Status: <span class="status-#{report[:health][:status]}">#{report[:health][:status].upcase}</span></h2>
          <h3>Components</h3>
          <table>
            <tr>
              <th>Component</th>
              <th>Status</th>
              <th>Message</th>
            </tr>
      HTML

      # コンポーネントの健全性を追加
      report[:health][:components].each do |component, result|
        html += <<-HTML
            <tr>
              <td>#{component}</td>
              <td class="status-#{result[:status]}">#{result[:status].upcase}</td>
              <td>#{result[:message]}</td>
            </tr>
        HTML
      end

      # HTMLを閉じる
      html += <<-HTML
          </table>
        </body>
        </html>
      HTML

      html
    end

    private

    # 外部サービスの健全性をチェック
    def check_external_service(service_name, service_config)
      begin
        # サービスのエンドポイントをチェック
        if service_config[:url]
          # HTTPリクエストを送信
          response = http_client.get(service_config[:url])

          # レスポンスをチェック
          if response.success?
            # 正常な場合
            {
              status: 'ok',
              message: "#{service_name} is operational",
              response_time: response.time
            }
          else
            # 異常な場合
            {
              status: 'error',
              message: "#{service_name} returned status code #{response.code}",
              response_time: response.time
            }
          end
        else
          # URLが指定されていない場合
          {
            status: 'unknown',
            message: "No URL configured for #{service_name}"
          }
        end
      rescue => e
        # エラーが発生した場合
        {
          status: 'error',
          message: "#{service_name} error: #{e.message}",
          error: e.class.name
        }
      end
    end

    # データベースの統計情報を取得
    def database_stats
      # データベースアダプタに応じて統計情報を取得
      case ActiveRecord::Base.connection.adapter_name.downcase
      when 'mysql', 'mysql2'
        # MySQLの統計情報を取得
        {
          version: ActiveRecord::Base.connection.select_value('SELECT VERSION()'),
          uptime: ActiveRecord::Base.connection.select_value('SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = "Uptime"'),
          connections: ActiveRecord::Base.connection.select_value('SELECT COUNT(*) FROM information_schema.PROCESSLIST'),
          max_connections: ActiveRecord::Base.connection.select_value('SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_VARIABLES WHERE VARIABLE_NAME = "max_connections"')
        }
      when 'postgresql'
        # PostgreSQLの統計情報を取得
        {
          version: ActiveRecord::Base.connection.select_value('SELECT VERSION()'),
          connections: ActiveRecord::Base.connection.select_value('SELECT COUNT(*) FROM pg_stat_activity'),
          max_connections: ActiveRecord::Base.connection.select_value('SHOW max_connections')
        }
      when 'sqlite'
        # SQLiteの統計情報を取得
        {
          version: ActiveRecord::Base.connection.select_value('SELECT sqlite_version()')
        }
      else
        # その他のデータベースの場合
        {}
      end
    end

    # キャッシュの統計情報を取得
    def cache_stats
      # キャッシュストアに応じて統計情報を取得
      cache_store = Rails.cache.instance_variable_get(:@data)

      if cache_store.respond_to?(:stats)
        # Memcachedの場合
        cache_store.stats
      elsif defined?(Redis) && cache_store.is_a?(Redis)
        # Redisの場合
        cache_store.info
      else
        # その他のキャッシュストアの場合
        {}
      end
    rescue
      {}
    end

    # ストレージの統計情報を取得
    def storage_stats
      if defined?(ActiveStorage::Blob)
        # Active Storageの統計情報を取得
        {
          total_blobs: ActiveStorage::Blob.count,
          total_size: ActiveStorage::Blob.sum(:byte_size)
        }
      else
        {}
      end
    rescue
      {}
    end

    # バックグラウンドジョブの統計情報を取得
    def background_job_stats
      if defined?(Sidekiq::Stats)
        # Sidekiqの統計情報を取得
        stats = Sidekiq::Stats.new
        {
          processed: stats.processed,
          failed: stats.failed,
          enqueued: stats.enqueued,
          queues: stats.queues
        }
      elsif defined?(Delayed::Job)
        # Delayed Jobの統計情報を取得
        {
          total: Delayed::Job.count,
          pending: Delayed::Job.where(locked_at: nil).count,
          failed: Delayed::Job.where.not(failed_at: nil).count
        }
      elsif defined?(Resque)
        # Resqueの統計情報を取得
        {
          pending: Resque.size(:default),
          processed: Resque.info[:processed],
          failed: Resque.info[:failed],
          queues: Resque.queues.size
        }
      else
        {}
      end
    rescue
      {}
    end

    # メモリ使用量を取得
    def get_memory_usage
      if RUBY_PLATFORM =~ /linux/
        # Linuxの場合
        mem_info = File.read('/proc/meminfo')
        total = mem_info.match(/MemTotal:\s+(\d+)/)[1].to_i
        free = mem_info.match(/MemFree:\s+(\d+)/)[1].to_i
        available = mem_info.match(/MemAvailable:\s+(\d+)/)[1].to_i

        used = total - available
        used_percent = (used.to_f / total) * 100

        {
          total: total,
          used: used,
          free: free,
          available: available,
          used_percent: used_percent.round(2)
        }
      elsif RUBY_PLATFORM =~ /darwin/
        # macOSの場合
        mem_info = `vm_stat`
        page_size = mem_info.match(/page size of (\d+) bytes/)[1].to_i
        free = mem_info.match(/Pages free:\s+(\d+)/)[1].to_i * page_size
        active = mem_info.match(/Pages active:\s+(\d+)/)[1].to_i * page_size
        inactive = mem_info.match(/Pages inactive:\s+(\d+)/)[1].to_i * page_size
        wired = mem_info.match(/Pages wired down:\s+(\d+)/)[1].to_i * page_size

        total = active + inactive + free + wired
        used = active + wired
        used_percent = (used.to_f / total) * 100

        {
          total: total,
          used: used,
          free: free,
          used_percent: used_percent.round(2)
        }
      else
        # その他のプラットフォームの場合
        {
          total: 0,
          used: 0,
          free: 0,
          used_percent: 0
        }
      end
    rescue
      {
        total: 0,
        used: 0,
        free: 0,
        used_percent: 0
      }
    end

    # CPU使用率を取得
    def get_cpu_usage
      if RUBY_PLATFORM =~ /linux/
        # Linuxの場合
        cpu_info = File.read('/proc/stat')
        cpu = cpu_info.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)

        user = cpu[1].to_i
        nice = cpu[2].to_i
        system = cpu[3].to_i
        idle = cpu[4].to_i

        total = user + nice + system + idle
        used = user + nice + system
        used_percent = (used.to_f / total) * 100

        {
          total: total,
          used: used,
          idle: idle,
          used_percent: used_percent.round(2)
        }
      elsif RUBY_PLATFORM =~ /darwin/
        # macOSの場合
        cpu_info = `top -l 1 | grep "CPU usage"`
        user = cpu_info.match(/(\d+\.\d+)% user/)[1].to_f
        system = cpu_info.match(/(\d+\.\d+)% sys/)[1].to_f
        idle = cpu_info.match(/(\d+\.\d+)% idle/)[1].to_f

        used_percent = user + system

        {
          user: user,
          system: system,
          idle: idle,
          used_percent: used_percent.round(2)
        }
      else
        # その他のプラットフォームの場合
        {
          used_percent: 0
        }
      end
    rescue
      {
        used_percent: 0
      }
    end

    # ディスク使用量を取得
    def get_disk_usage
      if RUBY_PLATFORM =~ /linux/ || RUBY_PLATFORM =~ /darwin/
        # LinuxまたはmacOSの場合
        df_output = `df -k #{Rails.root}`
        df_line = df_output.split("\n")[1]

        total = df_line.split[1].to_i * 1024
        used = df_line.split[2].to_i * 1024
        available = df_line.split[3].to_i * 1024
        used_percent = (used.to_f / total) * 100

        {
          total: total,
          used: used,
          available: available,
          used_percent: used_percent.round(2)
        }
      else
        # その他のプラットフォームの場合
        {
          total: 0,
          used: 0,
          available: 0,
          used_percent: 0
        }
      end
    rescue
      {
        total: 0,
        used: 0,
        available: 0,
        used_percent: 0
      }
    end

    # 外部サービスのリストを取得
    def external_services
      # 設定から外部サービスのリストを取得
      services = {}

      # 支払いゲートウェイ
      if defined?(Rails.application.config.payment_gateway_url)
        services[:payment_gateway] = {
          url: Rails.application.config.payment_gateway_url
        }
      end

      # 配送API
      if defined?(Rails.application.config.shipping_api_url)
        services[:shipping_api] = {
          url: Rails.application.config.shipping_api_url
        }
      end

      # メールサービス
      if defined?(Rails.application.config.email_service_url)
        services[:email_service] = {
          url: Rails.application.config.email_service_url
        }
      end

      # その他の外部サービス
      services
    end

    # HTTPクライアント
    def http_client
      # HTTPクライアントを作成
      @http_client ||= begin
        require 'faraday'
        Faraday.new do |faraday|
          faraday.adapter Faraday.default_adapter
          faraday.options.timeout = 5
          faraday.options.open_timeout = 2
        end
      end
    end
  end
end
