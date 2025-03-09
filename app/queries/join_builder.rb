class JoinBuilder
  attr_reader :query_builder, :applied_joins, :errors

  def initialize(query_builder)
    @query_builder = query_builder
    @applied_joins = []
    @errors = []
    @join_definitions = {}
  end

  # 結合定義を追加
  def define_join(name, options = {})
    @join_definitions[name.to_sym] = {
      table: options[:table] || name,
      alias_name: options[:alias],
      type: options[:type] || :inner,
      on: options[:on],
      foreign_key: options[:foreign_key],
      primary_key: options[:primary_key] || 'id',
      association: options[:association],
      conditions: options[:conditions]
    }
    self
  end

  # 複数の結合定義を追加
  def define_joins(definitions)
    definitions.each do |name, options|
      define_join(name, options)
    end
    self
  end

  # 結合を適用
  def apply_join(name, additional_conditions = nil)
    name = name.to_sym

    # 結合定義が存在するか確認
    unless @join_definitions.key?(name)
      @errors << "Join '#{name}' is not defined"
      return self
    end

    join = @join_definitions[name]

    # 結合タイプを確認
    join_type = join[:type].to_s.upcase
    unless ['INNER', 'LEFT', 'RIGHT', 'FULL'].include?(join_type)
      join_type = 'INNER'
    end

    # 結合条件を構築
    if join[:association]
      # アソシエーションを使用した結合
      @query_builder.join_association(join[:association])
    elsif join[:on]
      # ON句を使用した結合
      on_clause = join[:on]

      # 追加条件がある場合は追加
      if additional_conditions
        on_clause = "(#{on_clause}) AND (#{additional_conditions})"
      end

      # 条件が定義されている場合は追加
      if join[:conditions]
        on_clause = "(#{on_clause}) AND (#{join[:conditions]})"
      end

      # テーブル名とエイリアスを構築
      table_with_alias = join[:alias_name] ? "#{join[:table]} AS #{join[:alias_name]}" : join[:table]

      # 結合を適用
      case join_type
      when 'INNER'
        @query_builder.inner_join(table_with_alias, on_clause)
      when 'LEFT'
        @query_builder.left_join(table_with_alias, on_clause)
      when 'RIGHT'
        @query_builder.right_join(table_with_alias, on_clause)
      when 'FULL'
        @query_builder.join("FULL JOIN #{table_with_alias} ON #{on_clause}")
      end
    elsif join[:foreign_key] && join[:primary_key]
      # 外部キーと主キーを使用した結合
      table_name = @query_builder.model.table_name
      join_table = join[:table]
      foreign_key = join[:foreign_key]
      primary_key = join[:primary_key]

      # テーブル名とエイリアスを構築
      join_table_with_alias = join[:alias_name] ? "#{join_table} AS #{join[:alias_name]}" : join_table
      join_table_name = join[:alias_name] || join_table

      # ON句を構築
      on_clause = "#{table_name}.#{foreign_key} = #{join_table_name}.#{primary_key}"

      # 追加条件がある場合は追加
      if additional_conditions
        on_clause = "(#{on_clause}) AND (#{additional_conditions})"
      end

      # 条件が定義されている場合は追加
      if join[:conditions]
        on_clause = "(#{on_clause}) AND (#{join[:conditions]})"
      end

      # 結合を適用
      case join_type
      when 'INNER'
        @query_builder.inner_join(join_table_with_alias, on_clause)
      when 'LEFT'
        @query_builder.left_join(join_table_with_alias, on_clause)
      when 'RIGHT'
        @query_builder.right_join(join_table_with_alias, on_clause)
      when 'FULL'
        @query_builder.join("FULL JOIN #{join_table_with_alias} ON #{on_clause}")
      end
    else
      @errors << "Join '#{name}' has no valid join condition"
      return self
    end

    # 適用した結合を記録
    @applied_joins << { name: name, type: join_type, conditions: additional_conditions }

    self
  end

  # 複数の結合を適用
  def apply_joins(joins)
    joins.each do |join|
      if join.is_a?(Hash)
        apply_join(join[:name], join[:conditions])
      else
        apply_join(join)
      end
    end
    self
  end

  # 内部結合を適用
  def apply_inner_join(table, on_clause)
    @query_builder.inner_join(table, on_clause)

    # 適用した結合を記録
    @applied_joins << { table: table, type: 'INNER', on: on_clause }

    self
  end

  # 左外部結合を適用
  def apply_left_join(table, on_clause)
    @query_builder.left_join(table, on_clause)

    # 適用した結合を記録
    @applied_joins << { table: table, type: 'LEFT', on: on_clause }

    self
  end

  # 右外部結合を適用
  def apply_right_join(table, on_clause)
    @query_builder.right_join(table, on_clause)

    # 適用した結合を記録
    @applied_joins << { table: table, type: 'RIGHT', on: on_clause }

    self
  end

  # 完全外部結合を適用
  def apply_full_join(table, on_clause)
    @query_builder.join("FULL JOIN #{table} ON #{on_clause}")

    # 適用した結合を記録
    @applied_joins << { table: table, type: 'FULL', on: on_clause }

    self
  end

  # 交差結合を適用
  def apply_cross_join(table)
    @query_builder.join("CROSS JOIN #{table}")

    # 適用した結合を記録
    @applied_joins << { table: table, type: 'CROSS' }

    self
  end

  # 自己結合を適用
  def apply_self_join(alias_name, on_clause, type = :inner)
    table_name = @query_builder.model.table_name

    # 結合タイプを確認
    join_type = type.to_s.upcase
    unless ['INNER', 'LEFT', 'RIGHT', 'FULL'].include?(join_type)
      join_type = 'INNER'
    end

    # 結合を適用
    case join_type
    when 'INNER'
      @query_builder.inner_join("#{table_name} AS #{alias_name}", on_clause)
    when 'LEFT'
      @query_builder.left_join("#{table_name} AS #{alias_name}", on_clause)
    when 'RIGHT'
      @query_builder.right_join("#{table_name} AS #{alias_name}", on_clause)
    when 'FULL'
      @query_builder.join("FULL JOIN #{table_name} AS #{alias_name} ON #{on_clause}")
    end

    # 適用した結合を記録
    @applied_joins << { table: table_name, alias: alias_name, type: join_type, on: on_clause, self_join: true }

    self
  end

  # 条件付き結合を適用
  def apply_conditional_join(name, condition, additional_conditions = nil)
    # 条件が真の場合のみ結合を適用
    apply_join(name, additional_conditions) if condition

    self
  end

  # 複数テーブル結合を適用
  def apply_multiple_joins(tables, common_key = 'id', type = :inner)
    return self if tables.nil? || tables.empty?

    base_table = @query_builder.model.table_name

    tables.each do |table|
      foreign_key = "#{table.singularize}_id"

      # 結合タイプを確認
      join_type = type.to_s.upcase
      unless ['INNER', 'LEFT', 'RIGHT', 'FULL'].include?(join_type)
        join_type = 'INNER'
      end

      # ON句を構築
      on_clause = "#{base_table}.#{foreign_key} = #{table}.#{common_key}"

      # 結合を適用
      case join_type
      when 'INNER'
        @query_builder.inner_join(table, on_clause)
      when 'LEFT'
        @query_builder.left_join(table, on_clause)
      when 'RIGHT'
        @query_builder.right_join(table, on_clause)
      when 'FULL'
        @query_builder.join("FULL JOIN #{table} ON #{on_clause}")
      end

      # 適用した結合を記録
      @applied_joins << { table: table, type: join_type, on: on_clause }
    end

    self
  end

  # 多対多結合を適用
  def apply_many_to_many_join(join_table, target_table, source_fk, target_fk, type = :inner)
    base_table = @query_builder.model.table_name

    # 結合タイプを確認
    join_type = type.to_s.upcase
    unless ['INNER', 'LEFT', 'RIGHT', 'FULL'].include?(join_type)
      join_type = 'INNER'
    end

    # 中間テーブルとの結合
    join_on_clause = "#{base_table}.id = #{join_table}.#{source_fk}"

    # 結合を適用
    case join_type
    when 'INNER'
      @query_builder.inner_join(join_table, join_on_clause)
    when 'LEFT'
      @query_builder.left_join(join_table, join_on_clause)
    when 'RIGHT'
      @query_builder.right_join(join_table, join_on_clause)
    when 'FULL'
      @query_builder.join("FULL JOIN #{join_table} ON #{join_on_clause}")
    end

    # 適用した結合を記録
    @applied_joins << { table: join_table, type: join_type, on: join_on_clause }

    # ターゲットテーブルとの結合
    target_on_clause = "#{join_table}.#{target_fk} = #{target_table}.id"

    # 結合を適用
    case join_type
    when 'INNER'
      @query_builder.inner_join(target_table, target_on_clause)
    when 'LEFT'
      @query_builder.left_join(target_table, target_on_clause)
    when 'RIGHT'
      @query_builder.right_join(target_table, target_on_clause)
    when 'FULL'
      @query_builder.join("FULL JOIN #{target_table} ON #{target_on_clause}")
    end

    # 適用した結合を記録
    @applied_joins << { table: target_table, type: join_type, on: target_on_clause }

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

  # 結合をリセット
  def reset
    @query_builder.reset
    @applied_joins = []
    @errors = []
    self
  end

  # 利用可能な結合オプションを取得
  def available_joins
    @join_definitions.keys
  end

  # 現在適用されている結合を取得
  def current_joins
    @applied_joins
  end
end
