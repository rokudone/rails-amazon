class DataCleanupJob < ApplicationJob
  queue_as :maintenance

  # データクリーンアップを行うジョブ
  def perform(options = {})
    # オプションを取得
    options = {
      models: [],
      conditions: {},
      older_than: nil,
      batch_size: 1000,
      dry_run: false,
      on_complete: nil,
      on_error: nil,
      user_id: nil
    }.merge(options.symbolize_keys)

    # 結果を初期化
    result = {
      started_at: Time.current,
      completed_at: nil,
      models_processed: 0,
      records_deleted: 0,
      records_archived: 0,
      errors: []
    }

    begin
      # モデルが指定されていない場合
      if options[:models].blank?
        handle_error("No models specified for cleanup", options)
        return
      end

      # 各モデルを処理
      options[:models].each do |model_info|
        # モデル情報を取得
        model_class, model_options = extract_model_info(model_info)

        # モデルクラスが取得できない場合
        unless model_class
          result[:errors] << "Invalid model: #{model_info}"
          next
        end

        # モデルオプションをマージ
        model_options = options.merge(model_options || {})

        # モデルをクリーンアップ
        cleanup_result = cleanup_model(model_class, model_options)

        # 結果を更新
        result[:models_processed] += 1
        result[:records_deleted] += cleanup_result[:deleted] || 0
        result[:records_archived] += cleanup_result[:archived] || 0
        result[:errors].concat(cleanup_result[:errors] || [])
      end

      # 完了時間を設定
      result[:completed_at] = Time.current

      # 完了時の処理
      handle_completion(result, options)
    rescue => e
      # エラー時の処理
      handle_error("Data cleanup error: #{e.message}", options, e)

      # 結果を更新
      result[:errors] << e.message
      result[:completed_at] = Time.current
    end

    result
  end

  private

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

  # モデルをクリーンアップ
  def cleanup_model(model_class, options)
    # 結果を初期化
    result = {
      model: model_class.name,
      deleted: 0,
      archived: 0,
      errors: []
    }

    # クエリを構築
    query = build_cleanup_query(model_class, options)

    # レコード数を取得
    record_count = query.count

    # ドライランの場合
    if options[:dry_run]
      Rails.logger.info("DataCleanupJob Dry Run: Would delete #{record_count} records from #{model_class.name}")
      return result.merge(would_delete: record_count)
    end

    # アーカイブモードの場合
    if options[:archive]
      result[:archived] = archive_records(model_class, query, options)
    else
      # 削除モードの場合
      result[:deleted] = delete_records(model_class, query, options)
    end

    result
  end

  # クリーンアップクエリを構築
  def build_cleanup_query(model_class, options)
    # 基本クエリ
    query = model_class.all

    # 条件が指定されている場合
    if options[:conditions].present?
      query = query.where(options[:conditions])
    end

    # 古いレコードの条件が指定されている場合
    if options[:older_than].present?
      # 日付カラムを取得
      date_column = options[:date_column] || 'created_at'

      # 日付を計算
      if options[:older_than].is_a?(ActiveSupport::Duration)
        date = Time.current - options[:older_than]
      elsif options[:older_than].is_a?(Date) || options[:older_than].is_a?(Time)
        date = options[:older_than]
      else
        date = Time.current - options[:older_than].to_i.days
      end

      # クエリに条件を追加
      query = query.where("#{date_column} < ?", date)
    end

    # 除外条件が指定されている場合
    if options[:except].present?
      query = query.where.not(options[:except])
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

    query
  end

  # レコードを削除
  def delete_records(model_class, query, options)
    # 削除数を初期化
    deleted_count = 0

    # バッチサイズを取得
    batch_size = options[:batch_size] || 1000

    # バッチ処理
    if options[:force_delete] || !model_class.respond_to?(:acts_as_paranoid?)
      # 物理削除
      if options[:transaction]
        # トランザクション内で削除
        model_class.transaction do
          query.find_in_batches(batch_size: batch_size) do |batch|
            # バッチを削除
            batch_ids = batch.map(&:id)
            deleted = model_class.where(id: batch_ids).delete_all
            deleted_count += deleted

            # 進捗をログに記録
            Rails.logger.info("DataCleanupJob: Deleted #{deleted} records from #{model_class.name}, total: #{deleted_count}")
          end
        end
      else
        # トランザクションなしで削除
        query.find_in_batches(batch_size: batch_size) do |batch|
          # バッチを削除
          batch_ids = batch.map(&:id)
          deleted = model_class.where(id: batch_ids).delete_all
          deleted_count += deleted

          # 進捗をログに記録
          Rails.logger.info("DataCleanupJob: Deleted #{deleted} records from #{model_class.name}, total: #{deleted_count}")
        end
      end
    else
      # 論理削除
      if options[:transaction]
        # トランザクション内で削除
        model_class.transaction do
          query.find_in_batches(batch_size: batch_size) do |batch|
            # バッチを削除
            batch.each(&:destroy)
            deleted_count += batch.size

            # 進捗をログに記録
            Rails.logger.info("DataCleanupJob: Soft deleted #{batch.size} records from #{model_class.name}, total: #{deleted_count}")
          end
        end
      else
        # トランザクションなしで削除
        query.find_in_batches(batch_size: batch_size) do |batch|
          # バッチを削除
          batch.each(&:destroy)
          deleted_count += batch.size

          # 進捗をログに記録
          Rails.logger.info("DataCleanupJob: Soft deleted #{batch.size} records from #{model_class.name}, total: #{deleted_count}")
        end
      end
    end

    deleted_count
  end

  # レコードをアーカイブ
  def archive_records(model_class, query, options)
    # アーカイブ数を初期化
    archived_count = 0

    # バッチサイズを取得
    batch_size = options[:batch_size] || 1000

    # アーカイブカラムを取得
    archive_column = options[:archive_column] || 'archived_at'

    # アーカイブ時間を取得
    archive_time = Time.current

    # アーカイブ処理
    if options[:transaction]
      # トランザクション内でアーカイブ
      model_class.transaction do
        query.find_in_batches(batch_size: batch_size) do |batch|
          # バッチをアーカイブ
          batch_ids = batch.map(&:id)
          archived = model_class.where(id: batch_ids).update_all(archive_column => archive_time)
          archived_count += archived

          # 進捗をログに記録
          Rails.logger.info("DataCleanupJob: Archived #{archived} records from #{model_class.name}, total: #{archived_count}")
        end
      end
    else
      # トランザクションなしでアーカイブ
      query.find_in_batches(batch_size: batch_size) do |batch|
        # バッチをアーカイブ
        batch_ids = batch.map(&:id)
        archived = model_class.where(id: batch_ids).update_all(archive_column => archive_time)
        archived_count += archived

        # 進捗をログに記録
        Rails.logger.info("DataCleanupJob: Archived #{archived} records from #{model_class.name}, total: #{archived_count}")
      end
    end

    archived_count
  end

  # エラー処理
  def handle_error(message, options, exception = nil)
    # エラーをログに記録
    Rails.logger.error("DataCleanupJob Error: #{message}")
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
        event_type: 'data_cleanup_error',
        message: message,
        details: {
          models: options[:models].map { |m| m.is_a?(Hash) ? m[:model] || m[:class] : m }.map(&:to_s),
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
        notification_type: 'data_cleanup_error',
        title: 'Data Cleanup Error',
        message: message,
        reference_type: 'DataCleanup',
        reference_id: nil
      )
    end
  end

  # 完了時の処理
  def handle_completion(result, options)
    # 結果をログに記録
    Rails.logger.info("DataCleanupJob Completed: #{result.slice(:models_processed, :records_deleted, :records_archived).to_json}")

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
        event_type: 'data_cleanup_completed',
        message: "Data cleanup completed: #{result[:records_deleted]} records deleted, #{result[:records_archived]} records archived",
        details: {
          models: options[:models].map { |m| m.is_a?(Hash) ? m[:model] || m[:class] : m }.map(&:to_s),
          user_id: options[:user_id],
          result: result.slice(:models_processed, :records_deleted, :records_archived)
        }
      )
    end

    # 通知を送信
    if defined?(NotificationService) && options[:user_id].present?
      NotificationService.notify(
        recipient_type: 'user',
        recipient_id: options[:user_id],
        notification_type: 'data_cleanup_completed',
        title: 'Data Cleanup Completed',
        message: "Data cleanup completed: #{result[:records_deleted]} records deleted, #{result[:records_archived]} records archived",
        reference_type: 'DataCleanup',
        reference_id: nil
      )
    end
  end
end
