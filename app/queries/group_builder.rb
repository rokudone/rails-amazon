class GroupBuilder
  attr_reader :query_builder, :applied_groups, :errors

  def initialize(query_builder)
    @query_builder = query_builder
    @applied_groups = []
    @errors = []
    @group_definitions = {}
  end

  # グループ定義を追加
  def define_group(name, options = {})
    @group_definitions[name.to_sym] = {
      field: options[:field] || name,
      table: options[:table],
      expression: options[:expression],
      alias_name: options[:alias],
      format: options[:format]
    }
    self
  end

  # 複数のグループ定義を追加
  def define_groups(definitions)
    definitions.each do |name, options|
      define_group(name, options)
    end
    self
  end

  # グループを適用
  def apply_group(name)
    name = name.to_sym

    # グループ定義が存在するか確認
    unless @group_definitions.key?(name)
      @errors << "Group '#{name}' is not defined"
      return self
    end

    group = @group_definitions[name]

    # グループ化フィールドを構築
    if group[:expression]
      # 式を使用したグループ化
      expression = group[:expression]

      # エイリアスがある場合は追加
      if group[:alias_name]
        @query_builder.select("#{expression} AS #{group[:alias_name]}")
        @query_builder.group_by(group[:alias_name])
      else
        @query_builder.group_by(expression)
      end
    else
      # フィールドを使用したグループ化
      field = group[:field]
      table = group[:table]

      # テーブルが指定されている場合はプレフィックスを追加
      field_with_prefix = table ? "#{table}.#{field}" : field

      # フォーマットが指定されている場合は適用
      if group[:format]
        formatted_field = format_field(field_with_prefix, group[:format])

        # エイリアスがある場合は追加
        if group[:alias_name]
          @query_builder.select("#{formatted_field} AS #{group[:alias_name]}")
          @query_builder.group_by(group[:alias_name])
        else
          @query_builder.select(formatted_field)
          @query_builder.group_by(formatted_field)
        end
      else
        @query_builder.group_by(field_with_prefix)
      end
    end

    # 適用したグループを記録
    @applied_groups << { name: name }

    self
  end

  # 複数のグループを適用
  def apply_groups(groups)
    groups.each do |group|
      if group.is_a?(Hash)
        apply_group(group[:name])
      else
        apply_group(group)
      end
    end
    self
  end

  # フィールドでグループ化
  def group_by_field(field, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field
    @query_builder.group_by(field_with_prefix)

    # 適用したグループを記録
    @applied_groups << { field: field, table: table }

    self
  end

  # 複数フィールドでグループ化
  def group_by_fields(fields)
    fields.each do |field|
      if field.is_a?(Hash)
        group_by_field(field[:field], field[:table])
      else
        group_by_field(field)
      end
    end
    self
  end

  # 日付フィールドでグループ化（日単位）
  def group_by_date(field, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field
    expression = date_format_expression(field_with_prefix, 'day')

    @query_builder.select("#{expression} AS date_group")
    @query_builder.group_by('date_group')

    # 適用したグループを記録
    @applied_groups << { field: field, table: table, format: 'day' }

    self
  end

  # 日付フィールドでグループ化（週単位）
  def group_by_week(field, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field
    expression = date_format_expression(field_with_prefix, 'week')

    @query_builder.select("#{expression} AS week_group")
    @query_builder.group_by('week_group')

    # 適用したグループを記録
    @applied_groups << { field: field, table: table, format: 'week' }

    self
  end

  # 日付フィールドでグループ化（月単位）
  def group_by_month(field, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field
    expression = date_format_expression(field_with_prefix, 'month')

    @query_builder.select("#{expression} AS month_group")
    @query_builder.group_by('month_group')

    # 適用したグループを記録
    @applied_groups << { field: field, table: table, format: 'month' }

    self
  end

  # 日付フィールドでグループ化（年単位）
  def group_by_year(field, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field
    expression = date_format_expression(field_with_prefix, 'year')

    @query_builder.select("#{expression} AS year_group")
    @query_builder.group_by('year_group')

    # 適用したグループを記録
    @applied_groups << { field: field, table: table, format: 'year' }

    self
  end

  # 時間帯でグループ化
  def group_by_hour(field, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field
    expression = date_format_expression(field_with_prefix, 'hour')

    @query_builder.select("#{expression} AS hour_group")
    @query_builder.group_by('hour_group')

    # 適用したグループを記録
    @applied_groups << { field: field, table: table, format: 'hour' }

    self
  end

  # 曜日でグループ化
  def group_by_day_of_week(field, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field
    expression = date_format_expression(field_with_prefix, 'day_of_week')

    @query_builder.select("#{expression} AS day_of_week_group")
    @query_builder.group_by('day_of_week_group')

    # 適用したグループを記録
    @applied_groups << { field: field, table: table, format: 'day_of_week' }

    self
  end

  # 数値範囲でグループ化
  def group_by_range(field, ranges, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field

    case_expression = "CASE"
    ranges.each_with_index do |range, index|
      min = range[:min]
      max = range[:max]
      label = range[:label] || "Range #{index + 1}"

      if min.nil? && max.nil?
        next
      elsif min.nil?
        case_expression += " WHEN #{field_with_prefix} <= #{max} THEN '#{label}'"
      elsif max.nil?
        case_expression += " WHEN #{field_with_prefix} > #{min} THEN '#{label}'"
      else
        case_expression += " WHEN #{field_with_prefix} > #{min} AND #{field_with_prefix} <= #{max} THEN '#{label}'"
      end
    end
    case_expression += " ELSE 'Other' END"

    @query_builder.select("#{case_expression} AS range_group")
    @query_builder.group_by('range_group')

    # 適用したグループを記録
    @applied_groups << { field: field, table: table, ranges: ranges }

    self
  end

  # カスタム式でグループ化
  def group_by_expression(expression, alias_name = nil)
    if alias_name
      @query_builder.select("#{expression} AS #{alias_name}")
      @query_builder.group_by(alias_name)
    else
      @query_builder.group_by(expression)
    end

    # 適用したグループを記録
    @applied_groups << { expression: expression, alias: alias_name }

    self
  end

  # 集計関数を追加
  def add_aggregate(function, field, alias_name = nil, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field

    # 関数が有効か確認
    unless [:count, :sum, :avg, :min, :max].include?(function.to_sym)
      @errors << "Invalid aggregate function '#{function}'"
      return self
    end

    # 集計式を構築
    aggregate_expression = "#{function.to_s.upcase}(#{field_with_prefix})"

    # エイリアスがある場合は追加
    if alias_name
      @query_builder.select("#{aggregate_expression} AS #{alias_name}")
    else
      @query_builder.select(aggregate_expression)
    end

    self
  end

  # COUNT集計を追加
  def add_count(field = '*', alias_name = 'count', table = nil)
    add_aggregate(:count, field, alias_name, table)
  end

  # SUM集計を追加
  def add_sum(field, alias_name = 'sum', table = nil)
    add_aggregate(:sum, field, alias_name, table)
  end

  # AVG集計を追加
  def add_avg(field, alias_name = 'avg', table = nil)
    add_aggregate(:avg, field, alias_name, table)
  end

  # MIN集計を追加
  def add_min(field, alias_name = 'min', table = nil)
    add_aggregate(:min, field, alias_name, table)
  end

  # MAX集計を追加
  def add_max(field, alias_name = 'max', table = nil)
    add_aggregate(:max, field, alias_name, table)
  end

  # クエリビルダーを取得
  def get_query_builder
    @query_builder
  end

  # クエリを実行
  def execute
    @query_builder.execute
  end

  # グループをリセット
  def reset
    @query_builder.reset
    @applied_groups = []
    @errors = []
    self
  end

  # 利用可能なグループオプションを取得
  def available_groups
    @group_definitions.keys
  end

  # 現在適用されているグループを取得
  def current_groups
    @applied_groups
  end

  private

  # フィールドをフォーマット
  def format_field(field, format)
    case format.to_sym
    when :day
      date_format_expression(field, 'day')
    when :week
      date_format_expression(field, 'week')
    when :month
      date_format_expression(field, 'month')
    when :year
      date_format_expression(field, 'year')
    when :hour
      date_format_expression(field, 'hour')
    when :day_of_week
      date_format_expression(field, 'day_of_week')
    else
      field
    end
  end

  # 日付フォーマット式を取得（データベース依存）
  def date_format_expression(field, format)
    # SQLiteの場合
    case format
    when 'day'
      "strftime('%Y-%m-%d', #{field})"
    when 'week'
      "strftime('%Y-%W', #{field})"
    when 'month'
      "strftime('%Y-%m', #{field})"
    when 'year'
      "strftime('%Y', #{field})"
    when 'hour'
      "strftime('%H', #{field})"
    when 'day_of_week'
      "strftime('%w', #{field})"
    else
      field
    end

    # MySQLの場合は以下のようになる
    # case format
    # when 'day'
    #   "DATE(#{field})"
    # when 'week'
    #   "YEARWEEK(#{field}, 1)"
    # when 'month'
    #   "DATE_FORMAT(#{field}, '%Y-%m')"
    # when 'year'
    #   "YEAR(#{field})"
    # when 'hour'
    #   "HOUR(#{field})"
    # when 'day_of_week'
    #   "DAYOFWEEK(#{field})"
    # else
    #   field
    # end
  end
end
