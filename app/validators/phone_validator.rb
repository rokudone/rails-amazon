class PhoneValidator < ActiveModel::EachValidator
  # 国際電話番号の正規表現パターン
  # E.164形式（+国番号 + 電話番号）に準拠
  INTERNATIONAL_PATTERN = /\A\+[1-9]\d{1,14}\z/

  # 日本の電話番号の正規表現パターン
  JAPAN_PATTERN = /\A(?:\+81|0)\d{1,4}[-(]?\d{1,4}[-).]?\d{4}\z/

  # 米国の電話番号の正規表現パターン
  US_PATTERN = /\A(?:\+1|1)?[-\s.]?\(?([0-9]{3})\)?[-\s.]?([0-9]{3})[-\s.]?([0-9]{4})\z/

  # 国別の電話番号パターン
  COUNTRY_PATTERNS = {
    'jp' => JAPAN_PATTERN,
    'us' => US_PATTERN,
    # 他の国のパターンを追加可能
  }.freeze

  # 国コードと国番号のマッピング
  COUNTRY_CODES = {
    'jp' => '81',
    'us' => '1',
    'gb' => '44',
    'fr' => '33',
    'de' => '49',
    'it' => '39',
    'es' => '34',
    'cn' => '86',
    'in' => '91',
    'au' => '61',
    'ca' => '1',
    'br' => '55',
    'ru' => '7',
    'kr' => '82',
    # 他の国を追加可能
  }.freeze

  # バリデーションを実行
  def validate_each(record, attribute, value)
    # 値が空の場合は他のバリデーターに任せる
    return if value.blank?

    # オプションを取得
    options = {
      format: :any,
      country: nil,
      allow_blank: true,
      strict: false
    }.merge(self.options)

    # 値を正規化
    normalized_value = normalize_phone(value)

    # 国を取得
    country = options[:country]
    country = country.call(record) if country.respond_to?(:call)
    country = country.to_s.downcase if country

    # フォーマットに応じてバリデーション
    valid = case options[:format].to_sym
            when :international
              valid_international?(normalized_value, options)
            when :national
              valid_national?(normalized_value, country, options)
            when :any
              valid_international?(normalized_value, options) || valid_national?(normalized_value, country, options)
            else
              false
            end

    # バリデーション結果
    unless valid
      message = options[:message] || error_message_for(options[:format], country)
      record.errors.add(attribute, message)
    end
  end

  private

  # 国際電話番号形式が有効かどうかをチェック
  def valid_international?(value, options)
    return false unless value.start_with?('+')

    if options[:strict]
      # 厳格なチェック
      value.match?(INTERNATIONAL_PATTERN)
    else
      # 緩いチェック
      value.gsub(/[-()\s.]/, '').match?(/\A\+[1-9]\d{1,14}\z/)
    end
  end

  # 国内電話番号形式が有効かどうかをチェック
  def valid_national?(value, country, options)
    return false if country.blank?

    # 国別のパターンを取得
    pattern = COUNTRY_PATTERNS[country]
    return false unless pattern

    if options[:strict]
      # 厳格なチェック
      value.match?(pattern)
    else
      # 緩いチェック
      value.gsub(/[-()\s.]/, '').match?(pattern)
    end
  end

  # 電話番号を正規化
  def normalize_phone(value)
    value.to_s.strip.gsub(/[０-９]/) { |c| (c.ord - '０'.ord + '0'.ord).chr }
  end

  # エラーメッセージを取得
  def error_message_for(format, country)
    case format.to_sym
    when :international
      :invalid_international_phone
    when :national
      country ? :"invalid_#{country}_phone" : :invalid_phone
    else
      :invalid_phone
    end
  end

  # ヘルパーメソッド：電話番号が有効かどうかをチェック
  def self.valid?(phone, options = {})
    validator = new(options.merge(attributes: [:phone]))
    record = Struct.new(:phone, :errors).new(phone, ActiveModel::Errors.new(self))
    validator.validate_each(record, :phone, phone)
    record.errors.empty?
  end

  # ヘルパーメソッド：電話番号を国際形式に変換
  def self.to_international(phone, country_code = nil)
    return nil if phone.blank?

    # 既に国際形式の場合
    return phone if phone.start_with?('+')

    # 国コードが必要
    return nil unless country_code

    # 国番号を取得
    country_number = COUNTRY_CODES[country_code.to_s.downcase]
    return nil unless country_number

    # 電話番号を正規化
    normalized = phone.to_s.strip.gsub(/[-()\s.]/, '')

    # 国内形式の場合は先頭の0を削除
    normalized = normalized[1..-1] if normalized.start_with?('0')

    # 国際形式に変換
    "+#{country_number}#{normalized}"
  end

  # ヘルパーメソッド：電話番号を国内形式に変換
  def self.to_national(phone, country_code = 'jp')
    return nil if phone.blank?

    # 国際形式の場合
    if phone.start_with?('+')
      # 国番号を取得
      country_number = COUNTRY_CODES[country_code.to_s.downcase]
      return nil unless country_number

      # 国番号を削除
      if phone.start_with?("+#{country_number}")
        national = phone["+#{country_number}".length..-1]

        # 日本の場合は先頭に0を追加
        if country_code.to_s.downcase == 'jp'
          national = "0#{national}"
        end

        return national
      end
    end

    # 既に国内形式の場合
    phone
  end

  # ヘルパーメソッド：電話番号をフォーマット
  def self.format(phone, country_code = 'jp', format = :default)
    return nil if phone.blank?

    # 電話番号を正規化
    normalized = phone.to_s.strip.gsub(/[-()\s.]/, '')

    # 国内形式に変換
    national = to_national(normalized, country_code)
    return nil unless national

    case country_code.to_s.downcase
    when 'jp'
      case format.to_sym
      when :default
        if national.length == 11
          # 携帯電話
          "#{national[0..2]}-#{national[3..6]}-#{national[7..10]}"
        elsif national.length == 10
          # 固定電話
          "#{national[0..1]}-#{national[2..5]}-#{national[6..9]}"
        else
          national
        end
      when :hyphen
        if national.length == 11
          "#{national[0..2]}-#{national[3..6]}-#{national[7..10]}"
        elsif national.length == 10
          "#{national[0..1]}-#{national[2..5]}-#{national[6..9]}"
        else
          national
        end
      else
        national
      end
    when 'us'
      case format.to_sym
      when :default
        if national.length == 10
          "(#{national[0..2]}) #{national[3..5]}-#{national[6..9]}"
        else
          national
        end
      when :hyphen
        if national.length == 10
          "#{national[0..2]}-#{national[3..5]}-#{national[6..9]}"
        else
          national
        end
      else
        national
      end
    else
      national
    end
  end
end
