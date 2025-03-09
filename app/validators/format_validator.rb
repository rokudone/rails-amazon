class FormatValidator < ActiveModel::EachValidator
  # バリデーションを実行
  def validate_each(record, attribute, value)
    # 値が空の場合は他のバリデーターに任せる
    return if value.blank? && options[:allow_blank]
    return if value.nil? && options[:allow_nil]

    # オプションを取得
    options = {
      with: nil,
      without: nil,
      message: :invalid_format,
      allow_blank: false,
      allow_nil: false
    }.merge(self.options)

    # 値を文字列に変換
    value = value.to_s

    # パターンとマッチするかチェック
    if options[:with]
      pattern = options[:with]

      # パターンがProcの場合
      if pattern.is_a?(Proc)
        unless pattern.call(value)
          record.errors.add(attribute, options[:message])
        end
      # パターンが正規表現の場合
      elsif pattern.is_a?(Regexp)
        unless value.match?(pattern)
          record.errors.add(attribute, options[:message])
        end
      # パターンがシンボルの場合
      elsif pattern.is_a?(Symbol) && self.class.respond_to?(pattern)
        unless self.class.send(pattern, value)
          record.errors.add(attribute, options[:message])
        end
      end
    end

    # パターンとマッチしないかチェック
    if options[:without]
      pattern = options[:without]

      # パターンがProcの場合
      if pattern.is_a?(Proc)
        if pattern.call(value)
          record.errors.add(attribute, options[:without_message] || :invalid_format)
        end
      # パターンが正規表現の場合
      elsif pattern.is_a?(Regexp)
        if value.match?(pattern)
          record.errors.add(attribute, options[:without_message] || :invalid_format)
        end
      # パターンがシンボルの場合
      elsif pattern.is_a?(Symbol) && self.class.respond_to?(pattern)
        if self.class.send(pattern, value)
          record.errors.add(attribute, options[:without_message] || :invalid_format)
        end
      end
    end
  end

  # 一般的なフォーマットパターン

  # 英数字のみ
  def self.alphanumeric
    /\A[a-zA-Z0-9]+\z/
  end

  # 英字のみ
  def self.alpha
    /\A[a-zA-Z]+\z/
  end

  # 数字のみ
  def self.numeric
    /\A[0-9]+\z/
  end

  # 英数字とアンダースコア
  def self.alphanumeric_underscore
    /\A[a-zA-Z0-9_]+\z/
  end

  # 英数字とハイフン
  def self.alphanumeric_dash
    /\A[a-zA-Z0-9\-]+\z/
  end

  # 英数字とスペース
  def self.alphanumeric_space
    /\A[a-zA-Z0-9\s]+\z/
  end

  # 英数字と一般的な記号
  def self.alphanumeric_symbols
    /\A[a-zA-Z0-9\s\-_\.,:;!?@#$%^&*()[\]{}+=\/\\|"'~`<>]+\z/
  end

  # メールアドレス（簡易版）
  def self.email
    /\A[a-zA-Z0-9.!\#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\z/
  end

  # URL（簡易版）
  def self.url
    /\A(https?:\/\/)?([a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,})(:[0-9]{1,5})?(\/.*)?(\?.*)?(#.*)?\z/i
  end

  # 電話番号（簡易版）
  def self.phone
    /\A[0-9\-\+\(\)\s\.]+\z/
  end

  # 郵便番号（簡易版）
  def self.zip_code
    /\A[0-9\-\s]+\z/
  end

  # IPアドレス（IPv4）
  def self.ipv4
    /\A((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\z/
  end

  # IPアドレス（IPv6）
  def self.ipv6
    /\A(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))\z/
  end

  # 日付（YYYY-MM-DD）
  def self.date
    /\A\d{4}-\d{2}-\d{2}\z/
  end

  # 時間（HH:MM:SS）
  def self.time
    /\A\d{2}:\d{2}(:\d{2})?\z/
  end

  # 日時（YYYY-MM-DD HH:MM:SS）
  def self.datetime
    /\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?\z/
  end

  # 16進数
  def self.hex
    /\A[0-9a-fA-F]+\z/
  end

  # Base64
  def self.base64
    /\A[A-Za-z0-9+\/]+={0,2}\z/
  end

  # JSONオブジェクト
  def self.json?(value)
    begin
      JSON.parse(value)
      true
    rescue JSON::ParserError
      false
    end
  end

  # XMLドキュメント
  def self.xml?(value)
    begin
      Nokogiri::XML(value) { |config| config.strict }
      true
    rescue Nokogiri::XML::SyntaxError
      false
    end
  end

  # CSVデータ
  def self.csv?(value)
    begin
      CSV.parse(value)
      true
    rescue CSV::MalformedCSVError
      false
    end
  end

  # ヘルパーメソッド：値がパターンにマッチするかどうかをチェック
  def self.valid?(value, pattern)
    return false if value.nil?

    value = value.to_s

    # パターンがProcの場合
    if pattern.is_a?(Proc)
      pattern.call(value)
    # パターンが正規表現の場合
    elsif pattern.is_a?(Regexp)
      value.match?(pattern)
    # パターンがシンボルの場合
    elsif pattern.is_a?(Symbol) && respond_to?(pattern)
      send(pattern, value)
    else
      false
    end
  end
end
