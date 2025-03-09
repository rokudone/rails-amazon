class PasswordValidator < ActiveModel::EachValidator
  # デフォルトの最小長
  DEFAULT_MIN_LENGTH = 8

  # デフォルトの最大長
  DEFAULT_MAX_LENGTH = 128

  # デフォルトの複雑性要件
  DEFAULT_COMPLEXITY = {
    uppercase: true,   # 大文字を含む
    lowercase: true,   # 小文字を含む
    numbers: true,     # 数字を含む
    special: true,     # 特殊文字を含む
    min_unique: 5      # 最小ユニーク文字数
  }

  # 一般的なパスワード（使用禁止）
  COMMON_PASSWORDS = %w[
    password 123456 12345678 qwerty abc123 monkey 1234567 letmein
    trustno1 dragon baseball 111111 iloveyou master sunshine ashley
    bailey passw0rd shadow 123123 654321 superman qazwsx michael
    football welcome jesus ninja mustang password1 123456789 adobe123
  ].freeze

  # 特殊文字のパターン
  SPECIAL_CHARS_PATTERN = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]+/

  # バリデーションを実行
  def validate_each(record, attribute, value)
    # 値が空の場合は他のバリデーターに任せる
    return if value.blank? && options[:allow_blank]

    # オプションを取得
    options = {
      min_length: DEFAULT_MIN_LENGTH,
      max_length: DEFAULT_MAX_LENGTH,
      complexity: DEFAULT_COMPLEXITY,
      dictionary: true,
      common: true,
      personal_info: true,
      allow_blank: false
    }.merge(self.options)

    # 長さをチェック
    validate_length(record, attribute, value, options)

    # 複雑性をチェック
    validate_complexity(record, attribute, value, options)

    # 一般的なパスワードをチェック
    validate_common_password(record, attribute, value, options)

    # 個人情報をチェック
    validate_personal_info(record, attribute, value, options)
  end

  private

  # 長さをチェック
  def validate_length(record, attribute, value, options)
    # 最小長をチェック
    if value.length < options[:min_length]
      record.errors.add(attribute, options[:min_length_message] || :password_too_short, count: options[:min_length])
    end

    # 最大長をチェック
    if value.length > options[:max_length]
      record.errors.add(attribute, options[:max_length_message] || :password_too_long, count: options[:max_length])
    end
  end

  # 複雑性をチェック
  def validate_complexity(record, attribute, value, options)
    complexity = options[:complexity]
    return unless complexity

    # 大文字をチェック
    if complexity[:uppercase] && !value.match(/[A-Z]/)
      record.errors.add(attribute, options[:uppercase_message] || :password_no_uppercase)
    end

    # 小文字をチェック
    if complexity[:lowercase] && !value.match(/[a-z]/)
      record.errors.add(attribute, options[:lowercase_message] || :password_no_lowercase)
    end

    # 数字をチェック
    if complexity[:numbers] && !value.match(/[0-9]/)
      record.errors.add(attribute, options[:numbers_message] || :password_no_numbers)
    end

    # 特殊文字をチェック
    if complexity[:special] && !value.match(SPECIAL_CHARS_PATTERN)
      record.errors.add(attribute, options[:special_message] || :password_no_special)
    end

    # ユニーク文字数をチェック
    if complexity[:min_unique] && value.chars.uniq.length < complexity[:min_unique]
      record.errors.add(attribute, options[:min_unique_message] || :password_not_unique, count: complexity[:min_unique])
    end
  end

  # 一般的なパスワードをチェック
  def validate_common_password(record, attribute, value, options)
    return unless options[:common]

    # 一般的なパスワードをチェック
    if COMMON_PASSWORDS.include?(value.downcase)
      record.errors.add(attribute, options[:common_message] || :password_common)
    end
  end

  # 個人情報をチェック
  def validate_personal_info(record, attribute, value, options)
    return unless options[:personal_info]

    # ユーザー名をチェック
    if record.respond_to?(:username) && record.username.present?
      if value.downcase.include?(record.username.downcase)
        record.errors.add(attribute, options[:personal_info_message] || :password_contains_username)
        return
      end
    end

    # メールアドレスをチェック
    if record.respond_to?(:email) && record.email.present?
      username = record.email.split('@').first
      if value.downcase.include?(username.downcase)
        record.errors.add(attribute, options[:personal_info_message] || :password_contains_email)
        return
      end
    end

    # 名前をチェック
    if record.respond_to?(:first_name) && record.first_name.present?
      if value.downcase.include?(record.first_name.downcase)
        record.errors.add(attribute, options[:personal_info_message] || :password_contains_name)
        return
      end
    end

    if record.respond_to?(:last_name) && record.last_name.present?
      if value.downcase.include?(record.last_name.downcase)
        record.errors.add(attribute, options[:personal_info_message] || :password_contains_name)
        return
      end
    end
  end

  # ヘルパーメソッド：パスワードが有効かどうかをチェック
  def self.valid?(password, options = {})
    validator = new(options.merge(attributes: [:password]))
    record = Struct.new(:password, :errors).new(password, ActiveModel::Errors.new(self))
    validator.validate_each(record, :password, password)
    record.errors.empty?
  end

  # ヘルパーメソッド：パスワードの強度を計算（0-100）
  def self.strength(password)
    return 0 if password.blank?

    score = 0

    # 長さによるスコア
    length_score = [password.length, 20].min * 2
    score += length_score

    # 文字種類によるスコア
    char_types = 0
    char_types += 1 if password.match(/[a-z]/)
    char_types += 1 if password.match(/[A-Z]/)
    char_types += 1 if password.match(/[0-9]/)
    char_types += 1 if password.match(SPECIAL_CHARS_PATTERN)
    score += char_types * 10

    # ユニーク文字数によるスコア
    unique_chars = password.chars.uniq.length
    unique_score = [unique_chars, 10].min * 3
    score += unique_score

    # 一般的なパスワードによる減点
    if COMMON_PASSWORDS.include?(password.downcase)
      score -= 30
    end

    # 連続した文字による減点
    if password.match(/(.)\1{2,}/)
      score -= 10
    end

    # 連続した数字やアルファベットによる減点
    if password.match(/(?:0123|1234|2345|3456|4567|5678|6789|abcd|bcde|cdef|defg|efgh|fghi|ghij|hijk|ijkl|jklm|klmn|lmno|mnop|nopq|opqr|pqrs|qrst|rstu|stuv|tuvw|uvwx|vwxy|wxyz)/i)
      score -= 10
    end

    # スコアを0-100の範囲に収める
    [[score, 0].max, 100].min
  end

  # ヘルパーメソッド：パスワードの強度を文字列で取得
  def self.strength_level(password)
    score = strength(password)

    if score >= 80
      :very_strong
    elsif score >= 60
      :strong
    elsif score >= 40
      :medium
    elsif score >= 20
      :weak
    else
      :very_weak
    end
  end

  # ヘルパーメソッド：パスワードを生成
  def self.generate(options = {})
    options = {
      length: DEFAULT_MIN_LENGTH,
      uppercase: true,
      lowercase: true,
      numbers: true,
      special: true
    }.merge(options)

    chars = ''
    chars += ('A'..'Z').to_a.join if options[:uppercase]
    chars += ('a'..'z').to_a.join if options[:lowercase]
    chars += ('0'..'9').to_a.join if options[:numbers]
    chars += '!@#$%^&*()_+-=[]{}|;:,.<>?'.chars.join if options[:special]

    # 少なくとも1つの文字種類が必要
    raise ArgumentError, 'At least one character type must be enabled' if chars.empty?

    # パスワードを生成
    password = ''
    options[:length].times do
      password += chars[SecureRandom.random_number(chars.length)]
    end

    password
  end
end
