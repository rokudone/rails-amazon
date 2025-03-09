class DataBackupJob < ApplicationJob
  queue_as :maintenance

  # データバックアップを行うジョブ
  def perform(options = {})
    # オプションを取得
    options = {
      models: [],
      format: :json,
      compress: true,
      encrypt: false,
      encryption_key: nil,
      backup_dir: Rails.root.join('tmp', 'backups'),
      include_schema: true,
      include_attachments: false,
      on_complete: nil,
      on_error: nil,
      user_id: nil
    }.merge(options.symbolize_keys)

    # 結果を初期化
    result = {
      started_at: Time.current,
      completed_at: nil,
      backup_path: nil,
      models_backed_up: 0,
      records_backed_up: 0,
      backup_size: 0,
      errors: []
    }

    begin
      # バックアップディレクトリを作成
      FileUtils.mkdir_p(options[:backup_dir])

      # バックアップファイル名を生成
      timestamp = Time.current.strftime('%Y%m%d%H%M%S')
      backup_filename = "backup_#{timestamp}"

      # フォーマットに応じてファイル拡張子を設定
      extension = options[:format].to_s

      # 圧縮する場合は拡張子を追加
      if options[:compress]
        extension += '.gz'
      end

      # 暗号化する場合は拡張子を追加
      if options[:encrypt]
        extension += '.enc'
      end

      # バックアップファイルパスを設定
      backup_path = File.join(options[:backup_dir], "#{backup_filename}.#{extension}")
      result[:backup_path] = backup_path

      # バックアップデータを収集
      backup_data = collect_backup_data(options)

      # 結果を更新
      result[:models_backed_up] = backup_data[:models].size
      result[:records_backed_up] = backup_data[:total_records]

      # バックアップファイルを作成
      create_backup_file(backup_data, backup_path, options)

      # バックアップファイルサイズを取得
      result[:backup_size] = File.size(backup_path)

      # 完了時間を設定
      result[:completed_at] = Time.current

      # 完了時の処理
      handle_completion(result, options)
    rescue => e
      # エラー時の処理
      handle_error("Data backup error: #{e.message}", options, e)

      # 結果を更新
      result[:errors] << e.message
      result[:completed_at] = Time.current
    end

    result
  end

  private

  # バックアップデータを収集
  def collect_backup_data(options)
    # 結果を初期化
    result = {
      timestamp: Time.current,
      environment: Rails.env,
      rails_version: Rails.version,
      database_adapter: ActiveRecord::Base.connection.adapter_name,
      models: [],
      schema: nil,
      total_records: 0
    }

    # スキーマを含める場合
    if options[:include_schema]
      result[:schema] = collect_schema_info
    end

    # モデルが指定されていない場合は全モデルを対象にする
    models = options[:models].present? ? options[:models] : all_models

    # 各モデルのデータを収集
    models.each do |model_info|
      # モデル情報を取得
      model_class, model_options = extract_model_info(model_info)

      # モデルクラスが取得できない場合
      unless model_class
        result[:errors] ||= []
        result[:errors] << "Invalid model: #{model_info}"
        next
      end

      # モデルオプションをマージ
      model_options = options.merge(model_options || {})

      # モデルデータを収集
      model_data = collect_model_data(model_class, model_options)

      # 結果を更新
      result[:models] << model_data
      result[:total_records] += model_data[:records].size
    end

    result
  end

  # モデル情報を抽出
  def extract_model_info(model_info)
    if model_info.is_a?(Hash)
      # ハッシュの場合
      model_class = get_model_class(model_info[:model] || model_info[:class])
      model_options = model_info.except(:model, :class)
      [model_class, model_options]
    else
      # 文字列またはクラスの場合
      [get_model_class(model_info), {}]
    end
  end

  # モデルクラスを取得
  def get_model_class(model_class)
    return nil unless model_class

    if model_class.is_a?(Class)
      model_class
    elsif model_class.is_a?(String) || model_class.is_a?(Symbol)
      model_class.to_s.classify.constantize
    else
      nil
    end
  rescue NameError
    nil
  end

  # 全モデルを取得
  def all_models
    # Railsアプリケーションの全モデルを取得
    Rails.application.eager_load!
    ApplicationRecord.descendants
  end

  # スキーマ情報を収集
  def collect_schema_info
    # テーブル情報を収集
    tables = {}

    ActiveRecord::Base.connection.tables.each do |table_name|
      # システムテーブルをスキップ
      next if table_name == 'schema_migrations' || table_name == 'ar_internal_metadata'

      # カラム情報を収集
      columns = {}
      ActiveRecord::Base.connection.columns(table_name).each do |column|
        columns[column.name] = {
          type: column.type,
          null: column.null,
          default: column.default,
          limit: column.limit,
          precision: column.precision,
          scale: column.scale
        }
      end

      # インデックス情報を収集
      indexes = {}
      ActiveRecord::Base.connection.indexes(table_name).each do |index|
        indexes[index.name] = {
          columns: index.columns,
          unique: index.unique
        }
      end

      # テーブル情報を設定
      tables[table_name] = {
        columns: columns,
        indexes: indexes
      }
    end

    tables
  end

  # モデルデータを収集
  def collect_model_data(model_class, options)
    # 結果を初期化
    result = {
      model: model_class.name,
      table: model_class.table_name,
      records: []
    }

    # クエリを構築
    query = build_backup_query(model_class, options)

    # レコード数を取得
    total_records = query.count

    # バッチサイズを取得
    batch_size = options[:batch_size] || 1000

    # バッチ処理
    query.find_in_batches(batch_size: batch_size) do |batch|
      # 各レコードを処理
      batch.each do |record|
        # レコードデータを収集
        record_data = collect_record_data(record, options)

        # 結果に追加
        result[:records] << record_data
      end

      # 進捗をログに記録
      Rails.logger.info("DataBackupJob: Backed up #{result[:records].size}/#{total_records} records from #{model_class.name}")
    end

    result
  end

  # バックアップクエリを構築
  def build_backup_query(model_class, options)
    # 基本クエリ
    query = model_class.all

    # 条件が指定されている場合
    if options[:conditions].present?
      query = query.where(options[:conditions])
    end

    # 追加条件が指定されている場合
    if options[:additional_conditions].present?
      if options[:additional_conditions].is_a?(Proc)
        query = options[:additional_conditions].call(query)
      elsif options[:additional_conditions].is_a?(String)
        query = query.where(options[:additional_conditions])
      elsif options[:additional_conditions].is_a?(Hash)
        query = query.where(options[:additional_conditions])
      end
    end

    # ソート条件が指定されている場合
    if options[:order].present?
      query = query.order(options[:order])
    else
      # デフォルトはID順
      query = query.order(:id)
    end

    # 関連データを含める場合
    if options[:include].present?
      query = query.includes(options[:include])
    end

    query
  end

  # レコードデータを収集
  def collect_record_data(record, options)
    # 基本属性を取得
    data = record.attributes

    # 関連データを含める場合
    if options[:include_associations]
      # 関連データを収集
      associations = {}

      # 関連付けを取得
      record.class.reflect_on_all_associations.each do |association|
        # 関連データを取得
        related_data = record.send(association.name)

        # 関連データが存在する場合
        if related_data.present?
          # 関連データを変換
          if related_data.is_a?(ActiveRecord::Relation) || related_data.is_a?(Array)
            # 複数の関連データ
            associations[association.name] = related_data.map(&:attributes)
          else
            # 単一の関連データ
            associations[association.name] = related_data.attributes
          end
        end
      end

      # 関連データを追加
      data[:associations] = associations
    end

    # 添付ファイルを含める場合
    if options[:include_attachments] && record.respond_to?(:attachments)
      # 添付ファイル情報を収集
      attachments = {}

      record.attachments.each do |name, attachment|
        # 添付ファイルが存在する場合
        if attachment.attached?
          # 添付ファイル情報を取得
          attachment_info = {
            name: name,
            content_type: attachment.content_type,
            filename: attachment.filename.to_s
          }

          # 添付ファイルの内容を含める場合
          if options[:include_attachment_content]
            attachment_info[:content] = Base64.encode64(attachment.download)
          end

          # 添付ファイル情報を追加
          attachments[name] = attachment_info
        end
      end

      # 添付ファイル情報を追加
      data[:attachments] = attachments
    end

    data
  end

  # バックアップファイルを作成
  def create_backup_file(backup_data, backup_path, options)
    # フォーマットに応じてデータを変換
    case options[:format].to_sym
    when :json
      content = JSON.pretty_generate(backup_data)
    when :yaml
      content = backup_data.to_yaml
    when :csv
      content = generate_csv_backup(backup_data)
    when :xml
      content = generate_xml_backup(backup_data)
    else
      content = JSON.pretty_generate(backup_data)
    end

    # 圧縮する場合
    if options[:compress]
      content = compress_content(content)
    end

    # 暗号化する場合
    if options[:encrypt]
      content = encrypt_content(content, options[:encryption_key])
    end

    # ファイルに書き込み
    File.open(backup_path, 'wb') do |file|
      file.write(content)
    end
  end

  # CSVバックアップを生成
  def generate_csv_backup(backup_data)
    require 'csv'

    # CSVデータを初期化
    csv_data = []

    # ヘッダー情報を追加
    csv_data << ["# Backup generated at: #{backup_data[:timestamp]}"]
    csv_data << ["# Environment: #{backup_data[:environment]}"]
    csv_data << ["# Rails version: #{backup_data[:rails_version]}"]
    csv_data << ["# Database adapter: #{backup_data[:database_adapter]}"]
    csv_data << ["# Total records: #{backup_data[:total_records]}"]
    csv_data << []

    # 各モデルのデータを追加
    backup_data[:models].each do |model_data|
      # モデル情報を追加
      csv_data << ["# Model: #{model_data[:model]}"]
      csv_data << ["# Table: #{model_data[:table]}"]
      csv_data << ["# Records: #{model_data[:records].size}"]

      # レコードがある場合
      if model_data[:records].any?
        # カラム名を取得
        columns = model_data[:records].first.keys

        # ヘッダー行を追加
        csv_data << columns

        # データ行を追加
        model_data[:records].each do |record|
          csv_data << columns.map { |column| record[column] }
        end
      end

      csv_data << []
    end

    # CSVデータを文字列に変換
    CSV.generate do |csv|
      csv_data.each do |row|
        csv << row
      end
    end
  end

  # XMLバックアップを生成
  def generate_xml_backup(backup_data)
    require 'nokogiri'

    # XMLドキュメントを作成
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.backup(
        timestamp: backup_data[:timestamp],
        environment: backup_data[:environment],
        rails_version: backup_data[:rails_version],
        database_adapter: backup_data[:database_adapter],
        total_records: backup_data[:total_records]
      ) do
        # スキーマ情報を追加
        if backup_data[:schema].present?
          xml.schema do
            backup_data[:schema].each do |table_name, table_info|
              xml.table(name: table_name) do
                # カラム情報を追加
                xml.columns do
                  table_info[:columns].each do |column_name, column_info|
                    xml.column(column_info.merge(name: column_name))
                  end
                end

                # インデックス情報を追加
                xml.indexes do
                  table_info[:indexes].each do |index_name, index_info|
                    xml.index(name: index_name, unique: index_info[:unique]) do
                      index_info[:columns].each do |column|
                        xml.column(column)
                      end
                    end
                  end
                end
              end
            end
          end
        end

        # モデルデータを追加
        xml.models do
          backup_data[:models].each do |model_data|
            xml.model(name: model_data[:model], table: model_data[:table]) do
              # レコードを追加
              xml.records do
                model_data[:records].each do |record|
                  xml.record do
                    record.each do |key, value|
                      # 関連データの場合
                      if key == :associations && value.present?
                        xml.associations do
                          value.each do |assoc_name, assoc_data|
                            xml.association(name: assoc_name) do
                              if assoc_data.is_a?(Array)
                                assoc_data.each do |assoc_record|
                                  xml.record do
                                    assoc_record.each do |assoc_key, assoc_value|
                                      xml.send(assoc_key, assoc_value)
                                    end
                                  end
                                end
                              else
                                assoc_data.each do |assoc_key, assoc_value|
                                  xml.send(assoc_key, assoc_value)
                                end
                              end
                            end
                          end
                        end
                      # 添付ファイルの場合
                      elsif key == :attachments && value.present?
                        xml.attachments do
                          value.each do |attach_name, attach_data|
                            xml.attachment(name: attach_name) do
                              attach_data.each do |attach_key, attach_value|
                                xml.send(attach_key, attach_value)
                              end
                            end
                          end
                        end
                      # 通常のカラムの場合
                      else
                        xml.send(key, value)
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    builder.to_xml
  end

  # コンテンツを圧縮
  def compress_content(content)
    require 'zlib'

    # 圧縮
    Zlib::Deflate.deflate(content)
  end

  # コンテンツを暗号化
  def encrypt_content(content, key)
    require 'openssl'

    # 暗号化キーが指定されていない場合
    unless key.present?
      raise "Encryption key is required for encryption"
    end

    # 暗号化キーを正規化
    normalized_key = Digest::SHA256.digest(key.to_s)

    # 初期化ベクトルを生成
    iv = SecureRandom.random_bytes(16)

    # 暗号化
    cipher = OpenSSL::Cipher.new('aes-256-cbc')
    cipher.encrypt
    cipher.key = normalized_key
    cipher.iv = iv

    # 暗号化データを生成
    encrypted = cipher.update(content) + cipher.final

    # 初期化ベクトルと暗号化データを結合
    iv + encrypted
  end

  # エラー処理
  def handle_error(message, options, exception = nil)
    # エラーをログに記録
    Rails.logger.error("DataBackupJob Error: #{message}")
    Rails.logger.error(exception.backtrace.join("\n")) if exception

    # エラーコールバックが指定されている場合
    if options[:on_error].present?
      if options[:on_error].is_a?(Proc)
        options[:on_error].call(message, exception)
      elsif options[:on_error].is_a?(String) || options[:on_error].is_a?(Symbol)
        method_name = options[:on_error].to_s
        if respond_to?(method_name)
          send(method_name, message, exception)
        end
      end
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'data_backup_error',
        message: message,
        details: {
          models: options[:models].map { |m| m.is_a?(Hash) ? m[:model] || m[:class] : m }.map(&:to_s),
          format: options[:format],
          user_id: options[:user_id],
          error: exception&.message,
          backtrace: exception&.backtrace&.first(10)
        }
      )
    end

    # 通知を送信
    if defined?(NotificationService) && options[:user_id].present?
      NotificationService.notify(
        recipient_type: 'user',
        recipient_id: options[:user_id],
        notification_type: 'data_backup_error',
        title: 'Data Backup Error',
        message: message,
        reference_type: 'DataBackup',
        reference_id: nil
      )
    end
  end

  # 完了時の処理
  def handle_completion(result, options)
    # 結果をログに記録
    Rails.logger.info("DataBackupJob Completed: #{result.slice(:models_backed_up, :records_backed_up, :backup_size).to_json}")

    # 完了コールバックが指定されている場合
    if options[:on_complete].present?
      if options[:on_complete].is_a?(Proc)
        options[:on_complete].call(result)
      elsif options[:on_complete].is_a?(String) || options[:on_complete].is_a?(Symbol)
        method_name = options[:on_complete].to_s
        if respond_to?(method_name)
          send(method_name, result)
        end
      end
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'data_backup_completed',
        message: "Data backup completed: #{result[:records_backed_up]} records backed up, #{(result[:backup_size].to_f / 1024 / 1024).round(2)} MB",
        details: {
          backup_path: result[:backup_path],
          models: options[:models].map { |m| m.is_a?(Hash) ? m[:model] || m[:class] : m }.map(&:to_s),
          format: options[:format],
          user_id: options[:user_id],
          result: result.slice(:models_backed_up, :records_backed_up, :backup_size)
        }
      )
    end

    # 通知を送信
    if defined?(NotificationService) && options[:user_id].present?
      NotificationService.notify(
        recipient_type: 'user',
        recipient_id: options[:user_id],
        notification_type: 'data_backup_completed',
        title: 'Data Backup Completed',
        message: "Data backup completed: #{result[:records_backed_up]} records backed up, #{(result[:backup_size].to_f / 1024 / 1024).round(2)} MB",
        reference_type: 'DataBackup',
        reference_id: nil
      )
    end
  end
end
