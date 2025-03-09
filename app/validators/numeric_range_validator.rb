class NumericRangeValidator < ActiveModel::EachValidator
  # バリデーションを実行
  def validate_each(record, attribute, value)
    # 値が空の場合は他のバリデーターに任せる
    return if value.blank? && options[:allow_blank]

    # オプションを取得
    options = {
      greater_than: nil,
      greater_than_or_equal_to: nil,
      less_than: nil,
      less_than_or_equal_to: nil,
      equal_to: nil,
      other_than: nil,
      in: nil,
      allow_blank: false,
      only_integer: false,
      even: false,
      odd: false,
      positive: false,
      negative: false,
      zero: false
    }.merge(self.options)

    # 数値に変換
    begin
      numeric_value = parse_number(value)
    rescue ArgumentError
      record.errors.add(attribute, options[:message] || :not_a_number)
      return
    end

    # 数値が取得できない場合
    unless numeric_value
      record.errors.add(attribute, options[:message] || :not_a_number)
      return
    end

    # 整数のみをチェック
    if options[:only_integer] && !numeric_value.is_a?(Integer) && numeric_value != numeric_value.to_i
      record.errors.add(attribute, options[:only_integer_message] || :not_an_integer)
      return
    end

    # 偶数をチェック
    if options[:even] && numeric_value.to_i.odd?
      record.errors.add(attribute, options[:even_message] || :must_be_even)
      return
    end

    # 奇数をチェック
    if options[:odd] && numeric_value.to_i.even?
      record.errors.add(attribute, options[:odd_message] || :must_be_odd)
      return
    end

    # 正の数をチェック
    if options[:positive] && numeric_value <= 0
      record.errors.add(attribute, options[:positive_message] || :must_be_positive)
      return
    end

    # 負の数をチェック
    if options[:negative] && numeric_value >= 0
      record.errors.add(attribute, options[:negative_message] || :must_be_negative)
      return
    end

    # ゼロをチェック
    if options[:zero] && numeric_value != 0
      record.errors.add(attribute, options[:zero_message] || :must_be_zero)
      return
    end

    # 指定値より大きいをチェック
    if options[:greater_than]
      comparison_value = parse_number_option(options[:greater_than], record)
      if comparison_value && numeric_value <= comparison_value
        record.errors.add(attribute, options[:greater_than_message] || :must_be_greater_than, value: format_number(comparison_value))
        return
      end
    end

    # 指定値以上をチェック
    if options[:greater_than_or_equal_to]
      comparison_value = parse_number_option(options[:greater_than_or_equal_to], record)
      if comparison_value && numeric_value < comparison_value
        record.errors.add(attribute, options[:greater_than_or_equal_to_message] || :must_be_greater_than_or_equal_to, value: format_number(comparison_value))
        return
      end
    end

    # 指定値より小さいをチェック
    if options[:less_than]
      comparison_value = parse_number_option(options[:less_than], record)
      if comparison_value && numeric_value >= comparison_value
        record.errors.add(attribute, options[:less_than_message] || :must_be_less_than, value: format_number(comparison_value))
        return
      end
    end

    # 指定値以下をチェック
    if options[:less_than_or_equal_to]
      comparison_value = parse_number_option(options[:less_than_or_equal_to], record)
      if comparison_value && numeric_value > comparison_value
        record.errors.add(attribute, options[:less_than_or_equal_to_message] || :must_be_less_than_or_equal_to, value: format_number(comparison_value))
        return
      end
    end

    # 指定値と等しいをチェック
    if options[:equal_to]
      comparison_value = parse_number_option(options[:equal_to], record)
      if comparison_value && numeric_value != comparison_value
        record.errors.add(attribute, options[:equal_to_message] || :must_be_equal_to, value: format_number(comparison_value))
        return
      end
    end

    # 指定値と等しくないをチェック
    if options[:other_than]
      comparison_value = parse_number_option(options[:other_than], record)
      if comparison_value && numeric_value == comparison_value
        record.errors.add(attribute, options[:other_than_message] || :must_be_other_than, value: format_number(comparison_value))
        return
      end
    end

    # 範囲内をチェック
    if options[:in]
      range = options[:in]
      unless range.include?(numeric_value)
        record.errors.add(attribute, options[:in_message] || :must_be_in_range, range: format_range(range))
        return
      end
    end
  end

  private

  # 数値を解析
  def parse_number(value)
    return value if value.is_a?(Numeric)

    # 文字列の場合
    if value.is_a?(String)
      # 空文字列の場合
      return nil if value.blank?

      # 数値形式を解析
      begin
        # 整数形式の場合
        if value =~ /\A[+-]?\d+\z/
          value.to_i
        # 小数形式の場合
        elsif value =~ /\A[+-]?\d+\.\d+\z/
          value.to_f
        else
          nil
        end
      rescue ArgumentError
        nil
      end
    else
      nil
    end
  end

  # 数値オプションを解析
  def parse_number_option(option, record)
    case option
    when Numeric
      option
    when String
      # 文字列が数値形式の場合
      begin
        if option =~ /\A[+-]?\d+\z/
          option.to_i
        elsif option =~ /\A[+-]?\d+\.\d+\z/
          option.to_f
        else
          # 文字列がメソッド名の場合
          record.send(option) if record.respond_to?(option)
        end
      rescue ArgumentError
        # 文字列がメソッド名の場合
        record.send(option) if record.respond_to?(option)
      end
    when Symbol
      # シンボルがメソッド名の場合
      record.send(option) if record.respond_to?(option)
    when Proc
      # Procの場合
      result = option.call(record)
      parse_number(result)
    else
      nil
    end
  end

  # 数値をフォーマット
  def format_number(number)
    number.to_s
  end

  # 範囲をフォーマット
  def format_range(range)
    "#{range.begin} - #{range.end}"
  end

  # ヘルパーメソッド：数値が有効かどうかをチェック
  def self.valid?(number, options = {})
    validator = new(options.merge(attributes: [:number]))
    record = Struct.new(:number, :errors).new(number, ActiveModel::Errors.new(self))
    validator.validate_each(record, :number, number)
    record.errors.empty?
  end

  # ヘルパーメソッド：数値が範囲内かどうかをチェック
  def self.in_range?(number, min, max)
    number = parse_number(number)
    min = parse_number(min)
    max = parse_number(max)

    return false unless number && min && max

    number >= min && number <= max
  end

  # ヘルパーメソッド：数値を解析
  def self.parse_number(value)
    return value if value.is_a?(Numeric)

    # 文字列の場合
    if value.is_a?(String)
      # 空文字列の場合
      return nil if value.blank?

      # 数値形式を解析
      begin
        # 整数形式の場合
        if value =~ /\A[+-]?\d+\z/
          value.to_i
        # 小数形式の場合
        elsif value =~ /\A[+-]?\d+\.\d+\z/
          value.to_f
        else
          nil
        end
      rescue ArgumentError
        nil
      end
    else
      nil
    end
  end
end
