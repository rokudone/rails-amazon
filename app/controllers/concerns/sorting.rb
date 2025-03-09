module Sorting
  extend ActiveSupport::Concern

  included do
    # ソート関連の設定を定義するクラス変数
    class_attribute :sorting_options, default: {}

    # ヘルパーメソッドを定義
    helper_method :sort_params, :apply_sorting
  end

  class_methods do
    # ソート設定を構成
    def configure_sorting(options = {})
      self.sorting_options = {
        param_name: :sort,
        default_sort: nil,
        allowed_sorts: [],
        custom_sorts: {}
      }.merge(options)
    end

    # ソートを許可
    def allow_sorts(*sorts)
      self.sorting_options[:allowed_sorts] = sorts
    end

    # デフォルトソートを設定
    def default_sort(field, direction = :asc)
      self.sorting_options[:default_sort] = { field: field, direction: direction }
    end

    # カスタムソートを定義
    def custom_sort(name, handler)
      self.sorting_options[:custom_sorts][name.to_sym] = handler
    end
  end

  # ソートパラメータを取得
  def sort_params
    # ソートパラメータ名を取得
    param_name = sorting_options[:param_name]

    # パラメータからソートを取得
    sort_param = params[param_name]

    # ソートパラメータが存在しない場合はデフォルトを使用
    return sorting_options[:default_sort] if sort_param.blank?

    # ソートパラメータを解析
    if sort_param.is_a?(Hash)
      # ハッシュの場合
      field = sort_param[:field] || sort_param['field']
      direction = sort_param[:direction] || sort_param['direction'] || :asc
    else
      # 文字列の場合
      if sort_param.start_with?('-')
        # 降順
        field = sort_param[1..-1]
        direction = :desc
      else
        # 昇順
        field = sort_param
        direction = :asc
      end
    end

    # フィールドをシンボルに変換
    field = field.to_sym if field.is_a?(String)

    # 方向をシンボルに変換
    direction = direction.to_sym if direction.is_a?(String)

    # 許可されたソートのみを使用
    if sorting_options[:allowed_sorts].present? && !sorting_options[:allowed_sorts].include?(field)
      return sorting_options[:default_sort]
    end

    # ソートパラメータを返す
    { field: field, direction: direction }
  end

  # ソートを適用
  def apply_sorting(collection)
    # ソートパラメータを取得
    sort = sort_params

    # ソートパラメータが存在しない場合はコレクションをそのまま返す
    return collection if sort.nil?

    # フィールドと方向を取得
    field = sort[:field]
    direction = sort[:direction]

    # カスタムソートが定義されている場合
    if sorting_options[:custom_sorts][field].present?
      handler = sorting_options[:custom_sorts][field]

      # ハンドラがProcの場合
      if handler.is_a?(Proc)
        collection = handler.call(collection, direction)
      # ハンドラがシンボルまたは文字列の場合
      elsif handler.is_a?(Symbol) || handler.is_a?(String)
        collection = send(handler, collection, direction)
      end
    # モデルがSortableコンサーンを含んでいる場合
    elsif collection.respond_to?(:sort_by)
      collection = collection.sort_by(field, direction)
    # 標準のソート
    else
      collection = collection.order(field => direction)
    end

    collection
  end

  # 複数フィールドでソート
  def apply_multiple_sorting(collection, sorts)
    # ソートが空の場合はコレクションをそのまま返す
    return collection if sorts.blank?

    # ソートを適用
    sorts.each do |sort|
      # フィールドと方向を取得
      field = sort[:field]
      direction = sort[:direction] || :asc

      # カスタムソートが定義されている場合
      if sorting_options[:custom_sorts][field].present?
        handler = sorting_options[:custom_sorts][field]

        # ハンドラがProcの場合
        if handler.is_a?(Proc)
          collection = handler.call(collection, direction)
        # ハンドラがシンボルまたは文字列の場合
        elsif handler.is_a?(Symbol) || handler.is_a?(String)
          collection = send(handler, collection, direction)
        end
      # モデルがSortableコンサーンを含んでいる場合
      elsif collection.respond_to?(:sort_by)
        collection = collection.sort_by(field, direction)
      # 標準のソート
      else
        collection = collection.order(field => direction)
      end
    end

    collection
  end

  # 関連テーブルでソート
  def sort_by_association(collection, association, field, direction = :asc)
    collection.joins(association).order("#{association.to_s.pluralize}.#{field} #{direction}")
  end

  # カウントでソート
  def sort_by_count(collection, association, direction = :desc)
    collection.left_joins(association)
              .group("#{collection.table_name}.id")
              .order("COUNT(#{association.to_s.pluralize}.id) #{direction}")
  end

  # 複数フィールドの結合でソート
  def sort_by_multiple_fields(collection, fields, direction = :asc)
    order_clause = fields.map { |field| "#{field}" }.join(', ')
    collection.order(Arel.sql("#{order_clause} #{direction}"))
  end

  # NULLを最後にソート
  def sort_nulls_last(collection, field, direction = :asc)
    if direction.to_sym == :asc
      collection.order(Arel.sql("#{field} IS NULL, #{field} ASC"))
    else
      collection.order(Arel.sql("#{field} IS NULL, #{field} DESC"))
    end
  end

  # NULLを最初にソート
  def sort_nulls_first(collection, field, direction = :asc)
    if direction.to_sym == :asc
      collection.order(Arel.sql("#{field} IS NOT NULL, #{field} ASC"))
    else
      collection.order(Arel.sql("#{field} IS NOT NULL, #{field} DESC"))
    end
  end

  # ランダムソート
  def sort_random(collection, _direction = nil)
    collection.order(Arel.sql('RANDOM()'))
  end
end
