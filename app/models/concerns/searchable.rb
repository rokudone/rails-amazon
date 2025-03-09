module Searchable
  extend ActiveSupport::Concern

  included do
    # 検索可能なフィールドを定義するクラス変数
    class_attribute :searchable_fields, default: []

    # 検索スコープを定義
    scope :search, ->(query) { search_by_query(query) if query.present? }
  end

  class_methods do
    # 検索可能なフィールドを設定
    def search_by(*fields)
      self.searchable_fields = fields
    end

    # クエリによる検索
    def search_by_query(query)
      return all if query.blank? || searchable_fields.empty?

      # 検索条件を構築
      conditions = searchable_fields.map do |field|
        table_name = self.table_name
        # フィールドの型に応じて検索条件を変更
        column_type = columns_hash[field.to_s]&.type

        case column_type
        when :string, :text
          "LOWER(#{table_name}.#{field}) LIKE LOWER(:query)"
        when :integer, :decimal, :float
          if query.to_s =~ /\A[+-]?\d+(\.\d+)?\z/
            "#{table_name}.#{field} = :exact_query"
          else
            "FALSE"
          end
        when :datetime, :date
          begin
            date = Date.parse(query)
            "DATE(#{table_name}.#{field}) = :date_query"
          rescue ArgumentError
            "FALSE"
          end
        else
          "CAST(#{table_name}.#{field} AS TEXT) LIKE :query"
        end
      end

      # 検索条件を結合
      where_clause = conditions.join(' OR ')

      # クエリを実行
      where(where_clause,
        query: "%#{sanitize_sql_like(query)}%",
        exact_query: query.to_f,
        date_query: query.to_date
      )
    end

    # 高度な検索
    def advanced_search(params)
      results = all

      # パラメータが存在する場合のみ処理
      return results if params.blank?

      # 検索可能なフィールドでループ
      searchable_fields.each do |field|
        # パラメータに対応するフィールドが存在する場合
        if params[field].present?
          # フィールドの型に応じて検索条件を変更
          column_type = columns_hash[field.to_s]&.type

          case column_type
          when :string, :text
            results = results.where("LOWER(#{table_name}.#{field}) LIKE LOWER(?)", "%#{sanitize_sql_like(params[field])}%")
          when :integer, :decimal, :float
            results = results.where("#{table_name}.#{field} = ?", params[field])
          when :datetime, :date
            begin
              date = Date.parse(params[field])
              results = results.where("DATE(#{table_name}.#{field}) = ?", date)
            rescue ArgumentError
              # 日付の解析に失敗した場合は何もしない
            end
          when :boolean
            bool_value = ActiveModel::Type::Boolean.new.cast(params[field])
            results = results.where("#{table_name}.#{field} = ?", bool_value)
          else
            results = results.where("#{table_name}.#{field} = ?", params[field])
          end
        end
      end

      # 範囲検索（from_XXX, to_XXX）
      searchable_fields.each do |field|
        column_type = columns_hash[field.to_s]&.type

        # 日付や数値の場合のみ範囲検索を適用
        if [:datetime, :date, :integer, :decimal, :float].include?(column_type)
          # From値が存在する場合
          if params["from_#{field}"].present?
            begin
              from_value = column_type.in?([:datetime, :date]) ? Date.parse(params["from_#{field}"]) : params["from_#{field}"]
              results = results.where("#{table_name}.#{field} >= ?", from_value)
            rescue ArgumentError
              # 変換に失敗した場合は何もしない
            end
          end

          # To値が存在する場合
          if params["to_#{field}"].present?
            begin
              to_value = column_type.in?([:datetime, :date]) ? Date.parse(params["to_#{field}"]) : params["to_#{field}"]
              results = results.where("#{table_name}.#{field} <= ?", to_value)
            rescue ArgumentError
              # 変換に失敗した場合は何もしない
            end
          end
        end
      end

      results
    end
  end

  # インスタンスメソッド

  # 検索条件に一致するかどうかを確認
  def matches_search?(query)
    return true if query.blank?

    self.class.searchable_fields.any? do |field|
      value = self.send(field)
      next false if value.nil?

      value.to_s.downcase.include?(query.to_s.downcase)
    end
  end
end
