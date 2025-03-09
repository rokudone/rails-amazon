require 'nokogiri'

module XmlUtils
  class << self
    # XMLデータを生成
    def generate_xml(data, root = 'root')
      return "<#{root}></#{root}>" if data.nil?

      begin
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.send(root) do
            build_xml(xml, data)
          end
        end

        builder.to_xml
      rescue => e
        puts "Error generating XML: #{e.message}"
        "<#{root}></#{root}>"
      end
    end

    # XML文字列を解析
    def parse_xml(xml_string)
      return nil if xml_string.nil? || xml_string.empty?

      begin
        doc = Nokogiri::XML(xml_string)
        doc.errors.empty? ? doc : nil
      rescue => e
        puts "Error parsing XML: #{e.message}"
        nil
      end
    end

    # XMLファイルを解析
    def parse_xml_file(file_path)
      return nil unless File.exist?(file_path)

      begin
        doc = Nokogiri::XML(File.read(file_path))
        doc.errors.empty? ? doc : nil
      rescue => e
        puts "Error parsing XML file: #{e.message}"
        nil
      end
    end

    # XMLをファイルに保存
    def save_xml_to_file(xml_data, file_path)
      return false if xml_data.nil? || file_path.nil? || file_path.empty?

      begin
        # XMLオブジェクトの場合はto_xmlを呼び出す
        xml_string = xml_data.is_a?(Nokogiri::XML::Document) ? xml_data.to_xml : xml_data.to_s

        File.write(file_path, xml_string)
        true
      rescue => e
        puts "Error saving XML to file: #{e.message}"
        false
      end
    end

    # XMLスキーマ検証
    def validate_schema(xml_data, schema_path)
      return false if xml_data.nil? || schema_path.nil? || !File.exist?(schema_path)

      begin
        # XMLオブジェクトでない場合はパース
        doc = xml_data.is_a?(Nokogiri::XML::Document) ? xml_data : Nokogiri::XML(xml_data)

        # スキーマを読み込む
        schema = Nokogiri::XML::Schema(File.read(schema_path))

        # 検証
        errors = schema.validate(doc)

        if errors.empty?
          true
        else
          errors.each { |error| puts "Schema validation error: #{error.message}" }
          false
        end
      rescue => e
        puts "Error validating XML schema: #{e.message}"
        false
      end
    end

    # XMLをハッシュに変換
    def xml_to_hash(xml_data)
      return {} if xml_data.nil?

      begin
        # XMLオブジェクトでない場合はパース
        doc = xml_data.is_a?(Nokogiri::XML::Document) ? xml_data : Nokogiri::XML(xml_data)

        # ルート要素を取得
        root = doc.root

        # ハッシュに変換
        node_to_hash(root)
      rescue => e
        puts "Error converting XML to hash: #{e.message}"
        {}
      end
    end

    # XMLをJSONに変換
    def xml_to_json(xml_data, pretty = true)
      hash = xml_to_hash(xml_data)

      begin
        if pretty
          JSON.pretty_generate(hash)
        else
          hash.to_json
        end
      rescue => e
        puts "Error converting XML to JSON: #{e.message}"
        '{}'
      end
    end

    # XMLをCSVに変換（シンプルな構造のXMLのみ対応）
    def xml_to_csv(xml_data, row_xpath, column_xpaths, headers = nil)
      return nil if xml_data.nil? || row_xpath.nil? || column_xpaths.nil?

      begin
        # XMLオブジェクトでない場合はパース
        doc = xml_data.is_a?(Nokogiri::XML::Document) ? xml_data : Nokogiri::XML(xml_data)

        # 行要素を取得
        rows = doc.xpath(row_xpath)

        # CSVデータを生成
        csv_data = []

        # ヘッダー行を追加
        csv_data << (headers || column_xpaths.map { |xpath| xpath.split('/').last }) if headers || column_xpaths.any?

        # データ行を追加
        rows.each do |row|
          csv_row = column_xpaths.map do |xpath|
            # 相対パスの場合は行要素からの相対パス、絶対パスの場合はドキュメントルートからのパス
            if xpath.start_with?('/')
              doc.at_xpath(xpath)&.text
            else
              row.at_xpath(xpath)&.text
            end
          end

          csv_data << csv_row
        end

        # CSVを生成
        CSV.generate do |csv|
          csv_data.each do |row|
            csv << row
          end
        end
      rescue => e
        puts "Error converting XML to CSV: #{e.message}"
        nil
      end
    end

    # XPathで要素を取得
    def get_elements_by_xpath(xml_data, xpath)
      return [] if xml_data.nil? || xpath.nil?

      begin
        # XMLオブジェクトでない場合はパース
        doc = xml_data.is_a?(Nokogiri::XML::Document) ? xml_data : Nokogiri::XML(xml_data)

        # XPathで要素を取得
        doc.xpath(xpath)
      rescue => e
        puts "Error getting elements by XPath: #{e.message}"
        []
      end
    end

    # XPathで要素のテキストを取得
    def get_text_by_xpath(xml_data, xpath)
      return nil if xml_data.nil? || xpath.nil?

      begin
        # XMLオブジェクトでない場合はパース
        doc = xml_data.is_a?(Nokogiri::XML::Document) ? xml_data : Nokogiri::XML(xml_data)

        # XPathで要素を取得
        element = doc.at_xpath(xpath)

        # テキストを取得
        element&.text
      rescue => e
        puts "Error getting text by XPath: #{e.message}"
        nil
      end
    end

    # XPathで要素の属性を取得
    def get_attribute_by_xpath(xml_data, xpath, attribute)
      return nil if xml_data.nil? || xpath.nil? || attribute.nil?

      begin
        # XMLオブジェクトでない場合はパース
        doc = xml_data.is_a?(Nokogiri::XML::Document) ? xml_data : Nokogiri::XML(xml_data)

        # XPathで要素を取得
        element = doc.at_xpath(xpath)

        # 属性を取得
        element&.[](attribute)
      rescue => e
        puts "Error getting attribute by XPath: #{e.message}"
        nil
      end
    end

    # XPathで要素を更新
    def update_element_by_xpath(xml_data, xpath, value)
      return xml_data if xml_data.nil? || xpath.nil?

      begin
        # XMLオブジェクトでない場合はパース
        doc = xml_data.is_a?(Nokogiri::XML::Document) ? xml_data : Nokogiri::XML(xml_data)

        # XPathで要素を取得
        element = doc.at_xpath(xpath)

        # 要素を更新
        element.content = value if element

        doc
      rescue => e
        puts "Error updating element by XPath: #{e.message}"
        xml_data
      end
    end

    # XPathで属性を更新
    def update_attribute_by_xpath(xml_data, xpath, attribute, value)
      return xml_data if xml_data.nil? || xpath.nil? || attribute.nil?

      begin
        # XMLオブジェクトでない場合はパース
        doc = xml_data.is_a?(Nokogiri::XML::Document) ? xml_data : Nokogiri::XML(xml_data)

        # XPathで要素を取得
        element = doc.at_xpath(xpath)

        # 属性を更新
        element[attribute] = value if element

        doc
      rescue => e
        puts "Error updating attribute by XPath: #{e.message}"
        xml_data
      end
    end

    # XPathで要素を削除
    def remove_element_by_xpath(xml_data, xpath)
      return xml_data if xml_data.nil? || xpath.nil?

      begin
        # XMLオブジェクトでない場合はパース
        doc = xml_data.is_a?(Nokogiri::XML::Document) ? xml_data : Nokogiri::XML(xml_data)

        # XPathで要素を取得
        elements = doc.xpath(xpath)

        # 要素を削除
        elements.each(&:remove)

        doc
      rescue => e
        puts "Error removing element by XPath: #{e.message}"
        xml_data
      end
    end

    # XPathで要素を追加
    def add_element_by_xpath(xml_data, parent_xpath, element_name, content = nil, attributes = {})
      return xml_data if xml_data.nil? || parent_xpath.nil? || element_name.nil?

      begin
        # XMLオブジェクトでない場合はパース
        doc = xml_data.is_a?(Nokogiri::XML::Document) ? xml_data : Nokogiri::XML(xml_data)

        # 親要素を取得
        parent = doc.at_xpath(parent_xpath)

        if parent
          # 新しい要素を作成
          new_element = Nokogiri::XML::Node.new(element_name, doc)

          # コンテンツを設定
          new_element.content = content if content

          # 属性を設定
          attributes.each do |name, value|
            new_element[name.to_s] = value
          end

          # 親要素に追加
          parent.add_child(new_element)
        end

        doc
      rescue => e
        puts "Error adding element by XPath: #{e.message}"
        xml_data
      end
    end

    # XMLを整形
    def format_xml(xml_data)
      return xml_data if xml_data.nil?

      begin
        # XMLオブジェクトでない場合はパース
        doc = xml_data.is_a?(Nokogiri::XML::Document) ? xml_data : Nokogiri::XML(xml_data)

        # 整形
        doc.to_xml(indent: 2)
      rescue => e
        puts "Error formatting XML: #{e.message}"
        xml_data
      end
    end

    # XMLの名前空間を取得
    def get_namespaces(xml_data)
      return {} if xml_data.nil?

      begin
        # XMLオブジェクトでない場合はパース
        doc = xml_data.is_a?(Nokogiri::XML::Document) ? xml_data : Nokogiri::XML(xml_data)

        # 名前空間を取得
        doc.collect_namespaces
      rescue => e
        puts "Error getting XML namespaces: #{e.message}"
        {}
      end
    end

    private

    # XMLの構築
    def build_xml(xml, data)
      case data
      when Hash
        data.each do |k, v|
          if v.nil?
            xml.send(k)
          elsif v.is_a?(Array)
            v.each do |item|
              xml.send(k) do
                build_xml(xml, item)
              end
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

    # ノードをハッシュに変換
    def node_to_hash(node)
      # テキストノードの場合
      return node.text if node.text? || node.cdata?

      # 要素ノードの場合
      hash = {}

      # 属性を追加
      node.attributes.each do |name, attr|
        hash["@#{name}"] = attr.value
      end

      # 子ノードを処理
      node.children.each do |child|
        # テキストノードや空白ノードはスキップ
        next if child.text? && child.text.strip.empty?

        child_result = node_to_hash(child)

        if child.element?
          # 同じ名前の要素が複数ある場合は配列に
          if hash[child.name]
            hash[child.name] = [hash[child.name]] unless hash[child.name].is_a?(Array)
            hash[child.name] << child_result
          else
            hash[child.name] = child_result
          end
        elsif child.text? || child.cdata?
          # テキストノードの場合は特別なキーに
          hash["#text"] = child.text.strip
        end
      end

      # 子要素がなく、テキストのみの場合は単純化
      if hash.size == 1 && hash.key?("#text")
        hash["#text"]
      else
        hash
      end
    end
  end
end
