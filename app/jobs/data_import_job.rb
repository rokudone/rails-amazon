class DataImportJob < ApplicationJob
  queue_as :data_processing

  # データインポートを行うジョブ
  def perform(file_path, options = {})
    # オプションを取得
    options = {
      model_class: nil,
      format: detect_format(file_path),
      batch_size: 100,
      headers: true,
      skip_validation: false,
      on_complete: nil,
      on_error: nil,
      user_id: nil
    }.merge(options.symbolize_keys)

    # ファイルが存在するか確認
    unless File.exist?(file_path)
      handle_error("File not found: #{file_path}", options)
      return
    end

    # モデルクラスを取得
    model_class = get_model_class(options[:model_class])
    unless model_class
      handle_error("Invalid model class: #{options[:model_class]}", options)
      return
    end

    begin
      # フォーマットに応じてデータをインポート
      case options[:format].to_sym
      when :csv
        import_csv(file_path, model_class, options)
      when :json
        import_json(file_path, model_class, options)
      when :xml
        import_xml(file_path, model_class, options)
      when :excel
        import_excel(file_path, model_class, options)
      else
        handle_error("Unsupported format: #{options[:format]}", options)
      end
    rescue => e
      handle_error("Import error: #{e.message}", options, e)
    end
  end

  private

  # CSVファイルをインポート
  def import_csv(file_path, model_class, options)
    require 'csv'

    # 結果を初期化
    result = {
      total: 0,
      imported: 0,
      updated: 0,
      skipped: 0,
      failed: 0,
      errors: []
    }

    # CSVファイルを読み込み
    csv_options = { headers: options[:headers] }
    csv_options[:col_sep] = options[:column_separator] if options[:column_separator]
    csv_options[:quote_char] = options[:quote_character] if options[:quote_character]

    rows = CSV.read(file_path, **csv_options)
    result[:total] = rows.size

    # バッチ処理
    rows.each_slice(options[:batch_size]) do |batch|
      # トランザクションを開始
      ActiveRecord::Base.transaction do
        batch.each do |row|
          # データを変換
          attributes = row.to_h

          # データをフォーマット
          formatted_attributes = format_attributes(attributes, model_class)

          # レコードを作成または更新
          record = find_or_initialize_record(model_class, formatted_attributes, options)

          # レコードを保存
          if options[:skip_validation]
            success = record.save(validate: false)
          else
            success = record.save
          end

          # 結果を更新
          if success
            if record.previously_new_record?
              result[:imported] += 1
            else
              result[:updated] += 1
            end
          else
            result[:failed] += 1
            result[:errors] << {
              row: row.to_h,
              errors: record.errors.full_messages
            }
          end
        end
      end
    end

    # 完了時の処理
    handle_completion(result, options)
  end

  # JSONファイルをインポート
  def import_json(file_path, model_class, options)
    require 'json'

    # 結果を初期化
    result = {
      total: 0,
      imported: 0,
      updated: 0,
      skipped: 0,
      failed: 0,
      errors: []
    }

    # JSONファイルを読み込み
    json_data = JSON.parse(File.read(file_path))

    # 配列でない場合は配列に変換
    records = json_data.is_a?(Array) ? json_data : [json_data]
    result[:total] = records.size

    # バッチ処理
    records.each_slice(options[:batch_size]) do |batch|
      # トランザクションを開始
      ActiveRecord::Base.transaction do
        batch.each do |attributes|
          # データをフォーマット
          formatted_attributes = format_attributes(attributes, model_class)

          # レコードを作成または更新
          record = find_or_initialize_record(model_class, formatted_attributes, options)

          # レコードを保存
          if options[:skip_validation]
            success = record.save(validate: false)
          else
            success = record.save
          end

          # 結果を更新
          if success
            if record.previously_new_record?
              result[:imported] += 1
            else
              result[:updated] += 1
            end
          else
            result[:failed] += 1
            result[:errors] << {
              record: attributes,
              errors: record.errors.full_messages
            }
          end
        end
      end
    end

    # 完了時の処理
    handle_completion(result, options)
  end

  # XMLファイルをインポート
  def import_xml(file_path, model_class, options)
    require 'nokogiri'

    # 結果を初期化
    result = {
      total: 0,
      imported: 0,
      updated: 0,
      skipped: 0,
      failed: 0,
      errors: []
    }

    # XMLファイルを読み込み
    xml_doc = Nokogiri::XML(File.read(file_path))

    # ルート要素を取得
    root_element = options[:root_element] || model_class.name.underscore.pluralize
    records = xml_doc.xpath("//#{root_element}/#{model_class.name.underscore}")
    result[:total] = records.size

    # バッチ処理
    records.each_slice(options[:batch_size]) do |batch|
      # トランザクションを開始
      ActiveRecord::Base.transaction do
        batch.each do |record_node|
          # データを変換
          attributes = {}
          record_node.elements.each do |element|
            attributes[element.name] = element.text
          end

          # データをフォーマット
          formatted_attributes = format_attributes(attributes, model_class)

          # レコードを作成または更新
          record = find_or_initialize_record(model_class, formatted_attributes, options)

          # レコードを保存
          if options[:skip_validation]
            success = record.save(validate: false)
          else
            success = record.save
          end

          # 結果を更新
          if success
            if record.previously_new_record?
              result[:imported] += 1
            else
              result[:updated] += 1
            end
          else
            result[:failed] += 1
            result[:errors] << {
              record: attributes,
              errors: record.errors.full_messages
            }
          end
        end
      end
    end

    # 完了時の処理
    handle_completion(result, options)
  end

  # Excelファイルをインポート
  def import_excel(file_path, model_class, options)
    require 'roo'

    # 結果を初期化
    result = {
      total: 0,
      imported: 0,
      updated: 0,
      skipped: 0,
      failed: 0,
      errors: []
    }

    # Excelファイルを読み込み
    spreadsheet = Roo::Spreadsheet.open(file_path)
    sheet = spreadsheet.sheet(options[:sheet] || 0)

    # ヘッダーを取得
    headers = options[:headers] ? sheet.row(1) : nil
    start_row = options[:headers] ? 2 : 1
    end_row = sheet.last_row

    # 行数を取得
    result[:total] = end_row - start_row + 1

    # バッチ処理
    (start_row..end_row).each_slice(options[:batch_size]) do |batch_rows|
      # トランザクションを開始
      ActiveRecord::Base.transaction do
        batch_rows.each do |row_index|
          # データを変換
          row = sheet.row(row_index)
          attributes = {}

          if headers
            headers.each_with_index do |header, i|
              attributes[header] = row[i] if header.present?
            end
          else
            row.each_with_index do |value, i|
              attributes["column_#{i+1}"] = value
            end
          end

          # データをフォーマット
          formatted_attributes = format_attributes(attributes, model_class)

          # レコードを作成または更新
          record = find_or_initialize_record(model_class, formatted_attributes, options)

          # レコードを保存
          if options[:skip_validation]
            success = record.save(validate: false)
          else
            success = record.save
          end

          # 結果を更新
          if success
            if record.previously_new_record?
              result[:imported] += 1
            else
              result[:updated] += 1
            end
          else
            result[:failed] += 1
            result[:errors] << {
              row: row_index,
              data: attributes,
              errors: record.errors.full_messages
            }
          end
        end
      end
    end

    # 完了時の処理
    handle_completion(result, options)
  end

  # ファイル形式を検出
  def detect_format(file_path)
    extension = File.extname(file_path).downcase
    case extension
    when '.csv'
      :csv
    when '.json'
      :json
    when '.xml'
      :xml
    when '.xlsx', '.xls'
      :excel
    else
      :unknown
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

  # 属性をフォーマット
  def format_attributes(attributes, model_class)
    formatted = {}

    # 文字列のキーをシンボルに変換
    attributes = attributes.symbolize_keys if attributes.respond_to?(:symbolize_keys)

    # マッピングが指定されている場合
    if attributes[:mapping].present?
      mapping = attributes[:mapping]
      attributes.each do |key, value|
        formatted_key = mapping[key] || key
        formatted[formatted_key] = value
      end
    else
      # モデルの属性に存在するもののみを抽出
      attributes.each do |key, value|
        if model_class.column_names.include?(key.to_s)
          formatted[key] = value
        end
      end
    end

    # 日付や時間の属性を変換
    formatted.each do |key, value|
      column = model_class.columns_hash[key.to_s]
      if column && [:date, :datetime, :time].include?(column.type) && value.is_a?(String)
        begin
          case column.type
          when :date
            formatted[key] = Date.parse(value)
          when :datetime
            formatted[key] = Time.zone.parse(value)
          when :time
            formatted[key] = Time.zone.parse(value)
          end
        rescue ArgumentError
          # 変換に失敗した場合は元の値を使用
        end
      end
    end

    formatted
  end

  # レコードを検索または初期化
  def find_or_initialize_record(model_class, attributes, options)
    # 一意キーが指定されている場合
    if options[:unique_key].present?
      unique_key = options[:unique_key].to_sym
      if attributes[unique_key].present?
        record = model_class.find_or_initialize_by(unique_key => attributes[unique_key])
        record.assign_attributes(attributes)
        record
      else
        model_class.new(attributes)
      end
    # 複合一意キーが指定されている場合
    elsif options[:unique_keys].present?
      unique_keys = options[:unique_keys].map(&:to_sym)
      conditions = {}
      unique_keys.each do |key|
        conditions[key] = attributes[key] if attributes[key].present?
      end

      if conditions.present?
        record = model_class.find_or_initialize_by(conditions)
        record.assign_attributes(attributes)
        record
      else
        model_class.new(attributes)
      end
    # 常に新規作成する場合
    else
      model_class.new(attributes)
    end
  end

  # エラー処理
  def handle_error(message, options, exception = nil)
    # エラーをログに記録
    Rails.logger.error("DataImportJob Error: #{message}")
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
        event_type: 'data_import_error',
        message: message,
        details: {
          file_path: options[:file_path],
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
        notification_type: 'data_import_error',
        title: 'Data Import Error',
        message: message,
        reference_type: 'DataImport',
        reference_id: nil
      )
    end
  end

  # 完了時の処理
  def handle_completion(result, options)
    # 結果をログに記録
    Rails.logger.info("DataImportJob Completed: #{result.slice(:total, :imported, :updated, :failed).to_json}")

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
        event_type: 'data_import_completed',
        message: "Data import completed: #{result[:imported]} imported, #{result[:updated]} updated, #{result[:failed]} failed",
        details: {
          file_path: options[:file_path],
          model_class: options[:model_class].to_s,
          format: options[:format],
          user_id: options[:user_id],
          result: result.slice(:total, :imported, :updated, :skipped, :failed)
        }
      )
    end

    # 通知を送信
    if defined?(NotificationService) && options[:user_id].present?
      NotificationService.notify(
        recipient_type: 'user',
        recipient_id: options[:user_id],
        notification_type: 'data_import_completed',
        title: 'Data Import Completed',
        message: "Data import completed: #{result[:imported]} imported, #{result[:updated]} updated, #{result[:failed]} failed",
        reference_type: 'DataImport',
        reference_id: nil
      )
    end
  end
end
