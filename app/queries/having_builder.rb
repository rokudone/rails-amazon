class HavingBuilder
  attr_reader :query_builder, :applied_havings, :errors

  def initialize(query_builder)
    @query_builder = query_builder
    @applied_havings = []
    @errors = []
    @having_definitions = {}
  end

  # HAVING定義を追加
  def define_having(name, options = {})
    @having_definitions[name.to_sym] = {
      field: options[:field] || name,
      function: options[:function],
      operator: options[:operator] || :eq,
      table: options[:table],
      expression: options[:expression]
    }
    self
  end

  # 複数のHAVING定義を追加
  def define_havings(definitions)
    definitions.each do |name, options|
      define_having(name, options)
    end
    self
  end

  # HAVINGを適用
  def apply_having(name, value)
    name = name.to_sym

    # HAVING定義が存在するか確認
    unless @having_definitions.key?(name)
      @errors << "Having '#{name}' is not defined"
      return self
    end

    having = @having_definitions[name]

    # HAVINGフィールドを構築
    if having[:expression]
      # 式を使用したHAVING
      expression = having[:expression]

      # 値を置換
      expression = expression.gsub('?', value.to_s)

      @query_builder.having_raw(expression)
    else
      # フィールドと関数を使用したHAVING
      field = having[:field]
      table = having[:table]
      function = having[:function]
      operator = having[:operator]

      # テーブルが指定されている場合はプレフィックスを追加
      field_with_prefix = table ? "#{table}.#{field}" : field

      # 関数が指定されている場合は適用
      field_expression = function ? "#{function.to_s.upcase}(#{field_with_prefix})" : field_with_prefix

      # 演算子に基づいてHAVING条件を構築
      case operator
      when :eq
        @query_builder.having("#{field_expression} = ?", value)
      when :not_eq
        @query_builder.having("#{field_expression} != ?", value)
      when :lt
        @query_builder.having("#{field_expression} < ?", value)
      when :lte
        @query_builder.having("#{field_expression} <= ?", value)
      when :gt
        @query_builder.having("#{field_expression} > ?", value)
      when :gte
        @query_builder.having("#{field_expression} >= ?", value)
      when :in
        @query_builder.having("#{field_expression} IN (?)", value)
      when :not_in
        @query_builder.having("#{field_expression} NOT IN (?)", value)
      when :between
        if value.is_a?(Array) && value.size == 2
          @query_builder.having("#{field_expression} BETWEEN ? AND ?", value[0], value[1])
        else
          @errors << "Between having requires an array with two values"
          return self
        end
      when :like
        @query_builder.having("#{field_expression} LIKE ?", "%#{value}%")
      when :not_like
        @query_builder.having("#{field_expression} NOT LIKE ?", "%#{value}%")
      when :null
        if value
          @query_builder.having("#{field_expression} IS NULL")
        else
          @query_builder.having("#{field_expression} IS NOT NULL")
        end
      else
        @errors << "Unknown operator '#{operator}' for having '#{name}'"
        return self
      end
    end

    # 適用したHAVINGを記録
    @applied_havings << { name: name, value: value }

    self
  end

  # 複数のHAVINGを適用
  def apply_havings(havings)
    havings.each do |having|
      if having.is_a?(Hash)
        apply_having(having[:name], having[:value])
      else
        apply_having(having, nil)
      end
    end
    self
  end

  # COUNT関数でHAVING
  def having_count(field, operator, value, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field

    case operator
    when :eq
      @query_builder.having("COUNT(#{field_with_prefix}) = ?", value)
    when :not_eq
      @query_builder.having("COUNT(#{field_with_prefix}) != ?", value)
    when :lt
      @query_builder.having("COUNT(#{field_with_prefix}) < ?", value)
    when :lte
      @query_builder.having("COUNT(#{field_with_prefix}) <= ?", value)
    when :gt
      @query_builder.having("COUNT(#{field_with_prefix}) > ?", value)
    when :gte
      @query_builder.having("COUNT(#{field_with_prefix}) >= ?", value)
    else
      @errors << "Unknown operator '#{operator}' for COUNT having"
      return self
    end

    # 適用したHAVINGを記録
    @applied_havings << { function: 'COUNT', field: field, table: table, operator: operator, value: value }

    self
  end

  # SUM関数でHAVING
  def having_sum(field, operator, value, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field

    case operator
    when :eq
      @query_builder.having("SUM(#{field_with_prefix}) = ?", value)
    when :not_eq
      @query_builder.having("SUM(#{field_with_prefix}) != ?", value)
    when :lt
      @query_builder.having("SUM(#{field_with_prefix}) < ?", value)
    when :lte
      @query_builder.having("SUM(#{field_with_prefix}) <= ?", value)
    when :gt
      @query_builder.having("SUM(#{field_with_prefix}) > ?", value)
    when :gte
      @query_builder.having("SUM(#{field_with_prefix}) >= ?", value)
    else
      @errors << "Unknown operator '#{operator}' for SUM having"
      return self
    end

    # 適用したHAVINGを記録
    @applied_havings << { function: 'SUM', field: field, table: table, operator: operator, value: value }

    self
  end

  # AVG関数でHAVING
  def having_avg(field, operator, value, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field

    case operator
    when :eq
      @query_builder.having("AVG(#{field_with_prefix}) = ?", value)
    when :not_eq
      @query_builder.having("AVG(#{field_with_prefix}) != ?", value)
    when :lt
      @query_builder.having("AVG(#{field_with_prefix}) < ?", value)
    when :lte
      @query_builder.having("AVG(#{field_with_prefix}) <= ?", value)
    when :gt
      @query_builder.having("AVG(#{field_with_prefix}) > ?", value)
    when :gte
      @query_builder.having("AVG(#{field_with_prefix}) >= ?", value)
    else
      @errors << "Unknown operator '#{operator}' for AVG having"
      return self
    end

    # 適用したHAVINGを記録
    @applied_havings << { function: 'AVG', field: field, table: table, operator: operator, value: value }

    self
  end

  # MIN関数でHAVING
  def having_min(field, operator, value, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field

    case operator
    when :eq
      @query_builder.having("MIN(#{field_with_prefix}) = ?", value)
    when :not_eq
      @query_builder.having("MIN(#{field_with_prefix}) != ?", value)
    when :lt
      @query_builder.having("MIN(#{field_with_prefix}) < ?", value)
    when :lte
      @query_builder.having("MIN(#{field_with_prefix}) <= ?", value)
    when :gt
      @query_builder.having("MIN(#{field_with_prefix}) > ?", value)
    when :gte
      @query_builder.having("MIN(#{field_with_prefix}) >= ?", value)
    else
      @errors << "Unknown operator '#{operator}' for MIN having"
      return self
    end

    # 適用したHAVINGを記録
    @applied_havings << { function: 'MIN', field: field, table: table, operator: operator, value: value }

    self
  end

  # MAX関数でHAVING
  def having_max(field, operator, value, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field

    case operator
    when :eq
      @query_builder.having("MAX(#{field_with_prefix}) = ?", value)
    when :not_eq
      @query_builder.having("MAX(#{field_with_prefix}) != ?", value)
    when :lt
      @query_builder.having("MAX(#{field_with_prefix}) < ?", value)
    when :lte
      @query_builder.having("MAX(#{field_with_prefix}) <= ?", value)
    when :gt
      @query_builder.having("MAX(#{field_with_prefix}) > ?", value)
    when :gte
      @query_builder.having("MAX(#{field_with_prefix}) >= ?", value)
    else
      @errors << "Unknown operator '#{operator}' for MAX having"
      return self
    end

    # 適用したHAVINGを記録
    @applied_havings << { function: 'MAX', field: field, table: table, operator: operator, value: value }

    self
  end

  # カスタム関数でHAVING
  def having_function(function, field, operator, value, table = nil)
    field_with_prefix = table ? "#{table}.#{field}" : field

    case operator
    when :eq
      @query_builder.having("#{function.to_s.upcase}(#{field_with_prefix}) = ?", value)
    when :not_eq
      @query_builder.having("#{function.to_s.upcase}(#{field_with_prefix}) != ?", value)
    when :lt
      @query_builder.having("#{function.to_s.upcase}(#{field_with_prefix}) < ?", value)
    when :lte
      @query_builder.having("#{function.to_s.upcase}(#{field_with_prefix}) <= ?", value)
    when :gt
      @query_builder.having("#{function.to_s.upcase}(#{field_with_prefix}) > ?", value)
    when :gte
      @query_builder.having("#{function.to_s.upcase}(#{field_with_prefix}) >= ?", value)
    else
      @errors << "Unknown operator '#{operator}' for #{function.to_s.upcase} having"
      return self
    end

    # 適用したHAVINGを記録
    @applied_havings << { function: function.to_s.upcase, field: field, table: table, operator: operator, value: value }

    self
  end

  # 生のHAVING条件を適用
  def having_raw(sql, *bindings)
    @query_builder.having_raw(sql, *bindings)

    # 適用したHAVINGを記録
    @applied_havings << { raw: sql, bindings: bindings }

    self
  end

  # 複合条件HAVING（AND条件）
  def having_and(conditions)
    return self if conditions.nil? || conditions.empty?

    sql_parts = []
    bindings = []

    conditions.each do |condition|
      field = condition[:field]
      function = condition[:function]
      operator = condition[:operator] || :eq
      value = condition[:value]
      table = condition[:table]

      field_with_prefix = table ? "#{table}.#{field}" : field
      field_expression = function ? "#{function.to_s.upcase}(#{field_with_prefix})" : field_with_prefix

      case operator
      when :eq
        sql_parts << "#{field_expression} = ?"
        bindings << value
      when :not_eq
        sql_parts << "#{field_expression} != ?"
        bindings << value
      when :lt
        sql_parts << "#{field_expression} < ?"
        bindings << value
      when :lte
        sql_parts << "#{field_expression} <= ?"
        bindings << value
      when :gt
        sql_parts << "#{field_expression} > ?"
        bindings << value
      when :gte
        sql_parts << "#{field_expression} >= ?"
        bindings << value
      when :in
        sql_parts << "#{field_expression} IN (?)"
        bindings << value
      when :not_in
        sql_parts << "#{field_expression} NOT IN (?)"
        bindings << value
      when :between
        if value.is_a?(Array) && value.size == 2
          sql_parts << "#{field_expression} BETWEEN ? AND ?"
          bindings.concat(value)
        else
          @errors << "Between having requires an array with two values"
        end
      when :like
        sql_parts << "#{field_expression} LIKE ?"
        bindings << "%#{value}%"
      when :not_like
        sql_parts << "#{field_expression} NOT LIKE ?"
        bindings << "%#{value}%"
      when :null
        if value
          sql_parts << "#{field_expression} IS NULL"
        else
          sql_parts << "#{field_expression} IS NOT NULL"
        end
      else
        @errors << "Unknown operator '#{operator}' for having condition"
      end
    end

    return self if sql_parts.empty?

    @query_builder.having_raw(sql_parts.join(' AND '), *bindings)

    # 適用したHAVINGを記録
    @applied_havings << { and_conditions: conditions }

    self
  end

  # 複合条件HAVING（OR条件）
  def having_or(conditions)
    return self if conditions.nil? || conditions.empty?

    sql_parts = []
    bindings = []

    conditions.each do |condition|
      field = condition[:field]
      function = condition[:function]
      operator = condition[:operator] || :eq
      value = condition[:value]
      table = condition[:table]

      field_with_prefix = table ? "#{table}.#{field}" : field
      field_expression = function ? "#{function.to_s.upcase}(#{field_with_prefix})" : field_with_prefix

      case operator
      when :eq
        sql_parts << "#{field_expression} = ?"
        bindings << value
      when :not_eq
        sql_parts << "#{field_expression} != ?"
        bindings << value
      when :lt
        sql_parts << "#{field_expression} < ?"
        bindings << value
      when :lte
        sql_parts << "#{field_expression} <= ?"
        bindings << value
      when :gt
        sql_parts << "#{field_expression} > ?"
        bindings << value
      when :gte
        sql_parts << "#{field_expression} >= ?"
        bindings << value
      when :in
        sql_parts << "#{field_expression} IN (?)"
        bindings << value
      when :not_in
        sql_parts << "#{field_expression} NOT IN (?)"
        bindings << value
      when :between
        if value.is_a?(Array) && value.size == 2
          sql_parts << "#{field_expression} BETWEEN ? AND ?"
          bindings.concat(value)
        else
          @errors << "Between having requires an array with two values"
        end
      when :like
        sql_parts << "#{field_expression} LIKE ?"
        bindings << "%#{value}%"
      when :not_like
        sql_parts << "#{field_expression} NOT LIKE ?"
        bindings << "%#{value}%"
      when :null
        if value
          sql_parts << "#{field_expression} IS NULL"
        else
          sql_parts << "#{field_expression} IS NOT NULL"
        end
      else
        @errors << "Unknown operator '#{operator}' for having condition"
      end
    end

    return self if sql_parts.empty?

    @query_builder.having_raw(sql_parts.join(' OR '), *bindings)

    # 適用したHAVINGを記録
    @applied_havings << { or_conditions: conditions }

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

  # HAVINGをリセット
  def reset
    @query_builder.reset
    @applied_havings = []
    @errors = []
    self
  end

  # 利用可能なHAVINGオプションを取得
  def available_havings
    @having_definitions.keys
  end

  # 現在適用されているHAVINGを取得
  def current_havings
    @applied_havings
  end
end
