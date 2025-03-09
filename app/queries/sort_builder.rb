class SortBuilder
  attr_reader :query_builder, :applied_sorts, :errors

  def initialize(query_builder)
    @query_builder = query_builder
    @applied_sorts = []
    @errors = []
    @sort_definitions = {}
    @default_sort = nil
  end

  # ソート定義を追加
  def define_sort(name, options = {})
    @sort_definitions[name.to_sym] = {
      field: options[:field] || name,
      table: options[:table],
      join: options[:join],
      direction: options[:direction] || :asc,
      nulls: options[:nulls], # :first or :last
      custom_sql: options[:custom_sql]
    }
    self
  end

  # 複数のソート定義を追加
  def define_sorts(definitions)
    definitions.each do |name, options|
      define_sort(name, options)
    end
    self
  end

  # デフォルトソートを設定
  def set_default_sort(name, direction = nil)
    if @sort_definitions.key?(name.to_sym)
      @default_sort = {
        name: name.to_sym,
        direction: direction || @sort_definitions[name.to_sym][:direction] || :asc
      }
    else
      @errors << "Sort '#{name}' is not defined"
    end
    self
  end

  # ソートを適用
  def apply_sort(name, direction = nil)
    name = name.to_sym

    # ソート定義が存在するか確認
    unless @sort_definitions.key?(name)
      @errors << "Sort '#{name}' is not defined"
      return self
    end

    sort = @sort_definitions[name]
    direction = direction&.to_sym || sort[:direction] || :asc

    # 方向が有効か確認
    unless [:asc, :desc].include?(direction)
      @errors << "Invalid sort direction '#{direction}'"
      return self
    end

    # JOINが必要な場合は適用
    if sort[:join]
      @query_builder.join_association(sort[:join])
    end

    # ソートを適用
    if sort[:custom_sql]
      # カスタムSQLでのソート
      @query_builder.order_by_raw(sort[:custom_sql], direction)
    else
      # 通常のソート
      field = sort[:field]
      table = sort[:table]

      # テーブルが指定されている場合はプレフィックスを追加
      field_with_prefix = table ? "#{table}.#{field}" : field

      # NULLSオプションがある場合
      if sort[:nulls]
        nulls_clause = sort[:nulls] == :first ? 'NULLS FIRST' : 'NULLS LAST'
        @query_builder.order_by_raw("#{field_with_prefix} #{direction.to_s.upcase} #{nulls_clause}")
      else
        @query_builder.order_by(field_with_prefix, direction)
      end
    end

    # 適用したソートを記録
    @applied_sorts << { name: name, direction: direction }

    self
  end

  # 複数のソートを適用
  def apply_sorts(sorts)
    sorts.each do |sort|
      if sort.is_a?(Hash)
        apply_sort(sort[:name], sort[:direction])
      else
        apply_sort(sort)
      end
    end
    self
  end

  # パラメータからソートを適用
  def apply_sort_from_params(params, sort_param = :sort, direction_param = :direction)
    sort_name = params[sort_param]
    direction = params[direction_param]

    if sort_name
      apply_sort(sort_name, direction)
    elsif @default_sort
      apply_sort(@default_sort[:name], @default_sort[:direction])
    end

    self
  end

  # 複数のパラメータからソートを適用
  def apply_sorts_from_params(params, sort_param = :sorts)
    sorts = params[sort_param]

    if sorts.present?
      if sorts.is_a?(Array)
        apply_sorts(sorts)
      elsif sorts.is_a?(Hash)
        sorts.each do |name, direction|
          apply_sort(name, direction)
        end
      end
    elsif @default_sort
      apply_sort(@default_sort[:name], @default_sort[:direction])
    end

    self
  end

  # 関連テーブルでソート
  def apply_association_sort(association, field, direction = :asc)
    @query_builder.join_association(association)

    table_name = association.to_s.pluralize
    @query_builder.order_by("#{table_name}.#{field}", direction)

    # 適用したソートを記録
    @applied_sorts << { name: "#{association}_#{field}", direction: direction }

    self
  end

  # 複数フィールドでソート
  def apply_multiple_fields_sort(fields)
    fields.each do |field|
      if field.is_a?(Hash)
        name = field[:field]
        direction = field[:direction] || :asc
        table = field[:table]

        field_with_prefix = table ? "#{table}.#{name}" : name
        @query_builder.order_by(field_with_prefix, direction)

        # 適用したソートを記録
        @applied_sorts << { name: name, direction: direction, table: table }
      else
        @query_builder.order_by(field)

        # 適用したソートを記録
        @applied_sorts << { name: field, direction: :asc }
      end
    end

    self
  end

  # カスタムSQLでソート
  def apply_raw_sort(sql)
    @query_builder.order_by_raw(sql)

    # 適用したソートを記録
    @applied_sorts << { name: :raw, sql: sql }

    self
  end

  # ランダムソート
  def apply_random_sort
    @query_builder.order_random

    # 適用したソートを記録
    @applied_sorts << { name: :random }

    self
  end

  # 集計関数でソート
  def apply_aggregate_sort(function, field, direction = :asc)
    unless [:count, :sum, :avg, :min, :max].include?(function.to_sym)
      @errors << "Invalid aggregate function '#{function}'"
      return self
    end

    @query_builder.order_by_raw("#{function.to_s.upcase}(#{field}) #{direction.to_s.upcase}")

    # 適用したソートを記録
    @applied_sorts << { name: "#{function}_#{field}", direction: direction }

    self
  end

  # CASE式でソート
  def apply_case_sort(cases, else_value = nil, direction = :asc)
    case_sql = "CASE"

    cases.each do |condition, value|
      case_sql += " WHEN #{condition} THEN #{value}"
    end

    case_sql += " ELSE #{else_value}" if else_value
    case_sql += " END"

    @query_builder.order_by_raw("#{case_sql} #{direction.to_s.upcase}")

    # 適用したソートを記録
    @applied_sorts << { name: :case, direction: direction }

    self
  end

  # 優先順位付きソート（指定した値の順序でソート）
  def apply_priority_sort(field, priorities, direction = :asc)
    case_sql = "CASE"

    priorities.each_with_index do |value, index|
      case_sql += " WHEN #{field} = '#{value}' THEN #{index}"
    end

    case_sql += " ELSE #{priorities.length}" # 指定されていない値は最後に
    case_sql += " END"

    @query_builder.order_by_raw("#{case_sql} #{direction.to_s.upcase}")

    # 適用したソートを記録
    @applied_sorts << { name: "priority_#{field}", direction: direction }

    self
  end

  # クエリビルダーを取得
  def get_query_builder
    @query_builder
  end

  # クエリを実行
  def execute
    @query_builder.execute
  end

  # ソートをリセット
  def reset
    @query_builder.reset
    @applied_sorts = []
    @errors = []
    self
  end

  # 利用可能なソートオプションを取得
  def available_sorts
    @sort_definitions.keys
  end

  # 現在適用されているソートを取得
  def current_sorts
    @applied_sorts
  end

  private

  # カスタムSQLでソート（内部メソッド）
  def order_by_raw(sql, direction = nil)
    sql_with_direction = direction ? "#{sql} #{direction.to_s.upcase}" : sql
    @query_builder.instance_variable_get(:@query).order(Arel.sql(sql_with_direction))
    @query_builder
  end
end
