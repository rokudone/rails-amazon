class FilterBuilder
  attr_reader :query_builder, :applied_filters, :errors

  def initialize(query_builder)
    @query_builder = query_builder
    @applied_filters = []
    @errors = []
    @filter_definitions = {}
  end

  # フィルタ定義を追加
  def define_filter(name, options = {}, &block)
    @filter_definitions[name.to_sym] = {
      field: options[:field] || name,
      type: options[:type] || :string,
      operator: options[:operator] || :eq,
      validator: options[:validator],
      transformer: options[:transformer],
      block: block
    }
    self
  end

  # 複数のフィルタ定義を追加
  def define_filters(definitions)
    definitions.each do |name, options|
      define_filter(name, options)
    end
    self
  end

  # フィルタを適用
  def apply_filter(name, value)
    name = name.to_sym

    # フィルタ定義が存在するか確認
    unless @filter_definitions.key?(name)
      @errors << "Filter '#{name}' is not defined"
      return self
    end

    # 値が空でないか確認
    if value.nil? || (value.respond_to?(:empty?) && value.empty?)
      return self
    end

    filter = @filter_definitions[name]

    # バリデーションを実行
    if filter[:validator] && !filter[:validator].call(value)
      @errors << "Invalid value for filter '#{name}'"
      return self
    end

    # 値を変換
    if filter[:transformer]
      value = filter[:transformer].call(value)
    end

    # カスタムブロックがある場合は実行
    if filter[:block]
      @query_builder = filter[:block].call(@query_builder, value)
    else
      # デフォルトのフィルタ処理
      field = filter[:field]
      operator = filter[:operator]

      case operator
      when :eq
        @query_builder.where("#{field} = ?", value)
      when :not_eq
        @query_builder.where("#{field} != ?", value)
      when :lt
        @query_builder.where("#{field} < ?", value)
      when :lte
        @query_builder.where("#{field} <= ?", value)
      when :gt
        @query_builder.where("#{field} > ?", value)
      when :gte
        @query_builder.where("#{field} >= ?", value)
      when :like
        @query_builder.where_like(field, value)
      when :not_like
        @query_builder.where("#{field} NOT LIKE ?", "%#{value}%")
      when :in
        @query_builder.where_in(field, value)
      when :not_in
        @query_builder.where_not_in(field, value)
      when :between
        if value.is_a?(Array) && value.size == 2
          @query_builder.where_between(field, value[0], value[1])
        else
          @errors << "Between filter requires an array with two values"
        end
      when :null
        value ? @query_builder.where_null(field) : @query_builder.where_not_null(field)
      else
        @errors << "Unknown operator '#{operator}' for filter '#{name}'"
        return self
      end
    end

    # 適用したフィルタを記録
    @applied_filters << { name: name, value: value }

    self
  end

  # 複数のフィルタを適用
  def apply_filters(filters)
    filters.each do |name, value|
      apply_filter(name, value)
    end
    self
  end

  # パラメータからフィルタを適用
  def apply_filters_from_params(params, filter_param = :filters)
    filters = params[filter_param] || {}
    apply_filters(filters)
    self
  end

  # 日付範囲フィルタを適用
  def apply_date_range_filter(field, start_date, end_date)
    return self if start_date.nil? && end_date.nil?

    if start_date && end_date
      @query_builder.where_date_between(field, start_date, end_date)
    elsif start_date
      @query_builder.where("#{field} >= ?", start_date.beginning_of_day)
    elsif end_date
      @query_builder.where("#{field} <= ?", end_date.end_of_day)
    end

    # 適用したフィルタを記録
    @applied_filters << { name: "#{field}_range", start_date: start_date, end_date: end_date }

    self
  end

  # 数値範囲フィルタを適用
  def apply_number_range_filter(field, min_value, max_value)
    return self if min_value.nil? && max_value.nil?

    if min_value && max_value
      @query_builder.where_between(field, min_value, max_value)
    elsif min_value
      @query_builder.where("#{field} >= ?", min_value)
    elsif max_value
      @query_builder.where("#{field} <= ?", max_value)
    end

    # 適用したフィルタを記録
    @applied_filters << { name: "#{field}_range", min_value: min_value, max_value: max_value }

    self
  end

  # 検索フィルタを適用（複数フィールドを検索）
  def apply_search_filter(search_term, fields)
    return self if search_term.nil? || search_term.empty? || fields.empty?

    conditions = fields.map { |field| "#{field} LIKE ?" }.join(' OR ')
    values = Array.new(fields.size, "%#{search_term}%")

    @query_builder.where_raw(conditions, *values)

    # 適用したフィルタを記録
    @applied_filters << { name: :search, value: search_term, fields: fields }

    self
  end

  # 関連テーブルのフィルタを適用
  def apply_association_filter(association, field, value, operator = :eq)
    return self if value.nil? || (value.respond_to?(:empty?) && value.empty?)

    @query_builder.join_association(association)

    case operator
    when :eq
      @query_builder.where("#{association.to_s.pluralize}.#{field} = ?", value)
    when :not_eq
      @query_builder.where("#{association.to_s.pluralize}.#{field} != ?", value)
    when :like
      @query_builder.where("#{association.to_s.pluralize}.#{field} LIKE ?", "%#{value}%")
    when :in
      @query_builder.where("#{association.to_s.pluralize}.#{field} IN (?)", value)
    else
      @errors << "Unknown operator '#{operator}' for association filter"
      return self
    end

    # 適用したフィルタを記録
    @applied_filters << { name: "#{association}_#{field}", value: value, operator: operator }

    self
  end

  # 複合条件フィルタを適用（AND条件）
  def apply_and_filter(filters)
    return self if filters.nil? || filters.empty?

    conditions = []
    values = []

    filters.each do |filter|
      field = filter[:field]
      value = filter[:value]
      operator = filter[:operator] || :eq

      next if value.nil? || (value.respond_to?(:empty?) && value.empty?)

      case operator
      when :eq
        conditions << "#{field} = ?"
        values << value
      when :not_eq
        conditions << "#{field} != ?"
        values << value
      when :lt
        conditions << "#{field} < ?"
        values << value
      when :lte
        conditions << "#{field} <= ?"
        values << value
      when :gt
        conditions << "#{field} > ?"
        values << value
      when :gte
        conditions << "#{field} >= ?"
        values << value
      when :like
        conditions << "#{field} LIKE ?"
        values << "%#{value}%"
      when :in
        conditions << "#{field} IN (?)"
        values << value
      when :null
        conditions << (value ? "#{field} IS NULL" : "#{field} IS NOT NULL")
      else
        @errors << "Unknown operator '#{operator}' for AND filter"
      end
    end

    return self if conditions.empty?

    @query_builder.where_raw(conditions.join(' AND '), *values)

    # 適用したフィルタを記録
    @applied_filters << { name: :and_filter, filters: filters }

    self
  end

  # 複合条件フィルタを適用（OR条件）
  def apply_or_filter(filters)
    return self if filters.nil? || filters.empty?

    conditions = []
    values = []

    filters.each do |filter|
      field = filter[:field]
      value = filter[:value]
      operator = filter[:operator] || :eq

      next if value.nil? || (value.respond_to?(:empty?) && value.empty?)

      case operator
      when :eq
        conditions << "#{field} = ?"
        values << value
      when :not_eq
        conditions << "#{field} != ?"
        values << value
      when :lt
        conditions << "#{field} < ?"
        values << value
      when :lte
        conditions << "#{field} <= ?"
        values << value
      when :gt
        conditions << "#{field} > ?"
        values << value
      when :gte
        conditions << "#{field} >= ?"
        values << value
      when :like
        conditions << "#{field} LIKE ?"
        values << "%#{value}%"
      when :in
        conditions << "#{field} IN (?)"
        values << value
      when :null
        conditions << (value ? "#{field} IS NULL" : "#{field} IS NOT NULL")
      else
        @errors << "Unknown operator '#{operator}' for OR filter"
      end
    end

    return self if conditions.empty?

    @query_builder.where_raw(conditions.join(' OR '), *values)

    # 適用したフィルタを記録
    @applied_filters << { name: :or_filter, filters: filters }

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

  # 最初のレコードを取得
  def first
    @query_builder.first
  end

  # 全てのレコードを取得
  def all
    @query_builder.all
  end

  # レコード数を取得
  def count
    @query_builder.count
  end

  # フィルタをリセット
  def reset
    @query_builder.reset
    @applied_filters = []
    @errors = []
    self
  end
end
