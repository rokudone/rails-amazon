class UnionBuilder
  attr_reader :query_builders, :errors, :final_query

  def initialize
    @query_builders = []
    @errors = []
    @final_query = nil
    @union_type = :union_all
  end

  # クエリビルダーを追加
  def add_query_builder(query_builder)
    @query_builders << query_builder
    self
  end

  # 複数のクエリビルダーを追加
  def add_query_builders(query_builders)
    @query_builders.concat(query_builders)
    self
  end

  # UNIONタイプを設定（:union または :union_all）
  def set_union_type(type)
    if [:union, :union_all].include?(type.to_sym)
      @union_type = type.to_sym
    else
      @errors << "Invalid union type '#{type}'. Must be :union or :union_all"
    end
    self
  end

  # UNIONクエリを構築
  def build
    return nil if @query_builders.empty?

    # 各クエリビルダーからSQLを取得
    sql_queries = @query_builders.map { |qb| qb.to_sql }

    # UNIONタイプに基づいて結合
    union_keyword = @union_type == :union_all ? 'UNION ALL' : 'UNION'

    # 最終的なSQLを構築
    union_sql = sql_queries.join(" #{union_keyword} ")

    # ActiveRecord::Base.connection.execute(union_sql) を使用して実行することもできるが、
    # ここではシミュレーションのみ
    @final_query = union_sql

    self
  end

  # 結果を取得
  def execute
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # ActiveRecord::Base.connection.execute(@final_query)

    # シミュレーション用の結果
    { sql: @final_query, union_type: @union_type }
  end

  # 結果を配列として取得
  def to_a
    execute

    # 実際のアプリケーションでは、結果を配列に変換
    # result = execute
    # result.to_a

    # シミュレーション用の結果
    []
  end

  # 特定のモデルの結果として取得
  def as_model(model_class)
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # model_class.find_by_sql(@final_query)

    # シミュレーション用の結果
    []
  end

  # 結果をページネーション
  def paginate(page, per_page)
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # offset = (page - 1) * per_page
    # paginated_sql = "#{@final_query} LIMIT #{per_page} OFFSET #{offset}"
    # ActiveRecord::Base.connection.execute(paginated_sql)

    # シミュレーション用の結果
    { sql: "#{@final_query} LIMIT #{per_page} OFFSET #{(page - 1) * per_page}", page: page, per_page: per_page }
  end

  # 結果をソート
  def order(column, direction = :asc)
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # ordered_sql = "#{@final_query} ORDER BY #{column} #{direction.to_s.upcase}"
    # ActiveRecord::Base.connection.execute(ordered_sql)

    # シミュレーション用の結果
    { sql: "#{@final_query} ORDER BY #{column} #{direction.to_s.upcase}", column: column, direction: direction }
  end

  # 結果を制限
  def limit(value)
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # limited_sql = "#{@final_query} LIMIT #{value}"
    # ActiveRecord::Base.connection.execute(limited_sql)

    # シミュレーション用の結果
    { sql: "#{@final_query} LIMIT #{value}", limit: value }
  end

  # 結果をオフセット
  def offset(value)
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # offset_sql = "#{@final_query} OFFSET #{value}"
    # ActiveRecord::Base.connection.execute(offset_sql)

    # シミュレーション用の結果
    { sql: "#{@final_query} OFFSET #{value}", offset: value }
  end

  # 結果をグループ化
  def group(column)
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # grouped_sql = "#{@final_query} GROUP BY #{column}"
    # ActiveRecord::Base.connection.execute(grouped_sql)

    # シミュレーション用の結果
    { sql: "#{@final_query} GROUP BY #{column}", group: column }
  end

  # 結果にHAVING条件を適用
  def having(condition)
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # having_sql = "#{@final_query} HAVING #{condition}"
    # ActiveRecord::Base.connection.execute(having_sql)

    # シミュレーション用の結果
    { sql: "#{@final_query} HAVING #{condition}", having: condition }
  end

  # 結果の件数を取得
  def count
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # count_sql = "SELECT COUNT(*) FROM (#{@final_query}) AS union_subquery"
    # result = ActiveRecord::Base.connection.execute(count_sql)
    # result.first['count']

    # シミュレーション用の結果
    0
  end

  # 結果の最初のレコードを取得
  def first
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # first_sql = "#{@final_query} LIMIT 1"
    # result = ActiveRecord::Base.connection.execute(first_sql)
    # result.first

    # シミュレーション用の結果
    nil
  end

  # 結果の最後のレコードを取得
  def last
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # 最後のレコードを取得するには、ソートが必要
    # last_sql = "#{@final_query} ORDER BY id DESC LIMIT 1"
    # result = ActiveRecord::Base.connection.execute(last_sql)
    # result.first

    # シミュレーション用の結果
    nil
  end

  # 結果が存在するかどうかを確認
  def exists?
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # exists_sql = "SELECT EXISTS(#{@final_query}) AS exists"
    # result = ActiveRecord::Base.connection.execute(exists_sql)
    # result.first['exists'] == 1

    # シミュレーション用の結果
    false
  end

  # 結果をリセット
  def reset
    @query_builders = []
    @errors = []
    @final_query = nil
    @union_type = :union_all
    self
  end

  # 最終的なSQLを取得
  def to_sql
    build unless @final_query
    @final_query
  end

  # クエリの説明を取得
  def explain
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # explain_sql = "EXPLAIN #{@final_query}"
    # ActiveRecord::Base.connection.execute(explain_sql)

    # シミュレーション用の結果
    "EXPLAIN #{@final_query}"
  end

  # サブクエリとして使用するためのSQL
  def as_subquery(alias_name = 'subquery')
    build unless @final_query
    "(#{@final_query}) AS #{alias_name}"
  end

  # 特定のカラムのみを選択
  def select_columns(columns)
    build unless @final_query

    # カラムが配列の場合は結合
    columns_str = columns.is_a?(Array) ? columns.join(', ') : columns

    # 実際のアプリケーションでは、以下のようにして実行
    # select_sql = "SELECT #{columns_str} FROM (#{@final_query}) AS union_subquery"
    # ActiveRecord::Base.connection.execute(select_sql)

    # シミュレーション用の結果
    { sql: "SELECT #{columns_str} FROM (#{@final_query}) AS union_subquery", columns: columns }
  end

  # DISTINCTを適用
  def distinct
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # distinct_sql = "SELECT DISTINCT * FROM (#{@final_query}) AS union_subquery"
    # ActiveRecord::Base.connection.execute(distinct_sql)

    # シミュレーション用の結果
    { sql: "SELECT DISTINCT * FROM (#{@final_query}) AS union_subquery" }
  end

  # 特定のカラムでDISTINCTを適用
  def distinct_on(column)
    build unless @final_query

    # 実際のアプリケーションでは、以下のようにして実行
    # distinct_sql = "SELECT DISTINCT ON (#{column}) * FROM (#{@final_query}) AS union_subquery"
    # ActiveRecord::Base.connection.execute(distinct_sql)

    # シミュレーション用の結果
    { sql: "SELECT DISTINCT ON (#{column}) * FROM (#{@final_query}) AS union_subquery", column: column }
  end
end
