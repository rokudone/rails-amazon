require 'csv'

module CsvUtils
  class << self
    # CSVデータを生成
    def generate_csv(data, headers = nil, options = {})
      return nil if data.nil? || !data.is_a?(Array) || data.empty?

      default_options = {
        col_sep: ',',
        row_sep: "\n",
        quote_char: '"',
        force_quotes: false
      }

      options = default_options.merge(options)

      CSV.generate(options) do |csv|
        csv << headers if headers.is_a?(Array) && !headers.empty?
        data.each do |row|
          csv << row
        end
      end
    end

    # CSVファイルを解析
    def parse_csv(file_path, options = {})
      return nil unless File.exist?(file_path)

      default_options = {
        headers: true,
        header_converters: :symbol,
        converters: :all,
        col_sep: ',',
        quote_char: '"'
      }

      options = default_options.merge(options)

      begin
        CSV.read(file_path, options)
      rescue => e
        puts "Error parsing CSV file: #{e.message}"
        nil
      end
    end

    # CSVデータを解析
    def parse_csv_data(csv_data, options = {})
      return nil if csv_data.nil? || csv_data.empty?

      default_options = {
        headers: true,
        header_converters: :symbol,
        converters: :all,
        col_sep: ',',
        quote_char: '"'
      }

      options = default_options.merge(options)

      begin
        CSV.parse(csv_data, options)
      rescue => e
        puts "Error parsing CSV data: #{e.message}"
        nil
      end
    end

    # CSVファイルをハッシュの配列に変換
    def csv_to_hash(file_path, options = {})
      return nil unless File.exist?(file_path)

      default_options = {
        headers: true,
        header_converters: :symbol,
        converters: :all,
        col_sep: ',',
        quote_char: '"'
      }

      options = default_options.merge(options)

      begin
        csv = CSV.read(file_path, options)
        csv.map(&:to_h)
      rescue => e
        puts "Error converting CSV to hash: #{e.message}"
        nil
      end
    end

    # ハッシュの配列をCSVに変換
    def hash_to_csv(data, options = {})
      return nil if data.nil? || !data.is_a?(Array) || data.empty? || !data.first.is_a?(Hash)

      default_options = {
        col_sep: ',',
        row_sep: "\n",
        quote_char: '"',
        force_quotes: false
      }

      options = default_options.merge(options)

      headers = data.first.keys

      CSV.generate(options) do |csv|
        csv << headers
        data.each do |hash|
          csv << headers.map { |header| hash[header] }
        end
      end
    end

    # CSVファイルをJSONに変換
    def csv_to_json(file_path, options = {})
      hash_data = csv_to_hash(file_path, options)
      return nil if hash_data.nil?

      begin
        JSON.generate(hash_data)
      rescue => e
        puts "Error converting CSV to JSON: #{e.message}"
        nil
      end
    end

    # JSONをCSVに変換
    def json_to_csv(json_data, options = {})
      return nil if json_data.nil? || json_data.empty?

      begin
        data = JSON.parse(json_data)
        return nil unless data.is_a?(Array) && !data.empty? && data.first.is_a?(Hash)

        hash_to_csv(data, options)
      rescue => e
        puts "Error converting JSON to CSV: #{e.message}"
        nil
      end
    end

    # CSVファイルの行数を取得
    def count_rows(file_path, include_header = false)
      return 0 unless File.exist?(file_path)

      begin
        count = 0
        CSV.foreach(file_path) { |_| count += 1 }
        include_header ? count : [0, count - 1].max
      rescue => e
        puts "Error counting CSV rows: #{e.message}"
        0
      end
    end

    # CSVファイルの列数を取得
    def count_columns(file_path)
      return 0 unless File.exist?(file_path)

      begin
        CSV.open(file_path) do |csv|
          row = csv.first
          return row ? row.size : 0
        end
      rescue => e
        puts "Error counting CSV columns: #{e.message}"
        0
      end
    end

    # CSVファイルのヘッダーを取得
    def get_headers(file_path, options = {})
      return nil unless File.exist?(file_path)

      default_options = {
        col_sep: ',',
        quote_char: '"'
      }

      options = default_options.merge(options)

      begin
        CSV.open(file_path, options) do |csv|
          return csv.first
        end
      rescue => e
        puts "Error getting CSV headers: #{e.message}"
        nil
      end
    end

    # CSVファイルの特定の列を取得
    def get_column(file_path, column_index_or_name, options = {})
      return nil unless File.exist?(file_path)

      default_options = {
        headers: true,
        header_converters: :symbol,
        converters: :all,
        col_sep: ',',
        quote_char: '"'
      }

      options = default_options.merge(options)

      begin
        column = []
        CSV.foreach(file_path, options) do |row|
          if column_index_or_name.is_a?(Integer)
            column << row[column_index_or_name]
          else
            column << row[column_index_or_name.to_sym]
          end
        end
        column
      rescue => e
        puts "Error getting CSV column: #{e.message}"
        nil
      end
    end

    # CSVファイルの特定の行を取得
    def get_row(file_path, row_index, options = {})
      return nil unless File.exist?(file_path)

      default_options = {
        col_sep: ',',
        quote_char: '"'
      }

      options = default_options.merge(options)

      begin
        rows = CSV.read(file_path, options)
        rows[row_index]
      rescue => e
        puts "Error getting CSV row: #{e.message}"
        nil
      end
    end

    # CSVファイルをフィルタリング
    def filter_csv(file_path, column_index_or_name, value, options = {})
      return nil unless File.exist?(file_path)

      default_options = {
        headers: true,
        header_converters: :symbol,
        converters: :all,
        col_sep: ',',
        quote_char: '"'
      }

      options = default_options.merge(options)

      begin
        filtered_data = []
        CSV.foreach(file_path, options) do |row|
          if column_index_or_name.is_a?(Integer)
            filtered_data << row.to_h if row[column_index_or_name] == value
          else
            filtered_data << row.to_h if row[column_index_or_name.to_sym] == value
          end
        end
        filtered_data
      rescue => e
        puts "Error filtering CSV: #{e.message}"
        nil
      end
    end

    # CSVファイルをソート
    def sort_csv(file_path, column_index_or_name, ascending = true, options = {})
      return nil unless File.exist?(file_path)

      default_options = {
        headers: true,
        header_converters: :symbol,
        converters: :all,
        col_sep: ',',
        quote_char: '"'
      }

      options = default_options.merge(options)

      begin
        data = CSV.read(file_path, options).map(&:to_h)

        if column_index_or_name.is_a?(Integer)
          headers = get_headers(file_path, options)
          column_name = headers[column_index_or_name].to_sym
        else
          column_name = column_index_or_name.to_sym
        end

        sorted_data = data.sort_by { |row| row[column_name] || '' }
        sorted_data.reverse! unless ascending

        sorted_data
      rescue => e
        puts "Error sorting CSV: #{e.message}"
        nil
      end
    end
  end
end
