class LengthValidator < ActiveModel::EachValidator
  # バリデーションを実行
  def validate_each(record, attribute, value)
    # 値が空の場合は他のバリデーターに任せる
    return if value.blank? && options[:allow_blank]
    return if value.nil? && options[:allow_nil]

    # オプションを取得
    options = {
      minimum: nil,
      maximum: nil,
      is: nil,
      in: nil,
      within: nil,
      allow_blank: false,
      allow_nil: false,
      tokenizer: ->(value) { value.to_s.chars }
    }.merge(self.options)

    # 値を文字列に変換
    value_for_validation = value.to_s

    # トークナイザーを適用
    tokenizer = options[:tokenizer]
    tokens = tokenizer.call(value_for_validation)

    # 長さを取得
    length = tokens.length

    # 長さが指定値と等しいかチェック
    if options[:is]
      unless length == options[:is]
        record.errors.add(attribute, options[:wrong_length_message] || :wrong_length, count: options[:is])
      end
    end

    # 長さが範囲内かチェック
    if options[:in] || options[:within]
      range = options[:in] || options[:within]
      unless range.include?(length)
        record.errors.add(attribute, options[:not_in_range_message] || :not_in_range, range: range)
      end
    end

    # 長さが最小値以上かチェック
    if options[:minimum]
      unless length >= options[:minimum]
        record.errors.add(attribute, options[:too_short_message] || :too_short, count: options[:minimum])
      end
    end

    # 長さが最大値以下かチェック
    if options[:maximum]
      unless length <= options[:maximum]
        record.errors.add(attribute, options[:too_long_message] || :too_long, count: options[:maximum])
      end
    end
  end

  # ヘルパーメソッド：値の長さが有効かどうかをチェック
  def self.valid?(value, options = {})
    validator = new(options.merge(attributes: [:length]))
    record = Struct.new(:length, :errors).new(value, ActiveModel::Errors.new(self))
    validator.validate_each(record, :length, value)
    record.errors.empty?
  end

  # ヘルパーメソッド：値の長さを取得
  def self.length_of(value, options = {})
    # トークナイザーを取得
    tokenizer = options[:tokenizer] || ->(v) { v.to_s.chars }

    # トークナイザーを適用
    tokens = tokenizer.call(value.to_s)

    # 長さを返す
    tokens.length
  end

  # ヘルパーメソッド：値を切り詰め
  def self.truncate(value, options = {})
    # オプションを取得
    options = {
      length: 30,
      omission: '...',
      separator: nil,
      tokenizer: ->(v) { v.to_s.chars }
    }.merge(options)

    # 値を文字列に変換
    value_for_truncation = value.to_s

    # トークナイザーを適用
    tokenizer = options[:tokenizer]
    tokens = tokenizer.call(value_for_truncation)

    # 長さを取得
    length = tokens.length

    # 切り詰めが不要な場合
    return value_for_truncation if length <= options[:length]

    # 省略記号の長さを取得
    omission_length = tokenizer.call(options[:omission]).length

    # 切り詰め位置を計算
    stop = options[:length] - omission_length

    # セパレータが指定されている場合
    if options[:separator]
      stop = value_for_truncation.rindex(options[:separator], stop) || stop
    end

    # 切り詰め
    "#{value_for_truncation[0...stop]}#{options[:omission]}"
  end

  # ヘルパーメソッド：値をパディング
  def self.pad(value, options = {})
    # オプションを取得
    options = {
      length: 10,
      pad_char: ' ',
      position: :right
    }.merge(options)

    # 値を文字列に変換
    value_for_padding = value.to_s

    # 長さを取得
    length = value_for_padding.length

    # パディングが不要な場合
    return value_for_padding if length >= options[:length]

    # パディング文字を取得
    pad_char = options[:pad_char].to_s

    # パディング長を計算
    pad_length = options[:length] - length

    # パディング
    case options[:position]
    when :left
      "#{pad_char * pad_length}#{value_for_padding}"
    when :right
      "#{value_for_padding}#{pad_char * pad_length}"
    when :center
      left_pad = pad_length / 2
      right_pad = pad_length - left_pad
      "#{pad_char * left_pad}#{value_for_padding}#{pad_char * right_pad}"
    else
      value_for_padding
    end
  end

  # ヘルパーメソッド：値を省略
  def self.ellipsize(value, options = {})
    # オプションを取得
    options = {
      length: 20,
      position: :end,
      ellipsis: '...'
    }.merge(options)

    # 値を文字列に変換
    value_for_ellipsis = value.to_s

    # 長さを取得
    length = value_for_ellipsis.length

    # 省略が不要な場合
    return value_for_ellipsis if length <= options[:length]

    # 省略記号の長さを取得
    ellipsis_length = options[:ellipsis].length

    # 表示文字数を計算
    visible_length = options[:length] - ellipsis_length

    # 省略
    case options[:position]
    when :start
      "#{options[:ellipsis]}#{value_for_ellipsis[(length - visible_length)..-1]}"
    when :end
      "#{value_for_ellipsis[0...visible_length]}#{options[:ellipsis]}"
    when :middle
      left_length = visible_length / 2
      right_length = visible_length - left_length
      "#{value_for_ellipsis[0...left_length]}#{options[:ellipsis]}#{value_for_ellipsis[(length - right_length)..-1]}"
    else
      value_for_ellipsis
    end
  end
end
