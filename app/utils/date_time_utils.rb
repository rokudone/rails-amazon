module DateTimeUtils
  class << self
    # 日付を指定されたフォーマットに変換
    def format_date(date, format = '%Y-%m-%d')
      return nil if date.nil?

      date = parse_date(date) unless date.is_a?(Date) || date.is_a?(Time) || date.is_a?(DateTime)
      date&.strftime(format)
    end

    # 日時を指定されたフォーマットに変換
    def format_datetime(datetime, format = '%Y-%m-%d %H:%M:%S')
      return nil if datetime.nil?

      datetime = parse_datetime(datetime) unless datetime.is_a?(Time) || datetime.is_a?(DateTime)
      datetime&.strftime(format)
    end

    # 文字列を日付オブジェクトに変換
    def parse_date(date_string)
      return nil if date_string.nil?
      return date_string if date_string.is_a?(Date) || date_string.is_a?(Time) || date_string.is_a?(DateTime)

      begin
        Date.parse(date_string.to_s)
      rescue ArgumentError
        nil
      end
    end

    # 文字列を日時オブジェクトに変換
    def parse_datetime(datetime_string)
      return nil if datetime_string.nil?
      return datetime_string if datetime_string.is_a?(Time) || datetime_string.is_a?(DateTime)

      begin
        Time.parse(datetime_string.to_s)
      rescue ArgumentError
        nil
      end
    end

    # 2つの日付の間の日数を計算
    def days_between(start_date, end_date)
      start_date = parse_date(start_date)
      end_date = parse_date(end_date)

      return nil if start_date.nil? || end_date.nil?

      (end_date - start_date).to_i
    end

    # 2つの日時の間の時間を計算（時間単位）
    def hours_between(start_time, end_time)
      start_time = parse_datetime(start_time)
      end_time = parse_datetime(end_time)

      return nil if start_time.nil? || end_time.nil?

      ((end_time - start_time) / 3600).to_f.round(2)
    end

    # 指定された日付が特定の期間内にあるかどうかを確認
    def within_period?(date, start_date, end_date)
      date = parse_date(date)
      start_date = parse_date(start_date)
      end_date = parse_date(end_date)

      return false if date.nil? || start_date.nil? || end_date.nil?

      date >= start_date && date <= end_date
    end

    # 日付に日数を追加
    def add_days(date, days)
      date = parse_date(date)
      return nil if date.nil?

      date + days
    end

    # 日時に時間を追加
    def add_hours(datetime, hours)
      datetime = parse_datetime(datetime)
      return nil if datetime.nil?

      datetime + (hours * 3600)
    end

    # 日付を別のタイムゾーンに変換
    def convert_timezone(datetime, from_zone = 'UTC', to_zone = 'Asia/Tokyo')
      datetime = parse_datetime(datetime)
      return nil if datetime.nil?

      from_tz = TZInfo::Timezone.get(from_zone)
      to_tz = TZInfo::Timezone.get(to_zone)

      from_time = from_tz.local_to_utc(datetime)
      to_tz.utc_to_local(from_time)
    end

    # 現在の日付を取得
    def today
      Date.today
    end

    # 現在の日時を取得
    def now
      Time.now
    end

    # 現在のUTC日時を取得
    def now_utc
      Time.now.utc
    end

    # 日付が週末かどうかを確認
    def weekend?(date)
      date = parse_date(date)
      return false if date.nil?

      date.saturday? || date.sunday?
    end

    # 日付が平日かどうかを確認
    def weekday?(date)
      !weekend?(date)
    end

    # 月の最初の日を取得
    def beginning_of_month(date)
      date = parse_date(date)
      return nil if date.nil?

      Date.new(date.year, date.month, 1)
    end

    # 月の最後の日を取得
    def end_of_month(date)
      date = parse_date(date)
      return nil if date.nil?

      Date.new(date.year, date.month, -1)
    end

    # 年齢を計算
    def calculate_age(birth_date, reference_date = Date.today)
      birth_date = parse_date(birth_date)
      reference_date = parse_date(reference_date)

      return nil if birth_date.nil? || reference_date.nil?

      age = reference_date.year - birth_date.year
      age -= 1 if reference_date < birth_date + age.years
      age
    end
  end
end
