class ZipCodeValidator < ActiveModel::EachValidator
  # 国別の郵便番号パターン
  COUNTRY_PATTERNS = {
    # 日本（7桁の数字、ハイフンあり/なし）
    'jp' => /\A\d{3}[-]?\d{4}\z/,

    # アメリカ（5桁の数字、または5桁+ハイフン+4桁）
    'us' => /\A\d{5}([-]\d{4})?\z/,

    # イギリス（複雑なパターン）
    'gb' => /\A[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}\z/i,

    # カナダ（文字+数字+文字+数字+文字+数字、スペースあり/なし）
    'ca' => /\A[ABCEGHJKLMNPRSTVXY][0-9][ABCEGHJKLMNPRSTVWXYZ] ?[0-9][ABCEGHJKLMNPRSTVWXYZ][0-9]\z/i,

    # オーストラリア（4桁の数字）
    'au' => /\A\d{4}\z/,

    # ドイツ（5桁の数字）
    'de' => /\A\d{5}\z/,

    # フランス（5桁の数字）
    'fr' => /\A\d{5}\z/,

    # イタリア（5桁の数字）
    'it' => /\A\d{5}\z/,

    # スペイン（5桁の数字）
    'es' => /\A\d{5}\z/,

    # 中国（6桁の数字）
    'cn' => /\A\d{6}\z/,

    # インド（6桁の数字）
    'in' => /\A\d{6}\z/,

    # ブラジル（5桁の数字+ハイフン+3桁の数字）
    'br' => /\A\d{5}[-]?\d{3}\z/,

    # ロシア（6桁の数字）
    'ru' => /\A\d{6}\z/,

    # 韓国（5桁の数字）
    'kr' => /\A\d{5}\z/
  }.freeze

  # 国別の郵便番号フォーマット例
  COUNTRY_EXAMPLES = {
    'jp' => '123-4567',
    'us' => '12345-6789',
    'gb' => 'AB12 3CD',
    'ca' => 'A1B 2C3',
    'au' => '1234',
    'de' => '12345',
    'fr' => '12345',
    'it' => '12345',
    'es' => '12345',
    'cn' => '123456',
    'in' => '123456',
    'br' => '12345-678',
    'ru' => '123456',
    'kr' => '12345'
  }.freeze

  # バリデーションを実行
  def validate_each(record, attribute, value)
    # 値が空の場合は他のバリデーターに任せる
    return if value.blank? && options[:allow_blank]

    # オプションを取得
    options = {
      country: 'jp',
      allow_blank: false,
      strict: false
    }.merge(self.options)

    # 国を取得
    country = options[:country]
    country = country.call(record) if country.respond_to?(:call)
    country = country.to_s.downcase

    # 国別のパターンを取得
    pattern = COUNTRY_PATTERNS[country]

    # パターンが存在しない場合
    unless pattern
      record.errors.add(attribute, options[:message] || :zip_code_country_not_supported, country: country)
      return
    end

    # 郵便番号を正規化
    normalized_value = normalize_zip_code(value, country)

    # パターンをチェック
    unless normalized_value.match?(pattern)
      example = COUNTRY_EXAMPLES[country]
      record.errors.add(attribute, options[:message] || :invalid_zip_code, country: country, example: example)
      return
    end

    # 厳格なチェック
    if options[:strict]
      # 国別の厳格なチェック
      case country
      when 'jp'
        # 日本の場合、存在する郵便番号かチェック
        unless valid_japanese_zip_code?(normalized_value)
          record.errors.add(attribute, options[:message] || :zip_code_not_found)
        end
      when 'us'
        # アメリカの場合、存在する郵便番号かチェック
        unless valid_us_zip_code?(normalized_value)
          record.errors.add(attribute, options[:message] || :zip_code_not_found)
        end
      end
    end
  end

  private

  # 郵便番号を正規化
  def normalize_zip_code(value, country)
    value = value.to_s.strip.upcase

    # 全角数字を半角に変換
    value = value.tr('０-９', '0-9')

    # 国別の正規化
    case country
    when 'jp'
      # 日本の場合、ハイフンを削除
      value.gsub(/[^\d]/, '')
    when 'us'
      # アメリカの場合、ハイフン以外の記号を削除
      value.gsub(/[^\d-]/, '')
    when 'gb'
      # イギリスの場合、スペースを1つに正規化
      value.gsub(/\s+/, ' ')
    when 'ca'
      # カナダの場合、スペースを1つに正規化
      value.gsub(/\s+/, ' ')
    when 'br'
      # ブラジルの場合、ハイフン以外の記号を削除
      value.gsub(/[^\d-]/, '')
    else
      # その他の場合、記号を削除
      value.gsub(/[^\w\s]/, '')
    end
  end

  # 日本の郵便番号が有効かどうかをチェック
  def valid_japanese_zip_code?(zip_code)
    # 実際のアプリケーションでは、郵便番号データベースを使用して検証
    # ここではシミュレーションのみ
    true
  end

  # アメリカの郵便番号が有効かどうかをチェック
  def valid_us_zip_code?(zip_code)
    # 実際のアプリケーションでは、郵便番号データベースを使用して検証
    # ここではシミュレーションのみ
    true
  end

  # ヘルパーメソッド：郵便番号が有効かどうかをチェック
  def self.valid?(zip_code, country = 'jp', options = {})
    validator = new(options.merge(attributes: [:zip_code], country: country))
    record = Struct.new(:zip_code, :errors).new(zip_code, ActiveModel::Errors.new(self))
    validator.validate_each(record, :zip_code, zip_code)
    record.errors.empty?
  end

  # ヘルパーメソッド：郵便番号を正規化
  def self.normalize(zip_code, country = 'jp')
    return nil if zip_code.blank?

    zip_code = zip_code.to_s.strip.upcase

    # 全角数字を半角に変換
    zip_code = zip_code.tr('０-９', '0-9')

    # 国別の正規化
    case country.to_s.downcase
    when 'jp'
      # 日本の場合、数字のみ抽出して3桁-4桁に整形
      digits = zip_code.gsub(/[^\d]/, '')
      digits.length == 7 ? "#{digits[0..2]}-#{digits[3..6]}" : zip_code
    when 'us'
      # アメリカの場合、数字のみ抽出して5桁-4桁に整形（あれば）
      digits = zip_code.gsub(/[^\d]/, '')
      if digits.length == 9
        "#{digits[0..4]}-#{digits[5..8]}"
      elsif digits.length == 5
        digits
      else
        zip_code
      end
    when 'gb'
      # イギリスの場合、スペースを1つに正規化
      zip_code.gsub(/\s+/, ' ')
    when 'ca'
      # カナダの場合、3桁 3桁に整形
      letters_and_digits = zip_code.gsub(/[^A-Z0-9]/i, '')
      if letters_and_digits.length == 6
        "#{letters_and_digits[0..2]} #{letters_and_digits[3..5]}"
      else
        zip_code
      end
    when 'br'
      # ブラジルの場合、数字のみ抽出して5桁-3桁に整形
      digits = zip_code.gsub(/[^\d]/, '')
      digits.length == 8 ? "#{digits[0..4]}-#{digits[5..7]}" : zip_code
    else
      # その他の場合、記号を削除
      zip_code.gsub(/[^\w\s]/, '')
    end
  end

  # ヘルパーメソッド：郵便番号からフォーマットされた文字列を取得
  def self.format(zip_code, country = 'jp')
    normalize(zip_code, country)
  end
end
