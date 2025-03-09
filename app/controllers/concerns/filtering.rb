module Filtering
  extend ActiveSupport::Concern

  included do
    # フィルタリング関連の設定を定義するクラス変数
    class_attribute :filtering_options, default: {}

    # ヘルパーメソッドを定義
    helper_method :filter_params, :apply_filters
  end

  class_methods do
    # フィルタリング設定を構成
    def configure_filtering(options = {})
      self.filtering_options = {
        param_name: :filter,
        allowed_filters: [],
        default_filters: {},
        custom_filters: {}
      }.merge(options)
    end

    # フィルタを許可
    def allow_filters(*filters)
      self.filtering_options[:allowed_filters] = filters
    end

    # デフォルトフィルタを設定
    def default_filter(name, value)
      self.filtering_options[:default_filters][name.to_sym] = value
    end

    # カスタムフィルタを定義
    def custom_filter(name, handler)
      self.filtering_options[:custom_filters][name.to_sym] = handler
    end
  end

  # フィルタパラメータを取得
  def filter_params
    # フィルタパラメータ名を取得
    param_name = filtering_options[:param_name]

    # パラメータからフィルタを取得
    filters = params[param_name].is_a?(Hash) ? params[param_name].to_unsafe_h : {}

    # シンボルキーに変換
    filters = filters.symbolize_keys

    # 許可されたフィルタのみを抽出
    if filtering_options[:allowed_filters].present?
      filters = filters.slice(*filtering_options[:allowed_filters])
    end

    # デフォルトフィルタをマージ
    filters = filtering_options[:default_filters].merge(filters)

    filters
  end

  # フィルタを適用
  def apply_filters(collection)
    # フィルタパラメータを取得
    filters = filter_params

    # フィルタが空の場合はコレクションをそのまま返す
    return collection if filters.empty?

    # フィルタを適用
    filtered_collection = collection

    # 各フィルタを処理
    filters.each do |key, value|
      # 値が空の場合はスキップ
      next if value.blank?

      # カスタムフィルタが定義されている場合
      if filtering_options[:custom_filters][key].present?
        handler = filtering_options[:custom_filters][key]

        # ハンドラがProcの場合
        if handler.is_a?(Proc)
          filtered_collection = handler.call(filtered_collection, value)
        # ハンドラがシンボルまたは文字列の場合
        elsif handler.is_a?(Symbol) || handler.is_a?(String)
          filtered_collection = send(handler, filtered_collection, value)
        end
      # モデルがFilterableコンサーンを含んでいる場合
      elsif filtered_collection.respond_to?(:filter_by)
        filtered_collection = filtered_collection.filter_by({ key => value })
      # 標準のフィルタリング
      else
        # 値が配列の場合
        if value.is_a?(Array)
          filtered_collection = filtered_collection.where(key => value)
        # 値がハッシュの場合
        elsif value.is_a?(Hash)
          value.each do |operator, operand|
            case operator.to_sym
            when :eq, :equals
              filtered_collection = filtered_collection.where(key => operand)
            when :not_eq, :not_equals
              filtered_collection = filtered_collection.where.not(key => operand)
            when :gt, :greater_than
              filtered_collection = filtered_collection.where("#{key} > ?", operand)
            when :gte, :greater_than_or_equal
              filtered_collection = filtered_collection.where("#{key} >= ?", operand)
            when :lt, :less_than
              filtered_collection = filtered_collection.where("#{key} < ?", operand)
            when :lte, :less_than_or_equal
              filtered_collection = filtered_collection.where("#{key} <= ?", operand)
            when :like
              filtered_collection = filtered_collection.where("#{key} LIKE ?", "%#{operand}%")
            when :not_like
              filtered_collection = filtered_collection.where("#{key} NOT LIKE ?", "%#{operand}%")
            when :in
              filtered_collection = filtered_collection.where(key => operand)
            when :not_in
              filtered_collection = filtered_collection.where.not(key => operand)
            when :null
              if ActiveModel::Type::Boolean.new.cast(operand)
                filtered_collection = filtered_collection.where(key => nil)
              else
                filtered_collection = filtered_collection.where.not(key => nil)
              end
            when :between
              if operand.is_a?(Array) && operand.size == 2
                filtered_collection = filtered_collection.where("#{key} BETWEEN ? AND ?", operand[0], operand[1])
              end
            end
          end
        # 値が文字列または数値の場合
        else
          filtered_collection = filtered_collection.where(key => value)
        end
      end
    end

    filtered_collection
  end

  # 範囲フィルタを適用
  def apply_range_filter(collection, field, min_value, max_value)
    # 最小値が指定されている場合
    if min_value.present?
      collection = collection.where("#{field} >= ?", min_value)
    end

    # 最大値が指定されている場合
    if max_value.present?
      collection = collection.where("#{field} <= ?", max_value)
    end

    collection
  end

  # 日付範囲フィルタを適用
  def apply_date_range_filter(collection, field, start_date, end_date)
    # 開始日が指定されている場合
    if start_date.present?
      begin
        start_date = Date.parse(start_date.to_s)
        collection = collection.where("#{field} >= ?", start_date)
      rescue ArgumentError
        # 日付の解析に失敗した場合は何もしない
      end
    end

    # 終了日が指定されている場合
    if end_date.present?
      begin
        end_date = Date.parse(end_date.to_s)
        collection = collection.where("#{field} <= ?", end_date)
      rescue ArgumentError
        # 日付の解析に失敗した場合は何もしない
      end
    end

    collection
  end

  # 検索フィルタを適用
  def apply_search_filter(collection, query, fields = nil)
    return collection if query.blank?

    # 検索対象のフィールドを取得
    fields ||= collection.column_names.select { |c| [:string, :text].include?(collection.columns_hash[c]&.type) }

    # 検索条件を構築
    conditions = fields.map { |field| "#{field} LIKE ?" }
    values = Array.new(fields.size, "%#{query}%")

    # 検索を実行
    collection.where(conditions.join(' OR '), *values)
  end

  # 関連フィルタを適用
  def apply_association_filter(collection, association, conditions)
    collection.joins(association).where(association => conditions)
  end
end
