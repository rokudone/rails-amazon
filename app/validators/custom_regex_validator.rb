class CustomRegexValidator < ActiveModel::EachValidator
  # バリデーションを実行
  def validate_each(record, attribute, value)
    # 値が空の場合は他のバリデーターに任せる
    return if value.blank? && options[:allow_blank]
    return if value.nil? && options[:allow_nil]

    # オプションを取得
    options = {
      pattern: nil,
      with: nil,
      without: nil,
      allow_blank: false,
      allow_nil: false,
      message: :invalid_format,
      case_sensitive: true
    }.merge(self.options)

    # 値を文字列に変換
    value = value.to_s

    # パターンを取得
    pattern = options[:pattern] || options[:with]

    # パターンが存在しない場合
    if pattern.nil? && options[:without].nil?
      raise ArgumentError, "Include either :pattern, :with, or :without option in custom_regex validator"
    end

    # パターンとマッチするかチェック
    if pattern
      # 正規表現に変換
      regex = pattern_to_regex(pattern, options[:case_sensitive])

      # マッチするかチェック
      unless value.match?(regex)
        # エラーメッセージを構築
        error_options = { value: value }

        # パターンが表示可能な場合
        if pattern.respond_to?(:to_s)
          error_options[:pattern] = pattern.to_s
        end

        # エラーを追加
        record.errors.add(attribute, options[:message], **error_options)
      end
    end

    # パターンとマッチしないかチェック
    if options[:without]
      # 正規表現に変換
      regex = pattern_to_regex(options[:without], options[:case_sensitive])

      # マッチしないかチェック
      if value.match?(regex)
        # エラーメッセージを構築
        error_options = { value: value }

        # パターンが表示可能な場合
        if options[:without].respond_to?(:to_s)
          error_options[:pattern] = options[:without].to_s
        end

        # エラーを追加
        record.errors.add(attribute, options[:without_message] || :invalid_format, **error_options)
      end
    end
  end

  private

  # パターンを正規表現に変換
  def pattern_to_regex(pattern, case_sensitive = true)
    # 既に正規表現の場合
    return pattern if pattern.is_a?(Regexp)

    # 文字列の場合
    if pattern.is_a?(String)
      # 大文字小文字を区別しない場合
      if case_sensitive
        Regexp.new(pattern)
      else
        Regexp.new(pattern, Regexp::IGNORECASE)
      end
    else
      # その他の場合
      Regexp.new(pattern.to_s)
    end
  end

  # ヘルパーメソッド：値がパターンにマッチするかどうかをチェック
  def self.valid?(value, pattern, options = {})
    # 値が空の場合
    return true if value.blank? && options[:allow_blank]
    return true if value.nil? && options[:allow_nil]

    # パターンが存在しない場合
    return false unless pattern

    # 値を文字列に変換
    value = value.to_s

    # 正規表現に変換
    regex = pattern_to_regex(pattern, options[:case_sensitive] != false)

    # マッチするかチェック
    value.match?(regex)
  end

  # ヘルパーメソッド：パターンを正規表現に変換
  def self.pattern_to_regex(pattern, case_sensitive = true)
    # 既に正規表現の場合
    return pattern if pattern.is_a?(Regexp)

    # 文字列の場合
    if pattern.is_a?(String)
      # 大文字小文字を区別しない場合
      if case_sensitive
        Regexp.new(pattern)
      else
        Regexp.new(pattern, Regexp::IGNORECASE)
      end
    else
      # その他の場合
      Regexp.new(pattern.to_s)
    end
  end

  # ヘルパーメソッド：値からパターンにマッチする部分を抽出
  def self.extract_matches(value, pattern, options = {})
    # 値が空の場合
    return [] if value.blank?

    # パターンが存在しない場合
    return [] unless pattern

    # 値を文字列に変換
    value = value.to_s

    # 正規表現に変換
    regex = pattern_to_regex(pattern, options[:case_sensitive] != false)

    # マッチする部分を抽出
    matches = []
    value.scan(regex) do |match|
      if match.is_a?(Array)
        matches << match
      else
        matches << [match]
      end
    end

    matches
  end

  # ヘルパーメソッド：値からパターンにマッチする部分を置換
  def self.replace_matches(value, pattern, replacement, options = {})
    # 値が空の場合
    return value if value.blank?

    # パターンが存在しない場合
    return value unless pattern

    # 値を文字列に変換
    value = value.to_s

    # 正規表現に変換
    regex = pattern_to_regex(pattern, options[:case_sensitive] != false)

    # マッチする部分を置換
    value.gsub(regex, replacement)
  end

  # ヘルパーメソッド：一般的な正規表現パターン
  def self.common_patterns
    {
      # 英数字のみ
      alphanumeric: /\A[a-zA-Z0-9]+\z/,

      # 英字のみ
      alpha: /\A[a-zA-Z]+\z/,

      # 数字のみ
      numeric: /\A[0-9]+\z/,

      # 英数字とアンダースコア
      alphanumeric_underscore: /\A[a-zA-Z0-9_]+\z/,

      # 英数字とハイフン
      alphanumeric_dash: /\A[a-zA-Z0-9\-]+\z/,

      # 英数字とスペース
      alphanumeric_space: /\A[a-zA-Z0-9\s]+\z/,

      # メールアドレス（簡易版）
      email: /\A[a-zA-Z0-9.!\#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\z/,

      # URL（簡易版）
      url: /\A(https?:\/\/)?([a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,})(:[0-9]{1,5})?(\/.*)?(\?.*)?(#.*)?\z/i,

      # 電話番号（簡易版）
      phone: /\A[0-9\-\+\(\)\s\.]+\z/,

      # 郵便番号（簡易版）
      zip_code: /\A[0-9\-\s]+\z/,

      # IPアドレス（IPv4）
      ipv4: /\A((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\z/,

      # 日付（YYYY-MM-DD）
      date: /\A\d{4}-\d{2}-\d{2}\z/,

      # 時間（HH:MM:SS）
      time: /\A\d{2}:\d{2}(:\d{2})?\z/,

      # 16進数
      hex: /\A[0-9a-fA-F]+\z/,

      # Base64
      base64: /\A[A-Za-z0-9+\/]+={0,2}\z/
    }
  end
end
