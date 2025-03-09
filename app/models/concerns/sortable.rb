module Sortable
  extend ActiveSupport::Concern

  included do
    # ソート可能なフィールドを定義するクラス変数
    class_attribute :sortable_fields, default: []
    class_attribute :default_sort_field, default: :created_at
    class_attribute :default_sort_direction, default: :desc

    # ソートスコープを定義
    scope :sorted, ->(field = nil, direction = nil) { sort_by(field, direction) }
  end

  class_methods do
    # ソート可能なフィールドを設定
    def sort_by(*fields, default_field: :created_at, default_direction: :desc)
      self.sortable_fields = fields
      self.default_sort_field = default_field
      self.default_sort_direction = default_direction
    end

    # フィールドとソート方向によるソート
    def sort_by(field = nil, direction = nil)
      # フィールドが指定されていない場合はデフォルトを使用
      field = field.present? ? field.to_sym : default_sort_field

      # ソート方向が指定されていない場合はデフォルトを使用
      direction = direction.present? ? direction.to_sym : default_sort_direction

      # ソート方向を正規化
      direction = [:asc, :desc].include?(direction) ? direction : default_sort_direction

      # ソート可能なフィールドかどうかを確認
      if sortable_fields.include?(field)
        order(field => direction)
      else
        # ソート可能なフィールドでない場合はデフォルトでソート
        order(default_sort_field => default_sort_direction)
      end
    end

    # 複数フィールドによるソート
    def sort_by_multiple(sort_params)
      return order(default_sort_field => default_sort_direction) if sort_params.blank?

      # ソートパラメータを解析
      sort_conditions = {}

      sort_params.each do |param|
        if param.is_a?(Hash)
          field = param[:field].to_sym
          direction = param[:direction].to_sym
        else
          parts = param.to_s.split('_')
          direction = parts.last.downcase.to_sym
          field = parts[0..-2].join('_').to_sym

          # 方向が有効でない場合はデフォルトを使用
          direction = [:asc, :desc].include?(direction) ? direction : default_sort_direction
        end

        # ソート可能なフィールドかどうかを確認
        if sortable_fields.include?(field)
          sort_conditions[field] = direction
        end
      end

      # ソート条件が空の場合はデフォルトでソート
      if sort_conditions.empty?
        order(default_sort_field => default_sort_direction)
      else
        order(sort_conditions)
      end
    end

    # ランダムソート
    def sort_random
      order('RANDOM()')
    end

    # 関連テーブルのフィールドでソート
    def sort_by_association(association, field, direction = :asc)
      joins(association).order("#{association.to_s.pluralize}.#{field} #{direction}")
    end
  end
end
