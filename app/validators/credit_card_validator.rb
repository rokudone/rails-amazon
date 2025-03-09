class CreditCardValidator < ActiveModel::EachValidator
  # クレジットカード番号のパターン
  CARD_PATTERNS = {
    # Visa: 13桁または16桁、4で始まる
    visa: /\A4[0-9]{12}(?:[0-9]{3})?\z/,

    # MasterCard: 16桁、51-55または2221-2720で始まる
    mastercard: /\A(?:5[1-5][0-9]{14}|2(?:22[1-9]|2[3-9][0-9]|[3-6][0-9]{2}|7[0-1][0-9]|720)[0-9]{12})\z/,

    # American Express: 15桁、34または37で始まる
    amex: /\A3[47][0-9]{13}\z/,

    # Discover: 16桁、6011または65または644-649または622126-622925で始まる
    discover: /\A(?:6011|65[0-9]{2}|64[4-9][0-9]|6221[2-9][0-9]|62[2-8][0-9]{2}|6229[0-1][0-9]|62292[0-5])[0-9]{12}\z/,

    # Diners Club: 14桁、300-305または36または38で始まる
    diners_club: /\A3(?:0[0-5]|[68][0-9])[0-9]{11}\z/,

    # JCB: 16桁、2131または1800または35で始まる
    jcb: /\A(?:2131|1800|35[0-9]{3})[0-9]{11}\z/,

    # UnionPay: 16-19桁、62で始まる
    unionpay: /\A62[0-9]{14,17}\z/
  }.freeze

  # クレジットカード番号の桁数
  CARD_LENGTHS = {
    visa: [13, 16],
    mastercard: [16],
    amex: [15],
    discover: [16],
    diners_club: [14],
    jcb: [16],
    unionpay: [16, 17, 18, 19]
  }.freeze

  # バリデーションを実行
  def validate_each(record, attribute, value)
    # 値が空の場合は他のバリデーターに任せる
    return if value.blank? && options[:allow_blank]

    # オプションを取得
    options = {
      types: [:visa, :mastercard, :amex, :discover, :diners_club, :jcb, :unionpay],
      luhn: true,
      allow_blank: false,
      allow_test_numbers: false
    }.merge(self.options)

    # クレジットカード番号を正規化
    normalized_value = normalize_card_number(value)

    # 数字のみかチェック
    unless normalized_value.match?(/\A\d+\z/)
      record.errors.add(attribute, options[:message] || :invalid_credit_card_format)
      return
    end

    # 桁数をチェック
    valid_length = false
    options[:types].each do |type|
      if CARD_LENGTHS[type]&.include?(normalized_value.length)
        valid_length = true
        break
      end
    end

    unless valid_length
      record.errors.add(attribute, options[:message] || :invalid_credit_card_length)
      return
    end

    # カード種類をチェック
    card_type = detect_card_type(normalized_value)
    unless card_type && options[:types].include?(card_type)
      record.errors.add(attribute, options[:message] || :invalid_credit_card_type, types: options[:types].join(', '))
      return
    end

    # Luhnアルゴリズムをチェック
    if options[:luhn] && !valid_luhn?(normalized_value)
      # テスト番号の場合は例外
      unless options[:allow_test_numbers] && test_card_number?(normalized_value)
        record.errors.add(attribute, options[:message] || :invalid_credit_card_checksum)
        return
      end
    end
  end

  private

  # クレジットカード番号を正規化
  def normalize_card_number(value)
    value.to_s.gsub(/[^0-9]/, '')
  end

  # カード種類を検出
  def detect_card_type(number)
    CARD_PATTERNS.each do |type, pattern|
      return type if number.match?(pattern)
    end
    nil
  end

  # Luhnアルゴリズムによるチェック
  def valid_luhn?(number)
    digits = number.chars.map(&:to_i)
    check_digit = digits.pop

    sum = digits.reverse.each_with_index.sum do |digit, i|
      value = i.odd? ? digit * 2 : digit
      value > 9 ? value - 9 : value
    end

    (10 - sum % 10) % 10 == check_digit
  end

  # テスト用カード番号かどうかをチェック
  def test_card_number?(number)
    test_numbers = [
      '4111111111111111', # Visa
      '5555555555554444', # MasterCard
      '378282246310005',  # American Express
      '6011111111111117', # Discover
      '30569309025904',   # Diners Club
      '3530111333300000'  # JCB
    ]
    test_numbers.include?(number)
  end

  # ヘルパーメソッド：クレジットカード番号が有効かどうかをチェック
  def self.valid?(number, options = {})
    validator = new(options.merge(attributes: [:credit_card]))
    record = Struct.new(:credit_card, :errors).new(number, ActiveModel::Errors.new(self))
    validator.validate_each(record, :credit_card, number)
    record.errors.empty?
  end

  # ヘルパーメソッド：クレジットカード番号を正規化
  def self.normalize(number)
    number.to_s.gsub(/[^0-9]/, '')
  end

  # ヘルパーメソッド：クレジットカード種類を検出
  def self.detect_type(number)
    normalized = normalize(number)

    CARD_PATTERNS.each do |type, pattern|
      return type if normalized.match?(pattern)
    end

    nil
  end

  # ヘルパーメソッド：クレジットカード番号をマスク
  def self.mask(number, visible_digits = 4, mask_char = '*')
    normalized = normalize(number)
    return normalized if normalized.length <= visible_digits

    masked_length = normalized.length - visible_digits
    "#{mask_char * masked_length}#{normalized[-visible_digits..-1]}"
  end

  # ヘルパーメソッド：クレジットカード番号をフォーマット
  def self.format(number)
    normalized = normalize(number)
    return normalized if normalized.blank?

    card_type = detect_type(normalized)

    case card_type
    when :amex
      # American Express: XXXX XXXXXX XXXXX
      if normalized.length == 15
        "#{normalized[0..3]} #{normalized[4..9]} #{normalized[10..14]}"
      else
        normalized
      end
    when :diners_club
      # Diners Club: XXXX XXXXXX XXXX
      if normalized.length == 14
        "#{normalized[0..3]} #{normalized[4..9]} #{normalized[10..13]}"
      else
        normalized
      end
    else
      # その他: XXXX XXXX XXXX XXXX
      if normalized.length == 16
        "#{normalized[0..3]} #{normalized[4..7]} #{normalized[8..11]} #{normalized[12..15]}"
      elsif normalized.length > 16
        # 16桁以上の場合は4桁ずつ区切る
        normalized.scan(/.{1,4}/).join(' ')
      else
        normalized
      end
    end
  end

  # ヘルパーメソッド：有効期限が有効かどうかをチェック
  def self.valid_expiry?(month, year)
    return false if month.blank? || year.blank?

    # 月と年を整数に変換
    month = month.to_i
    year = year.to_i

    # 2桁の年を4桁に変換
    year = 2000 + year if year < 100

    # 現在の日付を取得
    current_date = Date.today
    expiry_date = Date.new(year, month, 1).end_of_month

    # 有効期限が現在以降かどうかをチェック
    expiry_date >= current_date
  end

  # ヘルパーメソッド：セキュリティコードが有効かどうかをチェック
  def self.valid_security_code?(code, card_type = nil)
    return false if code.blank?

    # セキュリティコードを正規化
    normalized = code.to_s.gsub(/[^0-9]/, '')

    # カード種類に応じた桁数をチェック
    if card_type == :amex
      normalized.length == 4
    else
      normalized.length == 3
    end
  end
end
