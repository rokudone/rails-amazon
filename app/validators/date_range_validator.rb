class DateRangeValidator < ActiveModel::EachValidator
  # バリデーションを実行
  def validate_each(record, attribute, value)
    # 値が空の場合は他のバリデーターに任せる
    return if value.blank? && options[:allow_blank]

    # オプションを取得
    options = {
      after: nil,
      after_or_equal_to: nil,
      before: nil,
      before_or_equal_to: nil,
      between: nil,
      not_in_past: false,
      not_in_future: false,
      allow_blank: false
    }.merge(self.options)

    # 日付に変換
    begin
      date_value = parse_date(value)
    rescue ArgumentError
      record.errors.add(attribute, options[:message] || :invalid_date)
      return
    end

    # 日付が取得できない場合
    unless date_value
      record.errors.add(attribute, options[:message] || :invalid_date)
      return
    end

    # 過去の日付をチェック
    if options[:not_in_past] && date_value < Date.current
      record.errors.add(attribute, options[:not_in_past_message] || :date_cannot_be_in_past)
      return
    end

    # 未来の日付をチェック
    if options[:not_in_future] && date_value > Date.current
      record.errors.add(attribute, options[:not_in_future_message] || :date_cannot_be_in_future)
      return
    end

    # 指定日以降をチェック
    if options[:after]
      after_date = parse_date_option(options[:after], record)
      if after_date && date_value <= after_date
        record.errors.add(attribute, options[:after_message] || :date_must_be_after, date: format_date(after_date))
        return
      end
    end

    # 指定日以降（当日含む）をチェック
    if options[:after_or_equal_to]
      after_or_equal_date = parse_date_option(options[:after_or_equal_to], record)
      if after_or_equal_date && date_value < after_or_equal_date
        record.errors.add(attribute, options[:after_or_equal_to_message] || :date_must_be_after_or_equal_to, date: format_date(after_or_equal_date))
        return
      end
    end

    # 指定日以前をチェック
    if options[:before]
      before_date = parse_date_option(options[:before], record)
      if before_date && date_value >= before_date
        record.errors.add(attribute, options[:before_message] || :date_must_be_before, date: format_date(before_date))
        return
      end
    end

    # 指定日以前（当日含む）をチェック
    if options[:before_or_equal_to]
      before_or_equal_date = parse_date_option(options[:before_or_equal_to], record)
      if before_or_equal_date && date_value > before_or_equal_date
        record.errors.add(attribute, options[:before_or_equal_to_message] || :date_must_be_before_or_equal_to, date: format_date(before_or_equal_date))
        return
      end
    end

    # 期間内をチェック
    if options[:between]
      start_date, end_date = parse_date_range_option(options[:between], record)
      if start_date && end_date
        unless date_value >= start_date && date_value <= end_date
          record.errors.add(attribute, options[:between_message] || :date_must_be_between, start_date: format_date(start_date), end_date: format_date(end_date))
          return
        end
      end
    end
  end

  private

  # 日付を解析
  def parse_date(value)
    return value if value.is_a?(Date)
    return value.to_date if value.is_a?(Time) || value.is_a?(DateTime)

    # 文字列の場合
    if value.is_a?(String)
      # 空文字列の場合
      return nil if value.blank?

      # 日付形式を解析
      begin
        Date.parse(value)
      rescue ArgumentError
        nil
      end
    else
      nil
    end
  end

  # 日付オプションを解析
  def parse_date_option(option, record)
    case option
    when Date, Time, DateTime
      option.to_date
    when String
      # 文字列が日付形式の場合
      begin
        Date.parse(option)
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
      parse_date(result)
    else
      nil
    end
  end

  # 日付範囲オプションを解析
  def parse_date_range_option(option, record)
    case option
    when Array
      # 配列の場合
      start_date = parse_date_option(option.first, record)
      end_date = parse_date_option(option.last, record)
      [start_date, end_date]
    when Range
      # 範囲の場合
      start_date = parse_date_option(option.begin, record)
      end_date = parse_date_option(option.end, record)
      [start_date, end_date]
    when Hash
      # ハッシュの場合
      start_date = parse_date_option(option[:start] || option[:from], record)
      end_date = parse_date_option(option[:end] || option[:to], record)
      [start_date, end_date]
    else
      [nil, nil]
    end
  end

  # 日付をフォーマット
  def format_date(date)
    date.strftime('%Y-%m-%d')
  end

  # ヘルパーメソッド：日付が有効かどうかをチェック
  def self.valid?(date, options = {})
    validator = new(options.merge(attributes: [:date]))
    record = Struct.new(:date, :errors).new(date, ActiveModel::Errors.new(self))
    validator.validate_each(record, :date, date)
    record.errors.empty?
  end

  # ヘルパーメソッド：日付が範囲内かどうかをチェック
  def self.in_range?(date, start_date, end_date)
    date = parse_date(date)
    start_date = parse_date(start_date)
    end_date = parse_date(end_date)

    return false unless date && start_date && end_date

    date >= start_date && date <= end_date
  end

  # ヘルパーメソッド：日付を解析
  def self.parse_date(value)
    return value if value.is_a?(Date)
    return value.to_date if value.is_a?(Time) || value.is_a?(DateTime)

    # 文字列の場合
    if value.is_a?(String)
      # 空文字列の場合
      return nil if value.blank?

      # 日付形式を解析
      begin
        Date.parse(value)
      rescue ArgumentError
        nil
      end
    else
      nil
    end
  end
end
