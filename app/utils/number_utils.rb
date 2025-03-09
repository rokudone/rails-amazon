module NumberUtils
  class << self
    # 数値を指定された桁数でフォーマット
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

    # 通貨をフォーマット
    def format_currency(amount, currency = 'JPY', precision = 0, symbol = '¥')
      return "#{symbol}0" if amount.nil?

      formatted_amount = format_number(amount, precision)

      case currency
      when 'JPY'
        "#{symbol}#{formatted_amount}"
      when 'USD'
        "$#{formatted_amount}"
      when 'EUR'
        "€#{formatted_amount}"
      when 'GBP'
        "£#{formatted_amount}"
      else
        "#{symbol}#{formatted_amount}"
      end
    end

    # パーセンテージをフォーマット
    def format_percentage(number, precision = 2)
      return '0%' if number.nil?

      "#{format_number(number, precision)}%"
    end

    # 数値を四捨五入
    def round(number, precision = 0)
      return 0 if number.nil?

      number.to_f.round(precision)
    end

    # 数値を切り捨て
    def floor(number, precision = 0)
      return 0 if number.nil?

      factor = 10.0 ** precision
      (number.to_f * factor).floor / factor
    end

    # 数値を切り上げ
    def ceil(number, precision = 0)
      return 0 if number.nil?

      factor = 10.0 ** precision
      (number.to_f * factor).ceil / factor
    end

    # 単位変換: キログラムからポンド
    def kg_to_lb(kg)
      return 0 if kg.nil?

      kg.to_f * 2.20462
    end

    # 単位変換: ポンドからキログラム
    def lb_to_kg(lb)
      return 0 if lb.nil?

      lb.to_f / 2.20462
    end

    # 単位変換: キロメートルからマイル
    def km_to_miles(km)
      return 0 if km.nil?

      km.to_f * 0.621371
    end

    # 単位変換: マイルからキロメートル
    def miles_to_km(miles)
      return 0 if miles.nil?

      miles.to_f / 0.621371
    end

    # 単位変換: 摂氏から華氏
    def celsius_to_fahrenheit(celsius)
      return 0 if celsius.nil?

      (celsius.to_f * 9/5) + 32
    end

    # 単位変換: 華氏から摂氏
    def fahrenheit_to_celsius(fahrenheit)
      return 0 if fahrenheit.nil?

      (fahrenheit.to_f - 32) * 5/9
    end

    # 数値が範囲内にあるかどうかを確認
    def within_range?(number, min, max)
      return false if number.nil?

      number.to_f >= min && number.to_f <= max
    end

    # 数値を指定された範囲内に制限
    def clamp(number, min, max)
      return min if number.nil?

      [min, [number.to_f, max].min].max
    end

    # 数値を人間が読みやすい形式に変換（例: 1000 -> 1K, 1000000 -> 1M）
    def to_human_readable(number)
      return '0' if number.nil?

      number = number.to_f

      if number >= 1_000_000_000
        "#{format_number(number / 1_000_000_000, 1)}B"
      elsif number >= 1_000_000
        "#{format_number(number / 1_000_000, 1)}M"
      elsif number >= 1_000
        "#{format_number(number / 1_000, 1)}K"
      else
        format_number(number, 0)
      end
    end

    # 数値をバイト単位から人間が読みやすい形式に変換（例: 1024 -> 1KB, 1048576 -> 1MB）
    def bytes_to_human_readable(bytes)
      return '0 B' if bytes.nil? || bytes == 0

      bytes = bytes.to_f
      units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB']

      i = 0
      while bytes >= 1024 && i < units.length - 1
        bytes /= 1024
        i += 1
      end

      "#{format_number(bytes, 2)} #{units[i]}"
    end
  end
end
