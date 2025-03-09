class DataExportJob < ApplicationJob
  queue_as :data_processing

  # データエクスポートを行うジョブ
  def perform(options = {})
    # オプションを取得
    options = {
      model_class: nil,
      query: nil,
      format: :csv,
      file_path: nil,
      columns: nil,
      include_header: true,
      batch_size: 1000,
      on_complete: nil,
      on_error: nil,
      user_id: nil
    }.merge(options.symbolize_keys)

    # モデルクラスを取得
    model_class = get_model_class(options[:model_class])
    unless model_class
      handle_error("Invalid model class: #{options[:model_class]}", options)
      return
    end

    # ファイルパスを生成
    file_path = options[:file_path] || generate_file_path(model_class, options[:format])

    # ディレクトリを作成
    FileUtils.mkdir_p(File.dirname(file_path))

    begin
      # クエリを取得
      query = get_query(model_class, options[:query])

      # カラムを取得
      columns = get_columns(model_class, options[:columns])

      # フォーマットに応じてデータをエクスポート
      case options[:format].to_sym
      when :csv
        export_csv(query, columns, file_path, options)
      when :json
        export_json(query, columns, file_path, options)
      when :xml
        export_xml(query, columns, file_path, options)
      when :excel
        export_excel(query, columns, file_path, options)
      else
        handle_error("Unsupported format: #{options[:format]}", options)
        return
      end

      # 完了時の処理
      handle_completion(file_path, options)
    rescue => e
      handle_error("Export error: #{e.message}", options, e)
    end
  end

  private

  # CSVにエクスポート
  def export_csv(query, columns, file_path, options)
    require 'csv'

    # 結果を初期化
    result = {
      total: 0,
      exported: 0,
      file_path: file_path,
      format: :csv
    }

    # 総件数を取得
    result[:total] = query.count

    # CSVファイルを作成
    CSV.open(file_path, 'w') do |csv|
      # ヘッダーを追加
      if options[:include_header]
        header_row = columns.map { |column| format_header(column) }
        csv << header_row
      end

      # バッチ処理
      query.find_each(batch_size: options[:batch_size]) do |record|
        # レコードをエクスポート
        row = columns.map { |column| get_column_value(record, column) }
        csv << row
        result[:exported] += 1
      end
    end

    result
  end

  # JSONにエクスポート
  def export_json(query, columns, file_path, options)
    require 'json'

    # 結果を初期化
    result = {
      total: 0,
      exported: 0,
      file_path: file_path,
      format: :json
    }

    # 総件数を取得
    result[:total] = query.count

    # データを収集
    records = []
    query.find_each(batch_size: options[:batch_size]) do |record|
      # レコードをエクスポート
      record_data = {}
      columns.each do |column|
        record_data[column.to_s] = get_column_value(record, column)
      end
      records << record_data
      result[:exported] += 1
    end

    # JSONファイルを作成
    File.open(file_path, 'w') do |file|
      file.write(JSON.pretty_generate(records))
    end

    result
  end

  # XMLにエクスポート
  def export_xml(query, columns, file_path, options)
    require 'nokogiri'

    # 結果を初期化
    result = {
      total: 0,
      exported: 0,
      file_path: file_path,
      format: :xml
    }

    # 総件数を取得
    result[:total] = query.count

    # XMLドキュメントを作成
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      # ルート要素
      root_element = options[:root_element] || query.model.name.underscore.pluralize
      xml.send(root_element) do
        # バッチ処理
        query.find_each(batch_size: options[:batch_size]) do |record|
          # レコード要素
          record_element = options[:record_element] || query.model.name.underscore
          xml.send(record_element) do
            # 各カラムを追加
            columns.each do |column|
              xml.send(column, get_column_value(record, column))
            end
          end
          result[:exported] += 1
        end
      end
    end

    # XMLファイルを作成
    File.open(file_path, 'w') do |file|
      file.write(builder.to_xml)
    end

    result
  end

  # Excelにエクスポート
  def export_excel(query, columns, file_path, options)
    require 'axlsx'

    # 結果を初期化
    result = {
      total: 0,
      exported: 0,
      file_path: file_path,
      format: :excel
    }

    # 総件数を取得
    result[:total] = query.count

    # Excelパッケージを作成
    package = Axlsx::Package.new
    workbook = package.workbook

    # シートを追加
    sheet_name = options[:sheet_name] || query.model.name.pluralize
    workbook.add_worksheet(name: sheet_name) do |sheet|
      # スタイルを設定
      styles = workbook.styles
      header_style = styles.add_style(b: true, bg_color: "DDDDDD")

      # ヘッダーを追加
      if options[:include_header]
        header_row = columns.map { |column| format_header(column) }
        sheet.add_row header_row, style: header_style
      end

      # バッチ処理
      offset = 0
      batch_size = options[:batch_size]

      while offset < result[:total]
        # バッチを取得
        batch = query.offset(offset).limit(batch_size).to_a

        # 各レコードを処理
        batch.each do |record|
          # レコードをエクスポート
          row = columns.map { |column| get_column_value(record, column) }
          sheet.add_row row
          result[:exported] += 1
        end

        # オフセットを更新
        offset += batch_size
      end
    end

    # Excelファイルを保存
    package.serialize(file_path)

    result
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

  # クエリを取得
  def get_query(model_class, query)
    if query.is_a?(ActiveRecord::Relation)
      query
    elsif query.is_a?(Hash)
      model_class.where(query)
    elsif query.is_a?(String)
      model_class.where(query)
    elsif query.is_a?(Array)
      model_class.where(*query)
    else
      model_class.all
    end
  end

  # カラムを取得
  def get_columns(model_class, columns)
    if columns.present?
      Array(columns).map(&:to_sym)
    else
      model_class.column_names.map(&:to_sym)
    end
  end

  # ファイルパスを生成
  def generate_file_path(model_class, format)
    timestamp = Time.current.strftime('%Y%m%d%H%M%S')
    filename = "#{model_class.name.underscore.pluralize}_#{timestamp}.#{format}"
    File.join(Rails.root, 'tmp', 'exports', filename)
  end

  # ヘッダーをフォーマット
  def format_header(column)
    column.to_s.humanize
  end

  # カラム値を取得
  def get_column_value(record, column)
    # ネストされたカラムの場合
    if column.to_s.include?('.')
      parts = column.to_s.split('.')
      value = record
      parts.each do |part|
        value = value.try(part)
      end
      value
    # 通常のカラムの場合
    else
      record.try(column)
    end
  end

  # エラー処理
  def handle_error(message, options, exception = nil)
    # エラーをログに記録
    Rails.logger.error("DataExportJob Error: #{message}")
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
        event_type: 'data_export_error',
        message: message,
        details: {
          model_class: options[:model_class].to_s,
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
        notification_type: 'data_export_error',
        title: 'Data Export Error',
        message: message,
        reference_type: 'DataExport',
        reference_id: nil
      )
    end
  end

  # 完了時の処理
  def handle_completion(file_path, options)
    # 結果を初期化
    result = {
      file_path: file_path,
      format: options[:format],
      model_class: options[:model_class].to_s,
      timestamp: Time.current
    }

    # 結果をログに記録
    Rails.logger.info("DataExportJob Completed: #{result.to_json}")

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
        event_type: 'data_export_completed',
        message: "Data export completed: #{File.basename(file_path)}",
        details: {
          file_path: file_path,
          model_class: options[:model_class].to_s,
          format: options[:format],
          user_id: options[:user_id]
        }
      )
    end

    # 通知を送信
    if defined?(NotificationService) && options[:user_id].present?
      NotificationService.notify(
        recipient_type: 'user',
        recipient_id: options[:user_id],
        notification_type: 'data_export_completed',
        title: 'Data Export Completed',
        message: "Data export completed: #{File.basename(file_path)}",
        reference_type: 'DataExport',
        reference_id: nil
      )
    end

    result
  end
end
