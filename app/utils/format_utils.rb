module FormatUtils
  class << self
    # JSONデータをフォーマット
    def format_json(data, pretty = true)
      return '{}' if data.nil?

      begin
        if pretty
          JSON.pretty_generate(data)
        else
          data.to_json
        end
      rescue
        '{}'
      end
    end

    # XMLデータをフォーマット
    def format_xml(data, root = 'root')
      return "<#{root}></#{root}>" if data.nil?

      begin
        data.to_xml(root: root)
      rescue
        "<#{root}></#{root}>"
      end
    end

    # CSVデータをフォーマット
    def format_csv(data, headers = true)
      return '' if data.nil? || !data.is_a?(Array) || data.empty?

      begin
        CSV.generate(headers: headers) do |csv|
          data.each do |row|
            csv << row
          end
        end
      rescue
        ''
      end
    end

    # YAMLデータをフォーマット
    def format_yaml(data)
      return '' if data.nil?

      begin
        data.to_yaml
      rescue
        ''
      end
    end

    # ハッシュをクエリ文字列に変換
    def to_query_string(hash)
      return '' if hash.nil? || !hash.is_a?(Hash) || hash.empty?

      hash.map { |k, v| "#{URI.encode_www_form_component(k.to_s)}=#{URI.encode_www_form_component(v.to_s)}" }.join('&')
    end

    # クエリ文字列をハッシュに変換
    def from_query_string(query_string)
      return {} if query_string.nil? || query_string.empty?

      result = {}
      query_string.split('&').each do |pair|
        key, value = pair.split('=')
        result[URI.decode_www_form_component(key)] = URI.decode_www_form_component(value || '')
      end
      result
    end

    # Base64エンコード
    def base64_encode(data)
      return '' if data.nil?

      Base64.strict_encode64(data.to_s)
    end

    # Base64デコード
    def base64_decode(data)
      return '' if data.nil?

      begin
        Base64.strict_decode64(data.to_s)
      rescue
        ''
      end
    end

    # HTMLエスケープ
    def html_escape(text)
      return '' if text.nil?

      CGI.escapeHTML(text.to_s)
    end

    # HTMLアンエスケープ
    def html_unescape(text)
      return '' if text.nil?

      CGI.unescapeHTML(text.to_s)
    end

    # URLエンコード
    def url_encode(text)
      return '' if text.nil?

      URI.encode_www_form_component(text.to_s)
    end

    # URLデコード
    def url_decode(text)
      return '' if text.nil?

      URI.decode_www_form_component(text.to_s)
    end

    # 文字列を指定された長さに切り詰め
    def truncate(text, length = 30, omission = '...')
      return '' if text.nil?

      text = text.to_s
      if text.length > length
        text[0...(length - omission.length)] + omission
      else
        text
      end
    end

    # 数値をフォーマット
    def format_number(number, precision = 2, delimiter = ',', separator = '.')
      return '0' if number.nil?

      begin
        whole, decimal = number.to_s.split('.')
        whole_with_delimiter = whole.gsub(/(\d)(?=(\d{3})+(?!\d))/, "\\1#{delimiter}")

        if decimal.nil? || precision == 0
          whole_with_delimiter
        else
          decimal = decimal.ljust(precision, '0')[0, precision]
          "#{whole_with_delimiter}#{separator}#{decimal}"
        end
      rescue
        '0'
      end
    end

    # 日付をフォーマット
    def format_date(date, format = '%Y-%m-%d')
      return '' if date.nil?

      begin
        date = Date.parse(date.to_s) unless date.is_a?(Date) || date.is_a?(Time) || date.is_a?(DateTime)
        date.strftime(format)
      rescue
        ''
      end
    end

    # 日時をフォーマット
    def format_datetime(datetime, format = '%Y-%m-%d %H:%M:%S')
      return '' if datetime.nil?

      begin
        datetime = Time.parse(datetime.to_s) unless datetime.is_a?(Time) || datetime.is_a?(DateTime)
        datetime.strftime(format)
      rescue
        ''
      end
    end

    # 通貨をフォーマット
    def format_currency(amount, currency = 'JPY', precision = 0)
      return '¥0' if amount.nil?

      symbol = case currency
               when 'JPY' then '¥'
               when 'USD' then '$'
               when 'EUR' then '€'
               when 'GBP' then '£'
               else '¥'
               end

      "#{symbol}#{format_number(amount, precision)}"
    end

    # パーセンテージをフォーマット
    def format_percentage(number, precision = 2)
      return '0%' if number.nil?

      "#{format_number(number, precision)}%"
    end

    # 電話番号をフォーマット
    def format_phone(phone, country_code = 'JP')
      return '' if phone.nil?

      phone = phone.to_s.gsub(/[^\d]/, '')

      case country_code
      when 'JP' # 日本
        if phone.length == 10
          "#{phone[0..1]}-#{phone[2..5]}-#{phone[6..9]}"
        elsif phone.length == 11
          "#{phone[0..2]}-#{phone[3..6]}-#{phone[7..10]}"
        else
          phone
        end
      when 'US' # アメリカ
        if phone.length == 10
          "(#{phone[0..2]}) #{phone[3..5]}-#{phone[6..9]}"
        else
          phone
        end
      else
        phone
      end
    end

    # 郵便番号をフォーマット
    def format_postal_code(postal_code, country_code = 'JP')
      return '' if postal_code.nil?

      postal_code = postal_code.to_s.gsub(/[^\d]/, '')

      case country_code
      when 'JP' # 日本
        if postal_code.length == 7
          "#{postal_code[0..2]}-#{postal_code[3..6]}"
        else
          postal_code
        end
      when 'US' # アメリカ
        if postal_code.length == 9
          "#{postal_code[0..4]}-#{postal_code[5..8]}"
        else
          postal_code
        end
      else
        postal_code
      end
    end
  end
end
