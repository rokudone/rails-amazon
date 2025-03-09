module Taggable
  extend ActiveSupport::Concern

  included do
    # タグ関連の関連付けを定義
    has_many :taggings, as: :taggable, dependent: :destroy
    has_many :tags, through: :taggings

    # コールバックを設定
    after_save :save_tags, if: :tags_changed?

    # インスタンス変数を定義
    attr_accessor :tag_list_cache
  end

  class_methods do
    # タグ付けされたレコードを検索
    def tagged_with(tag_name)
      tag = Tag.find_by(name: tag_name)
      return none unless tag

      joins(:taggings).where(taggings: { tag_id: tag.id })
    end

    # 複数のタグで検索
    def tagged_with_all(tag_names)
      return none if tag_names.blank?

      # タグIDを取得
      tag_ids = Tag.where(name: tag_names).pluck(:id)
      return none if tag_ids.size != tag_names.size

      # サブクエリを構築
      taggable_ids = Tagging.where(tag_id: tag_ids, taggable_type: name)
                            .group(:taggable_id)
                            .having("COUNT(DISTINCT tag_id) = ?", tag_ids.size)
                            .pluck(:taggable_id)

      where(id: taggable_ids)
    end

    # いずれかのタグで検索
    def tagged_with_any(tag_names)
      return none if tag_names.blank?

      # タグIDを取得
      tag_ids = Tag.where(name: tag_names).pluck(:id)
      return none if tag_ids.empty?

      # クエリを構築
      joins(:taggings).where(taggings: { tag_id: tag_ids }).distinct
    end

    # 人気のタグを取得
    def popular_tags(limit = 10)
      Tag.joins(:taggings)
         .where(taggings: { taggable_type: name })
         .group('tags.id')
         .order('COUNT(taggings.id) DESC')
         .limit(limit)
    end

    # タグクラウドを生成
    def tag_cloud(limit = 20)
      tags = popular_tags(limit)

      # タグの使用回数を取得
      counts = Tagging.where(tag_id: tags.map(&:id), taggable_type: name)
                     .group(:tag_id)
                     .count

      # 最小値と最大値を取得
      min_count = counts.values.min || 0
      max_count = counts.values.max || 0

      # 重み付けを計算
      tags.map do |tag|
        count = counts[tag.id] || 0
        weight = min_count == max_count ? 1 : (count - min_count).to_f / (max_count - min_count)

        {
          tag: tag,
          count: count,
          weight: weight
        }
      end
    end
  end

  # インスタンスメソッド

  # タグリストを取得
  def tag_list
    @tag_list_cache ||= tags.map(&:name).join(', ')
  end

  # タグリストを設定
  def tag_list=(value)
    @tag_list_cache = value
    @tags_changed = true
  end

  # タグが変更されたかどうかをチェック
  def tags_changed?
    @tags_changed || false
  end

  # タグを保存
  def save_tags
    return unless @tag_list_cache

    # 現在のタグを取得
    current_tags = tags.map(&:name)

    # 新しいタグを解析
    new_tags = parse_tag_list(@tag_list_cache)

    # 追加するタグと削除するタグを計算
    tags_to_add = new_tags - current_tags
    tags_to_remove = current_tags - new_tags

    # タグを追加
    tags_to_add.each do |tag_name|
      tag = Tag.find_or_create_by(name: tag_name)
      taggings.create(tag: tag)
    end

    # タグを削除
    if tags_to_remove.any?
      tags_to_remove_ids = Tag.where(name: tags_to_remove).pluck(:id)
      taggings.where(tag_id: tags_to_remove_ids).destroy_all
    end

    # キャッシュをリセット
    @tag_list_cache = nil
    @tags_changed = false
  end

  # タグリストを解析
  def parse_tag_list(tag_list)
    return [] if tag_list.blank?

    # カンマまたは空白で区切られたタグを分割
    tag_list.split(/,\s*|\s+/).map(&:strip).reject(&:blank?).uniq
  end

  # タグを追加
  def add_tag(tag_name)
    return if tag_name.blank?

    # タグが既に存在するかチェック
    return if tags.exists?(name: tag_name)

    # タグを追加
    tag = Tag.find_or_create_by(name: tag_name)
    taggings.create(tag: tag)

    # キャッシュをリセット
    @tag_list_cache = nil
  end

  # タグを削除
  def remove_tag(tag_name)
    return if tag_name.blank?

    # タグを検索
    tag = Tag.find_by(name: tag_name)
    return unless tag

    # タグを削除
    taggings.where(tag_id: tag.id).destroy_all

    # キャッシュをリセット
    @tag_list_cache = nil
  end

  # タグをすべて削除
  def clear_tags
    taggings.destroy_all
    @tag_list_cache = nil
  end

  # タグを持っているかどうかをチェック
  def has_tag?(tag_name)
    tags.exists?(name: tag_name)
  end

  # すべてのタグを持っているかどうかをチェック
  def has_all_tags?(tag_names)
    return true if tag_names.blank?

    # タグ名を配列に変換
    tag_names = [tag_names] unless tag_names.is_a?(Array)

    # 現在のタグを取得
    current_tags = tags.pluck(:name)

    # すべてのタグが含まれているかチェック
    tag_names.all? { |tag_name| current_tags.include?(tag_name) }
  end

  # いずれかのタグを持っているかどうかをチェック
  def has_any_tags?(tag_names)
    return false if tag_names.blank?

    # タグ名を配列に変換
    tag_names = [tag_names] unless tag_names.is_a?(Array)

    # 現在のタグを取得
    current_tags = tags.pluck(:name)

    # いずれかのタグが含まれているかチェック
    tag_names.any? { |tag_name| current_tags.include?(tag_name) }
  end

  # 関連するタグを取得
  def related_tags(limit = 10)
    # 同じタグを持つレコードのIDを取得
    related_ids = self.class.tagged_with_any(tags.pluck(:name))
                           .where.not(id: id)
                           .pluck(:id)

    return [] if related_ids.empty?

    # 関連するレコードのタグを取得
    Tag.joins(:taggings)
       .where(taggings: { taggable_type: self.class.name, taggable_id: related_ids })
       .where.not(id: tags.pluck(:id))
       .group('tags.id')
       .order('COUNT(taggings.id) DESC')
       .limit(limit)
  end
end
