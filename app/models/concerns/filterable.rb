module Filterable
  extend ActiveSupport::Concern

  included do
    # フィルタ可能なフィールドを定義するクラス変数
    class_attribute :filterable_fields, default: []

    # フィルタスコープを定義
    scope :filter_by, ->(filtering_params) { apply_filters(filtering_params) if filtering_params.present? }
  end

  class_methods do
    # フィルタ可能なフィールドを設定
    def filter_by(*fields)
      self.filterable_fields = fields
    end

    # フィルタを適用
    def apply_filters(filtering_params)
      results = all

      # パラメータが存在する場合のみ処理
      return results if filtering_params.blank?

      # フィルタ可能なフィールドでループ
      filterable_fields.each do |field|
        # パラメータに対応するフィールドが存在する場合
        if filtering_params[field].present?
          # フィールドの型に応じてフィルタ条件を変更
          column_type = columns_hash[field.to_s]&.type

          case column_type
          when :string, :text
            if filtering_params[field].is_a?(Array)
              results = results.where(field => filtering_params[field])
            else
              results = results.where("#{table_name}.#{field} = ?", filtering_params[field])
            end
          when :integer, :decimal, :float
            if filtering_params[field].is_a?(Array)
              results = results.where(field => filtering_params[field])
            else
              results = results.where("#{table_name}.#{field} = ?", filtering_params[field])
            end
          when :datetime, :date
            if filtering_params[field].is_a?(Array)
              dates = filtering_params[field].map { |d| Date.parse(d) rescue nil }.compact
              results = results.where(field => dates) if dates.any?
            else
              begin
                date = Date.parse(filtering_params[field])
                results = results.where("DATE(#{table_name}.#{field}) = ?", date)
              rescue ArgumentError
                # 日付の解析に失敗した場合は何もしない
              end
            end
          when :boolean
            bool_value = ActiveModel::Type::Boolean.new.cast(filtering_params[field])
            results = results.where("#{table_name}.#{field} = ?", bool_value)
          else
            if filtering_params[field].is_a?(Array)
              results = results.where(field => filtering_params[field])
            else
              results = results.where("#{table_name}.#{field} = ?", filtering_params[field])
            end
          end
        end
      end

      # 範囲フィルタ（from_XXX, to_XXX）
      filterable_fields.each do |field|
        column_type = columns_hash[field.to_s]&.type

        # 日付や数値の場合のみ範囲フィルタを適用
        if [:datetime, :date, :integer, :decimal, :float].include?(column_type)
          # From値が存在する場合
          if filtering_params["from_#{field}"].present?
            begin
              from_value = column_type.in?([:datetime, :date]) ? Date.parse(filtering_params["from_#{field}"]) : filtering_params["from_#{field}"]
              results = results.where("#{table_name}.#{field} >= ?", from_value)
            rescue ArgumentError
              # 変換に失敗した場合は何もしない
            end
          end

          # To値が存在する場合
          if filtering_params["to_#{field}"].present?
            begin
              to_value = column_type.in?([:datetime, :date]) ? Date.parse(filtering_params["to_#{field}"]) : filtering_params["to_#{field}"]
              results = results.where("#{table_name}.#{field} <= ?", to_value)
            rescue ArgumentError
              # 変換に失敗した場合は何もしない
            end
          end
        end
      end

      # NULL/NOT NULLフィルタ
      filterable_fields.each do |field|
        # NULL条件
        if filtering_params["#{field}_null"].present? && ActiveModel::Type::Boolean.new.cast(filtering_params["#{field}_null"])
          results = results.where("#{table_name}.#{field} IS NULL")
        end

        # NOT NULL条件
        if filtering_params["#{field}_not_null"].present? && ActiveModel::Type::Boolean.new.cast(filtering_params["#{field}_not_null"])
          results = results.where("#{table_name}.#{field} IS NOT NULL")
        end
      end

      # LIKE/NOT LIKEフィルタ（文字列フィールドのみ）
      filterable_fields.each do |field|
        column_type = columns_hash[field.to_s]&.type

        if [:string, :text].include?(column_type)
          # LIKE条件
          if filtering_params["#{field}_like"].present?
            results = results.where("#{table_name}.#{field} LIKE ?", "%#{filtering_params["#{field}_like"]}%")
          end

          # NOT LIKE条件
          if filtering_params["#{field}_not_like"].present?
            results = results.where("#{table_name}.#{field} NOT LIKE ?", "%#{filtering_params["#{field}_not_like"]}%")
          end
        end
      end

      # IN/NOT INフィルタ
      filterable_fields.each do |field|
        # IN条件
        if filtering_params["#{field}_in"].present? && filtering_params["#{field}_in"].is_a?(Array)
          results = results.where("#{table_name}.#{field} IN (?)", filtering_params["#{field}_in"])
        end

        # NOT IN条件
        if filtering_params["#{field}_not_in"].present? && filtering_params["#{field}_not_in"].is_a?(Array)
          results = results.where("#{table_name}.#{field} NOT IN (?)", filtering_params["#{field}_not_in"])
        end
      end

      results
    end

    # 動的フィルタリング
    def dynamic_filter(field, operator, value)
      return all if field.blank? || operator.blank?

      # フィールドがフィルタ可能かどうかを確認
      return all unless filterable_fields.include?(field.to_sym)

      # フィールドの型を取得
      column_type = columns_hash[field.to_s]&.type

      # 演算子に応じてフィルタ条件を構築
      case operator.to_s.downcase
      when 'eq', '='
        where("#{table_name}.#{field} = ?", value)
      when 'neq', '!='
        where("#{table_name}.#{field} != ?", value)
      when 'gt', '>'
        where("#{table_name}.#{field} > ?", value)
      when 'gte', '>='
        where("#{table_name}.#{field} >= ?", value)
      when 'lt', '<'
        where("#{table_name}.#{field} < ?", value)
      when 'lte', '<='
        where("#{table_name}.#{field} <= ?", value)
      when 'like'
        where("#{table_name}.#{field} LIKE ?", "%#{value}%")
      when 'not_like'
        where("#{table_name}.#{field} NOT LIKE ?", "%#{value}%")
      when 'in'
        value = value.is_a?(Array) ? value : [value]
        where("#{table_name}.#{field} IN (?)", value)
      when 'not_in'
        value = value.is_a?(Array) ? value : [value]
        where("#{table_name}.#{field} NOT IN (?)", value)
      when 'null'
        where("#{table_name}.#{field} IS NULL")
      when 'not_null'
        where("#{table_name}.#{field} IS NOT NULL")
      when 'between'
        if value.is_a?(Array) && value.size == 2
          where("#{table_name}.#{field} BETWEEN ? AND ?", value[0], value[1])
        else
          all
        end
      else
        all
      end
    end
  end
end
