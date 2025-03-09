module Exportable
  extend ActiveSupport::Concern

  included do
    # エクスポート設定を定義するクラス変数
    class_attribute :export_options, default: {}
    class_attribute :export_columns, default: []
    class_attribute :export_methods, default: {}
    class_attribute :export_formatters, default: {}
  end

  class_methods do
    # エクスポート設定を構成
    def configure_export(options = {})
      self.export_options = {
        include_header: true,
        batch_size: 1000,
        format: :csv
      }.merge(options)
    end

    # エクスポート列を設定
    def export_column(*columns)
      self.export_columns = columns
    end

    # エクスポートメソッドを設定
    def export_method(column, method)
      self.export_methods = export_methods.merge(column => method)
    end

    # エクスポートフォーマッタを設定
    def export_formatter(column, formatter)
      self.export_formatters = export_formatters.merge(column => formatter)
    end

    # CSVにエクスポート
    def export_to_csv(scope = nil, options = {})
      require 'csv'

      # オプションをマージ
      export_options_with_overrides = export_options.merge(options)

      # 列を取得
      columns = export_options_with_overrides[:columns] || export_columns

      # 列が指定されていない場合はモデルの属性を使用
      columns = column_names.map(&:to_sym) if columns.blank?

      # CSVを生成
      CSV.generate(export_options_with_overrides[:csv_options] || {}) do |csv|
        # ヘッダー行を追加
        if export_options_with_overrides[:include_header]
          header_row = columns.map { |column| format_header(column) }
          csv << header_row
        end

        # レコードを取得
        records = scope || all

        # バッチサイズを取得
        batch_size = export_options_with_overrides[:batch_size] || 1000

        # バッチ処理
        records.find_each(batch_size: batch_size) do |record|
          # レコードをエクスポート
          row = export_record(record, columns, export_options_with_overrides)
          csv << row
        end
      end
    end

    # JSONにエクスポート
    def export_to_json(scope = nil, options = {})
      # オプションをマージ
      export_options_with_overrides = export_options.merge(options)

      # 列を取得
      columns = export_options_with_overrides[:columns] || export_columns

      # 列が指定されていない場合はモデルの属性を使用
      columns = column_names.map(&:to_sym) if columns.blank?

      # レコードを取得
      records = scope || all

      # バッチサイズを取得
      batch_size = export_options_with_overrides[:batch_size] || 1000

      # 結果を初期化
      result = []

      # バッチ処理
      records.find_each(batch_size: batch_size) do |record|
        # レコードをエクスポート
        row = {}
        columns.each do |column|
          row[column.to_s] = get_column_value(record, column, export_options_with_overrides)
        end
        result << row
      end

      # JSONに変換
      result.to_json
    end

    # XMLにエクスポート
    def export_to_xml(scope = nil, options = {})
      # オプションをマージ
      export_options_with_overrides = export_options.merge(options)

      # 列を取得
      columns = export_options_with_overrides[:columns] || export_columns

      # 列が指定されていない場合はモデルの属性を使用
      columns = column_names.map(&:to_sym) if columns.blank?

      # レコードを取得
      records = scope || all

      # ルート要素名を取得
      root = export_options_with_overrides[:root] || model_name.plural

      # レコード要素名を取得
      record_name = export_options_with_overrides[:record_name] || model_name.element

      # XMLを生成
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.send(root) do
          # バッチサイズを取得
          batch_size = export_options_with_overrides[:batch_size] || 1000

          # バッチ処理
          records.find_each(batch_size: batch_size) do |record|
            xml.send(record_name) do
              columns.each do |column|
                value = get_column_value(record, column, export_options_with_overrides)
                xml.send(column, value)
              end
            end
          end
        end
      end

      builder.to_xml
    end

    # Excelにエクスポート
    def export_to_excel(scope = nil, options = {})
      require 'axlsx'

      # オプションをマージ
      export_options_with_overrides = export_options.merge(options)

      # 列を取得
      columns = export_options_with_overrides[:columns] || export_columns

      # 列が指定されていない場合はモデルの属性を使用
      columns = column_names.map(&:to_sym) if columns.blank?

      # Excelパッケージを作成
      package = Axlsx::Package.new
      workbook = package.workbook

      # シート名を取得
      sheet_name = export_options_with_overrides[:sheet_name] || model_name.plural

      # シートを追加
      workbook.add_worksheet(name: sheet_name) do |sheet|
        # スタイルを設定
        styles = workbook.styles
        header_style = styles.add_style(b: true, bg_color: "DDDDDD")

        # ヘッダー行を追加
        if export_options_with_overrides[:include_header]
          header_row = columns.map { |column| format_header(column) }
          sheet.add_row header_row, style: header_style
        end

        # レコードを取得
        records = scope || all

        # バッチサイズを取得
        batch_size = export_options_with_overrides[:batch_size] || 1000

        # バッチ処理
        records.find_each(batch_size: batch_size) do |record|
          # レコードをエクスポート
          row = export_record(record, columns, export_options_with_overrides)
          sheet.add_row row
        end
      end

      # 一時ファイルに保存
      temp_file = Tempfile.new([model_name.plural, '.xlsx'])
      package.serialize(temp_file.path)

      # ファイルパスを返す
      temp_file.path
    end

    # レコードをエクスポート
    def export_record(record, columns, options = {})
      columns.map do |column|
        get_column_value(record, column, options)
      end
    end

    # 列の値を取得
    def get_column_value(record, column, options = {})
      # カスタムメソッドが定義されている場合
      if export_methods[column].present?
        method = export_methods[column]

        # メソッドがProcの場合
        if method.is_a?(Proc)
          value = method.call(record)
        # メソッドがシンボルまたは文字列の場合
        else
          value = record.send(method)
        end
      # 列名がメソッドとして存在する場合
      elsif record.respond_to?(column)
        value = record.send(column)
      # 関連付けとして存在する場合
      elsif column.to_s.include?('.')
        association, attr = column.to_s.split('.', 2)
        related = record.send(association)
        value = related.respond_to?(attr) ? related.send(attr) : nil
      else
        value = nil
      end

      # フォーマッタが定義されている場合
      if export_formatters[column].present?
        formatter = export_formatters[column]

        # フォーマッタがProcの場合
        if formatter.is_a?(Proc)
          value = formatter.call(value, record)
        # フォーマッタがシンボルまたは文字列の場合
        else
          value = record.send(formatter, value)
        end
      end

      value
    end

    # ヘッダーをフォーマット
    def format_header(column)
      # カスタムヘッダーが定義されている場合
      if export_options[:headers].is_a?(Hash) && export_options[:headers][column].present?
        export_options[:headers][column]
      # 関連付けの場合
      elsif column.to_s.include?('.')
        column.to_s.humanize
      else
        # 人間が読みやすい形式に変換
        column.to_s.humanize
      end
    end
  end

  # インスタンスメソッド

  # レコードをCSVにエクスポート
  def to_csv(options = {})
    self.class.export_to_csv(self.class.where(id: id), options)
  end

  # レコードをJSONにエクスポート
  def to_export_json(options = {})
    self.class.export_to_json(self.class.where(id: id), options)
  end

  # レコードをXMLにエクスポート
  def to_export_xml(options = {})
    self.class.export_to_xml(self.class.where(id: id), options)
  end
end
