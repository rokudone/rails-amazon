class DataMigrationJob < ApplicationJob
  queue_as :data_processing

  # データ移行を行うジョブ
  def perform(options = {})
    # オプションを取得
    options = {
      source_model: nil,
      target_model: nil,
      mapping: {},
      conditions: {},
      batch_size: 1000,
      skip_validation: false,
      delete_source: false,
      on_complete: nil,
      on_error: nil,
      user_id: nil
    }.merge(options.symbolize_keys)

    # 結果を初期化
    result = {
      started_at: Time.current,
      completed_at: nil,
      source_records: 0,
      migrated_records: 0,
      failed_records: 0,
      deleted_records: 0,
      errors: []
    }

    begin
      # ソースモデルを取得
      source_model = get_model_class(options[:source_model])
      unless source_model
        handle_error("Invalid source model: #{options[:source_model]}", options)
        return
      end

      # ターゲットモデルを取得
      target_model = get_model_class(options[:target_model])
      unless target_model
        handle_error("Invalid target model: #{options[:target_model]}", options)
        return
      end

      # マッピングが指定されていない場合
      if options[:mapping].blank?
        # 共通カラムを自動マッピング
        options[:mapping] = auto_generate_mapping(source_model, target_model)
      end

      # クエリを構築
      query = build_migration_query(source_model, options)

      # レコード数を取得
      result[:source_records] = query.count

      # データを移行
      migration_result = migrate_data(query, target_model, options)

      # 結果を更新
      result[:migrated_records] = migration_result[:migrated]
      result[:failed_records] = migration_result[:failed]
      result[:errors].concat(migration_result[:errors])

      # ソースレコードを削除
      if options[:delete_source] && migration_result[:migrated] > 0
        result[:deleted_records] = delete_source_records(query, options)
      end

      # 完了時間を設定
      result[:completed_at] = Time.current

      # 完了時の処理
      handle_completion(result, options)
    rescue => e
      # エラー時の処理
      handle_error("Data migration error: #{e.message}", options, e)

      # 結果を更新
      result[:errors] << e.message
      result[:completed_at] = Time.current
    end

    result
  end

  private

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

  # 移行クエリを構築
  def build_migration_query(model_class, options)
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
    end

    query
  end

  # 自動マッピングを生成
  def auto_generate_mapping(source_model, target_model)
    mapping = {}

    # ソースモデルのカラムを取得
    source_columns = source_model.column_names

    # ターゲットモデルのカラムを取得
    target_columns = target_model.column_names

    # 共通カラムを抽出
    common_columns = source_columns & target_columns

    # 共通カラムをマッピング
    common_columns.each do |column|
      mapping[column.to_sym] = column.to_sym
    end

    mapping
  end

  # データを移行
  def migrate_data(query, target_model, options)
    # 結果を初期化
    result = {
      migrated: 0,
      failed: 0,
      errors: []
    }

    # バッチサイズを取得
    batch_size = options[:batch_size] || 1000

    # バッチ処理
    query.find_in_batches(batch_size: batch_size) do |batch|
      # トランザクションを開始
      ActiveRecord::Base.transaction do
        batch.each do |source_record|
          begin
            # ターゲットレコードを作成
            target_record = create_target_record(source_record, target_model, options)

            # レコードを保存
            if options[:skip_validation]
              success = target_record.save(validate: false)
            else
              success = target_record.save
            end

            # 結果を更新
            if success
              result[:migrated] += 1

              # 移行後のコールバックが指定されている場合
              if options[:after_migrate].present? && options[:after_migrate].is_a?(Proc)
                options[:after_migrate].call(source_record, target_record)
              end
            else
              result[:failed] += 1
              result[:errors] << {
                source_id: source_record.id,
                errors: target_record.errors.full_messages
              }
            end
          rescue => e
            # エラーが発生した場合
            result[:failed] += 1
            result[:errors] << {
              source_id: source_record.id,
              error: e.message
            }

            # トランザクションをロールバックするかどうか
            raise e if options[:rollback_on_error]
          end
        end
      end

      # 進捗をログに記録
      Rails.logger.info("DataMigrationJob: Migrated #{result[:migrated]} records, failed: #{result[:failed]}")
    end

    result
  end

  # ターゲットレコードを作成
  def create_target_record(source_record, target_model, options)
    # ターゲットレコードを初期化
    target_record = target_model.new

    # マッピングを適用
    options[:mapping].each do |target_field, source_field|
      # ソースフィールドがProcの場合
      if source_field.is_a?(Proc)
        target_record[target_field] = source_field.call(source_record)
      # ソースフィールドがシンボルまたは文字列の場合
      elsif source_field.is_a?(Symbol) || source_field.is_a?(String)
        target_record[target_field] = source_record[source_field]
      # ソースフィールドがハッシュの場合（関連データ）
      elsif source_field.is_a?(Hash) && source_field[:association]
        # 関連データを取得
        association = source_field[:association]
        related_data = source_record.send(association)

        # 関連データが存在する場合
        if related_data.present?
          # 関連データのマッピングが指定されている場合
          if source_field[:mapping].present?
            # 関連データをマッピング
            if related_data.is_a?(ActiveRecord::Relation) || related_data.is_a?(Array)
              # 複数の関連データ
              related_values = related_data.map do |item|
                map_related_data(item, source_field[:mapping])
              end
              target_record[target_field] = related_values
            else
              # 単一の関連データ
              target_record[target_field] = map_related_data(related_data, source_field[:mapping])
            end
          else
            # マッピングが指定されていない場合はそのまま使用
            target_record[target_field] = related_data
          end
        end
      end
    end

    # 追加属性が指定されている場合
    if options[:additional_attributes].present?
      if options[:additional_attributes].is_a?(Proc)
        # Procの場合
        additional_attrs = options[:additional_attributes].call(source_record)
        target_record.assign_attributes(additional_attrs) if additional_attrs.is_a?(Hash)
      elsif options[:additional_attributes].is_a?(Hash)
        # ハッシュの場合
        target_record.assign_attributes(options[:additional_attributes])
      end
    end

    target_record
  end

  # 関連データをマッピング
  def map_related_data(related_data, mapping)
    result = {}

    mapping.each do |target_field, source_field|
      # ソースフィールドがProcの場合
      if source_field.is_a?(Proc)
        result[target_field] = source_field.call(related_data)
      # ソースフィールドがシンボルまたは文字列の場合
      elsif source_field.is_a?(Symbol) || source_field.is_a?(String)
        result[target_field] = related_data[source_field]
      end
    end

    result
  end

  # ソースレコードを削除
  def delete_source_records(query, options)
    # 削除数を初期化
    deleted_count = 0

    # バッチサイズを取得
    batch_size = options[:batch_size] || 1000

    # バッチ処理
    if options[:force_delete] || !query.model.respond_to?(:acts_as_paranoid?)
      # 物理削除
      query.find_in_batches(batch_size: batch_size) do |batch|
        # バッチを削除
        batch_ids = batch.map(&:id)
        deleted = query.model.where(id: batch_ids).delete_all
        deleted_count += deleted

        # 進捗をログに記録
        Rails.logger.info("DataMigrationJob: Deleted #{deleted} source records, total: #{deleted_count}")
      end
    else
      # 論理削除
      query.find_in_batches(batch_size: batch_size) do |batch|
        # バッチを削除
        batch.each(&:destroy)
        deleted_count += batch.size

        # 進捗をログに記録
        Rails.logger.info("DataMigrationJob: Soft deleted #{batch.size} source records, total: #{deleted_count}")
      end
    end

    deleted_count
  end

  # エラー処理
  def handle_error(message, options, exception = nil)
    # エラーをログに記録
    Rails.logger.error("DataMigrationJob Error: #{message}")
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
        event_type: 'data_migration_error',
        message: message,
        details: {
          source_model: options[:source_model].to_s,
          target_model: options[:target_model].to_s,
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
        notification_type: 'data_migration_error',
        title: 'Data Migration Error',
        message: message,
        reference_type: 'DataMigration',
        reference_id: nil
      )
    end
  end

  # 完了時の処理
  def handle_completion(result, options)
    # 結果をログに記録
    Rails.logger.info("DataMigrationJob Completed: #{result.slice(:source_records, :migrated_records, :failed_records, :deleted_records).to_json}")

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
        event_type: 'data_migration_completed',
        message: "Data migration completed: #{result[:migrated_records]} records migrated, #{result[:failed_records]} failed",
        details: {
          source_model: options[:source_model].to_s,
          target_model: options[:target_model].to_s,
          user_id: options[:user_id],
          result: result.slice(:source_records, :migrated_records, :failed_records, :deleted_records)
        }
      )
    end

    # 通知を送信
    if defined?(NotificationService) && options[:user_id].present?
      NotificationService.notify(
        recipient_type: 'user',
        recipient_id: options[:user_id],
        notification_type: 'data_migration_completed',
        title: 'Data Migration Completed',
        message: "Data migration completed: #{result[:migrated_records]} records migrated, #{result[:failed_records]} failed",
        reference_type: 'DataMigration',
        reference_id: nil
      )
    end
  end
end
