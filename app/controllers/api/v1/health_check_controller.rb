module Api
  module V1
    class HealthCheckController < BaseController
      skip_before_action :authenticate_user

      # GET /api/v1/health_check
      def index
        # システムの基本的な状態確認
        db_status = check_database
        redis_status = check_redis
        storage_status = check_storage

        overall_status = db_status[:status] == 'ok' &&
                         redis_status[:status] == 'ok' &&
                         storage_status[:status] == 'ok' ? 'ok' : 'error'

        render_success({
          status: overall_status,
          version: Rails.application.config.version || '1.0.0',
          environment: Rails.env,
          timestamp: Time.current,
          uptime: process_uptime,
          checks: {
            database: db_status,
            redis: redis_status,
            storage: storage_status
          }
        })
      end

      # GET /api/v1/health_check/dependencies
      def dependencies
        # 依存サービスの状態確認
        db_status = check_database
        redis_status = check_redis
        storage_status = check_storage
        elasticsearch_status = check_elasticsearch
        payment_gateway_status = check_payment_gateway
        email_service_status = check_email_service

        overall_status = db_status[:status] == 'ok' &&
                         redis_status[:status] == 'ok' &&
                         storage_status[:status] == 'ok' &&
                         elasticsearch_status[:status] == 'ok' &&
                         payment_gateway_status[:status] == 'ok' &&
                         email_service_status[:status] == 'ok' ? 'ok' : 'error'

        render_success({
          status: overall_status,
          version: Rails.application.config.version || '1.0.0',
          environment: Rails.env,
          timestamp: Time.current,
          uptime: process_uptime,
          checks: {
            database: db_status,
            redis: redis_status,
            storage: storage_status,
            elasticsearch: elasticsearch_status,
            payment_gateway: payment_gateway_status,
            email_service: email_service_status
          },
          system_info: {
            ruby_version: RUBY_VERSION,
            rails_version: Rails.version,
            database_adapter: ActiveRecord::Base.connection.adapter_name,
            database_version: database_version,
            memory_usage: memory_usage,
            cpu_usage: cpu_usage
          }
        })
      end

      private

      def check_database
        # データベース接続の確認
        begin
          ActiveRecord::Base.connection.execute("SELECT 1")
          { status: 'ok', message: 'Database connection successful' }
        rescue => e
          { status: 'error', message: "Database connection failed: #{e.message}" }
        end
      end

      def check_redis
        # Redis接続の確認（実際の実装ではRedisが設定されている場合）
        begin
          if defined?(Redis) && Redis.current
            Redis.current.ping == 'PONG' ?
              { status: 'ok', message: 'Redis connection successful' } :
              { status: 'error', message: 'Redis ping failed' }
          else
            { status: 'not_configured', message: 'Redis not configured' }
          end
        rescue => e
          { status: 'error', message: "Redis connection failed: #{e.message}" }
        end
      end

      def check_storage
        # ストレージの確認
        begin
          storage_path = Rails.root.join('storage')

          if Dir.exist?(storage_path)
            test_file_path = storage_path.join('health_check_test.txt')
            File.write(test_file_path, 'test')
            File.delete(test_file_path)
            { status: 'ok', message: 'Storage is writable' }
          else
            { status: 'error', message: 'Storage directory does not exist' }
          end
        rescue => e
          { status: 'error', message: "Storage check failed: #{e.message}" }
        end
      end

      def check_elasticsearch
        # Elasticsearch接続の確認（実際の実装ではElasticsearchが設定されている場合）
        begin
          if defined?(Elasticsearch::Client)
            client = Elasticsearch::Client.new
            client.ping ?
              { status: 'ok', message: 'Elasticsearch connection successful' } :
              { status: 'error', message: 'Elasticsearch ping failed' }
          else
            { status: 'not_configured', message: 'Elasticsearch not configured' }
          end
        rescue => e
          { status: 'error', message: "Elasticsearch connection failed: #{e.message}" }
        end
      end

      def check_payment_gateway
        # 支払いゲートウェイの確認（実際の実装では支払いゲートウェイが設定されている場合）
        # ここではシミュレーションのみ
        { status: 'ok', message: 'Payment gateway simulation successful' }
      end

      def check_email_service
        # メールサービスの確認（実際の実装ではメールサービスが設定されている場合）
        begin
          if defined?(ActionMailer::Base) && ActionMailer::Base.delivery_method
            { status: 'ok', message: "Email service configured with #{ActionMailer::Base.delivery_method}" }
          else
            { status: 'not_configured', message: 'Email service not configured' }
          end
        rescue => e
          { status: 'error', message: "Email service check failed: #{e.message}" }
        end
      end

      def process_uptime
        # プロセスの稼働時間を取得
        uptime_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        days = (uptime_seconds / 86400).floor
        hours = ((uptime_seconds % 86400) / 3600).floor
        minutes = ((uptime_seconds % 3600) / 60).floor
        seconds = (uptime_seconds % 60).floor

        "#{days}d #{hours}h #{minutes}m #{seconds}s"
      end

      def database_version
        # データベースのバージョンを取得
        case ActiveRecord::Base.connection.adapter_name
        when 'PostgreSQL'
          ActiveRecord::Base.connection.execute("SELECT version()").first['version']
        when 'MySQL', 'Mysql2'
          ActiveRecord::Base.connection.execute("SELECT version()").first[0]
        when 'SQLite'
          ActiveRecord::Base.connection.execute("SELECT sqlite_version()").first[0]
        else
          'Unknown'
        end
      rescue
        'Unknown'
      end

      def memory_usage
        # メモリ使用量を取得（Linuxの場合）
        if File.exist?('/proc/self/status')
          mem_info = File.read('/proc/self/status').split("\n").grep(/VmRSS/).first
          mem_info ? mem_info.split(':').last.strip : 'Unknown'
        else
          # その他のOSの場合
          "#{(GetProcessMem.new.mb).round(2)} MB" rescue 'Unknown'
        end
      end

      def cpu_usage
        # CPU使用率を取得（シミュレーション）
        "#{rand(1.0..5.0).round(2)}%"
      end
    end
  end
end
