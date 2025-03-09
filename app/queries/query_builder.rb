class QueryBuilder
  attr_reader :model, :query, :errors

  def initialize(model)
    @model = model
    @query = model.all
    @errors = []
    @joins = []
    @includes = []
    @where_clauses = []
    @order_clauses = []
    @group_clauses = []
    @having_clauses = []
    @select_clauses = []
    @limit_value = nil
    @offset_value = nil
  end

  # 条件を追加
  def where(conditions)
    @where_clauses << conditions
    @query = @query.where(conditions)
    self
  end

  # OR条件を追加
  def or_where(conditions)
    @query = @query.or(@model.where(conditions))
    self
  end

  # NOT条件を追加
  def not_where(conditions)
    @query = @query.where.not(conditions)
    self
  end

  # LIKE条件を追加
  def where_like(column, value)
    @query = @query.where("#{column} LIKE ?", "%#{value}%")
    self
  end

  # IN条件を追加
  def where_in(column, values)
    @query = @query.where(column => values)
    self
  end

  # NOT IN条件を追加
  def where_not_in(column, values)
    @query = @query.where.not(column => values)
    self
  end

  # NULL条件を追加
  def where_null(column)
    @query = @query.where("#{column} IS NULL")
    self
  end

  # NOT NULL条件を追加
  def where_not_null(column)
    @query = @query.where("#{column} IS NOT NULL")
    self
  end

  # BETWEEN条件を追加
  def where_between(column, start_value, end_value)
    @query = @query.where("#{column} BETWEEN ? AND ?", start_value, end_value)
    self
  end

  # 日付範囲条件を追加
  def where_date_between(column, start_date, end_date)
    @query = @query.where("#{column} BETWEEN ? AND ?", start_date.beginning_of_day, end_date.end_of_day)
    self
  end

  # 生のSQL条件を追加
  def where_raw(sql, *bindings)
    @query = @query.where(sql, *bindings)
    self
  end

  # ソート条件を追加
  def order_by(column, direction = :asc)
    @order_clauses << { column: column, direction: direction }
    @query = @query.order(column => direction)
    self
  end

  # 複数のソート条件を追加
  def order_by_multiple(orders)
    orders.each do |order|
      order_by(order[:column], order[:direction] || :asc)
    end
    self
  end

  # ランダムソート
  def order_random
    @query = @query.order('RANDOM()')
    self
  end

  # グループ化
  def group_by(columns)
    columns = [columns] unless columns.is_a?(Array)
    @group_clauses.concat(columns)
    @query = @query.group(columns)
    self
  end

  # HAVING条件を追加
  def having(conditions)
    @having_clauses << conditions
    @query = @query.having(conditions)
    self
  end

  # 生のHAVING条件を追加
  def having_raw(sql, *bindings)
    @query = @query.having(sql, *bindings)
    self
  end

  # JOINを追加
  def join(table, on_clause)
    @joins << { table: table, on: on_clause }
    @query = @query.joins("JOIN #{table} ON #{on_clause}")
    self
  end

  # LEFT JOINを追加
  def left_join(table, on_clause)
    @joins << { table: table, on: on_clause, type: 'LEFT' }
    @query = @query.joins("LEFT JOIN #{table} ON #{on_clause}")
    self
  end

  # RIGHT JOINを追加
  def right_join(table, on_clause)
    @joins << { table: table, on: on_clause, type: 'RIGHT' }
    @query = @query.joins("RIGHT JOIN #{table} ON #{on_clause}")
    self
  end

  # INNER JOINを追加
  def inner_join(table, on_clause)
    @joins << { table: table, on: on_clause, type: 'INNER' }
    @query = @query.joins("INNER JOIN #{table} ON #{on_clause}")
    self
  end

  # 関連テーブルのJOINを追加
  def join_association(association)
    @query = @query.joins(association)
    self
  end

  # INCLUDEを追加（Eager Loading）
  def include_association(associations)
    @includes.concat(Array(associations))
    @query = @query.includes(associations)
    self
  end

  # SELECT句を設定
  def select(columns)
    columns = [columns] unless columns.is_a?(Array)
    @select_clauses.concat(columns)
    @query = @query.select(columns)
    self
  end

  # DISTINCTを設定
  def distinct
    @query = @query.distinct
    self
  end

  # LIMITを設定
  def limit(value)
    @limit_value = value
    @query = @query.limit(value)
    self
  end

  # OFFSETを設定
  def offset(value)
    @offset_value = value
    @query = @query.offset(value)
    self
  end

  # ページネーション
  def paginate(page, per_page = 20)
    page = [1, page.to_i].max
    @limit_value = per_page
    @offset_value = (page - 1) * per_page
    @query = @query.limit(per_page).offset(@offset_value)
    self
  end

  # COUNT
  def count(column = '*')
    @query.count(column)
  end

  # SUM
  def sum(column)
    @query.sum(column)
  end

  # AVG
  def avg(column)
    @query.average(column)
  end

  # MIN
  def min(column)
    @query.minimum(column)
  end

  # MAX
  def max(column)
    @query.maximum(column)
  end

  # EXISTS
  def exists?
    @query.exists?
  end

  # 最初のレコードを取得
  def first
    @query.first
  end

  # 最後のレコードを取得
  def last
    @query.last
  end

  # 指定したIDのレコードを取得
  def find(id)
    @query.find(id)
  rescue ActiveRecord::RecordNotFound => e
    @errors << e.message
    nil
  end

  # 指定した条件の最初のレコードを取得
  def find_by(conditions)
    @query.find_by(conditions)
  end

  # 全てのレコードを取得
  def all
    @query.to_a
  end

  # クエリを実行
  def execute
    @query.to_a
  end

  # クエリをリセット
  def reset
    @query = @model.all
    @joins = []
    @includes = []
    @where_clauses = []
    @order_clauses = []
    @group_clauses = []
    @having_clauses = []
    @select_clauses = []
    @limit_value = nil
    @offset_value = nil
    self
  end

  # 生のSQLクエリを取得
  def to_sql
    @query.to_sql
  end

  # クエリの説明を取得
  def explain
    @query.explain
  end

  # トランザクションを開始
  def transaction(&block)
    @model.transaction(&block)
  end

  # クエリをコピー
  def copy
    clone = self.class.new(@model)
    clone.instance_variable_set(:@query, @query.clone)
    clone.instance_variable_set(:@joins, @joins.clone)
    clone.instance_variable_set(:@includes, @includes.clone)
    clone.instance_variable_set(:@where_clauses, @where_clauses.clone)
    clone.instance_variable_set(:@order_clauses, @order_clauses.clone)
    clone.instance_variable_set(:@group_clauses, @group_clauses.clone)
    clone.instance_variable_set(:@having_clauses, @having_clauses.clone)
    clone.instance_variable_set(:@select_clauses, @select_clauses.clone)
    clone.instance_variable_set(:@limit_value, @limit_value)
    clone.instance_variable_set(:@offset_value, @offset_value)
    clone
  end
end
