require 'json'

module JsonUtils
  class << self
    # JSONデータを生成
    def generate_json(data, pretty = true)
      return '{}' if data.nil?

      begin
        if pretty
          JSON.pretty_generate(data)
        else
          data.to_json
        end
      rescue => e
        puts "Error generating JSON: #{e.message}"
        '{}'
      end
    end

    # JSON文字列を解析
    def parse_json(json_string)
      return nil if json_string.nil? || json_string.empty?

      begin
        JSON.parse(json_string)
      rescue => e
        puts "Error parsing JSON: #{e.message}"
        nil
      end
    end

    # JSONファイルを解析
    def parse_json_file(file_path)
      return nil unless File.exist?(file_path)

      begin
        json_string = File.read(file_path)
        JSON.parse(json_string)
      rescue => e
        puts "Error parsing JSON file: #{e.message}"
        nil
      end
    end

    # JSONをファイルに保存
    def save_json_to_file(data, file_path, pretty = true)
      return false if data.nil? || file_path.nil? || file_path.empty?

      begin
        json_string = generate_json(data, pretty)
        File.write(file_path, json_string)
        true
      rescue => e
        puts "Error saving JSON to file: #{e.message}"
        false
      end
    end

    # JSONスキーマ検証
    def validate_schema(data, schema)
      return false if data.nil? || schema.nil?

      # 実際のアプリケーションでは、json-schema gemなどを使用
      # ここでは簡易的な検証のみ実装

      begin
        # スキーマが文字列の場合はJSONとして解析
        schema = JSON.parse(schema) if schema.is_a?(String)

        # データが文字列の場合はJSONとして解析
        data = JSON.parse(data) if data.is_a?(String)

        # 簡易的なスキーマ検証
        validate_object(data, schema)
      rescue => e
        puts "Error validating JSON schema: #{e.message}"
        false
      end
    end

    # JSONをマージ
    def merge_json(json1, json2)
      return json2 if json1.nil?
      return json1 if json2.nil?

      begin
        # 文字列の場合はJSONとして解析
        json1 = JSON.parse(json1) if json1.is_a?(String)
        json2 = JSON.parse(json2) if json2.is_a?(String)

        # ハッシュの場合は深いマージを実行
        if json1.is_a?(Hash) && json2.is_a?(Hash)
          deep_merge(json1, json2)
        elsif json1.is_a?(Array) && json2.is_a?(Array)
          json1 + json2
        else
          json2
        end
      rescue => e
        puts "Error merging JSON: #{e.message}"
        nil
      end
    end

    # JSONの差分を取得
    def diff_json(json1, json2)
      return {} if json1.nil? && json2.nil?
      return json2 if json1.nil?
      return { _removed: json1 } if json2.nil?

      begin
        # 文字列の場合はJSONとして解析
        json1 = JSON.parse(json1) if json1.is_a?(String)
        json2 = JSON.parse(json2) if json2.is_a?(String)

        # ハッシュの場合は差分を計算
        if json1.is_a?(Hash) && json2.is_a?(Hash)
          diff_hash(json1, json2)
        elsif json1.is_a?(Array) && json2.is_a?(Array)
          diff_array(json1, json2)
        else
          json1 == json2 ? {} : json2
        end
      rescue => e
        puts "Error calculating JSON diff: #{e.message}"
        nil
      end
    end

    # JSONをフラット化
    def flatten_json(json, delimiter = '.')
      return {} if json.nil?

      begin
        # 文字列の場合はJSONとして解析
        json = JSON.parse(json) if json.is_a?(String)

        # ハッシュの場合はフラット化
        if json.is_a?(Hash)
          flatten_hash(json, '', delimiter)
        else
          json
        end
      rescue => e
        puts "Error flattening JSON: #{e.message}"
        nil
      end
    end

    # JSONをCSVに変換
    def json_to_csv(json_data, options = {})
      return nil if json_data.nil?

      begin
        # 文字列の場合はJSONとして解析
        data = json_data.is_a?(String) ? JSON.parse(json_data) : json_data

        # 配列でない場合は配列に変換
        data = [data] unless data.is_a?(Array)

        # 空の配列の場合は空文字列を返す
        return '' if data.empty?

        # ヘッダーを取得
        headers = data.first.keys

        # CSVを生成
        CSV.generate(options) do |csv|
          csv << headers
          data.each do |row|
            csv << headers.map { |header| row[header] }
          end
        end
      rescue => e
        puts "Error converting JSON to CSV: #{e.message}"
        nil
      end
    end

    # JSONをXMLに変換
    def json_to_xml(json_data, root = 'root')
      return "<#{root}></#{root}>" if json_data.nil?

      begin
        # 文字列の場合はJSONとして解析
        data = json_data.is_a?(String) ? JSON.parse(json_data) : json_data

        # XMLを生成
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.send(root) do
            build_xml(xml, data)
          end
        end

        builder.to_xml
      rescue => e
        puts "Error converting JSON to XML: #{e.message}"
        "<#{root}></#{root}>"
      end
    end

    # JSONをYAMLに変換
    def json_to_yaml(json_data)
      return '' if json_data.nil?

      begin
        # 文字列の場合はJSONとして解析
        data = json_data.is_a?(String) ? JSON.parse(json_data) : json_data

        # YAMLに変換
        data.to_yaml
      rescue => e
        puts "Error converting JSON to YAML: #{e.message}"
        nil
      end
    end

    # JSONパスで値を取得
    def get_value_by_path(json_data, path)
      return nil if json_data.nil? || path.nil? || path.empty?

      begin
        # 文字列の場合はJSONとして解析
        data = json_data.is_a?(String) ? JSON.parse(json_data) : json_data

        # パスを分割
        keys = path.split('.')

        # パスに沿って値を取得
        result = data
        keys.each do |key|
          if result.is_a?(Hash)
            result = result[key] || result[key.to_sym]
          elsif result.is_a?(Array) && key =~ /^\d+$/
            result = result[key.to_i]
          else
            return nil
          end
        end

        result
      rescue => e
        puts "Error getting value by path: #{e.message}"
        nil
      end
    end

    # JSONパスで値を設定
    def set_value_by_path(json_data, path, value)
      return json_data if json_data.nil? || path.nil? || path.empty?

      begin
        # 文字列の場合はJSONとして解析
        data = json_data.is_a?(String) ? JSON.parse(json_data) : json_data.dup

        # パスを分割
        keys = path.split('.')

        # 最後のキーを取得
        last_key = keys.pop

        # パスに沿って進む
        current = data
        keys.each do |key|
          if current.is_a?(Hash)
            current[key] ||= {}
            current = current[key]
          elsif current.is_a?(Array) && key =~ /^\d+$/
            index = key.to_i
            current[index] ||= {}
            current = current[index]
          else
            return json_data
          end
        end

        # 値を設定
        if current.is_a?(Hash)
          current[last_key] = value
        elsif current.is_a?(Array) && last_key =~ /^\d+$/
          current[last_key.to_i] = value
        end

        data
      rescue => e
        puts "Error setting value by path: #{e.message}"
        json_data
      end
    end

    private

    # オブジェクトのスキーマ検証
    def validate_object(data, schema)
      return true if schema.nil?

      # 型の検証
      if schema['type']
        case schema['type']
        when 'object'
          return false unless data.is_a?(Hash)
        when 'array'
          return false unless data.is_a?(Array)
        when 'string'
          return false unless data.is_a?(String)
        when 'number'
          return false unless data.is_a?(Numeric)
        when 'boolean'
          return false unless [true, false].include?(data)
        when 'null'
          return false unless data.nil?
        end
      end

      # プロパティの検証
      if schema['properties'] && data.is_a?(Hash)
        schema['properties'].each do |prop_name, prop_schema|
          if data.key?(prop_name)
            return false unless validate_object(data[prop_name], prop_schema)
          elsif schema['required'] && schema['required'].include?(prop_name)
            return false
          end
        end
      end

      # 配列アイテムの検証
      if schema['items'] && data.is_a?(Array)
        data.each do |item|
          return false unless validate_object(item, schema['items'])
        end
      end

      true
    end

    # ハッシュの深いマージ
    def deep_merge(hash1, hash2)
      hash1.merge(hash2) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge(old_val, new_val)
        elsif old_val.is_a?(Array) && new_val.is_a?(Array)
          old_val + new_val
        else
          new_val
        end
      end
    end

    # ハッシュの差分計算
    def diff_hash(hash1, hash2)
      diff = {}

      # hash1にあってhash2にない、または値が異なるキー
      hash1.each do |k, v|
        if !hash2.key?(k)
          diff[k] = { _removed: v }
        elsif hash2[k] != v
          if v.is_a?(Hash) && hash2[k].is_a?(Hash)
            diff[k] = diff_hash(v, hash2[k])
          elsif v.is_a?(Array) && hash2[k].is_a?(Array)
            diff[k] = diff_array(v, hash2[k])
          else
            diff[k] = hash2[k]
          end
        end
      end

      # hash2にあってhash1にないキー
      hash2.each do |k, v|
        diff[k] = v unless hash1.key?(k)
      end

      diff
    end

    # 配列の差分計算
    def diff_array(array1, array2)
      # 簡易的な実装
      array1 == array2 ? [] : array2
    end

    # ハッシュのフラット化
    def flatten_hash(hash, prefix = '', delimiter = '.')
      hash.each_with_object({}) do |(k, v), h|
        key = prefix.empty? ? k.to_s : "#{prefix}#{delimiter}#{k}"

        if v.is_a?(Hash)
          h.merge!(flatten_hash(v, key, delimiter))
        else
          h[key] = v
        end
      end
    end

    # XMLの構築
    def build_xml(xml, data)
      case data
      when Hash
        data.each do |k, v|
          if v.nil?
            xml.send(k)
          elsif v.is_a?(Array)
            xml.send(k) do
              v.each { |item| build_xml(xml, item) }
            end
          elsif v.is_a?(Hash)
            xml.send(k) do
              build_xml(xml, v)
            end
          else
            xml.send(k, v.to_s)
          end
        end
      when Array
        data.each { |item| build_xml(xml, item) }
      else
        xml.text(data.to_s)
      end
    end
  end
end
