module Sluggable
  extend ActiveSupport::Concern

  included do
    # スラグ関連の設定を定義するクラス変数
    class_attribute :slug_options, default: {}

    # バリデーションを設定
    validates :slug, presence: true, uniqueness: { case_sensitive: false }, if: :should_validate_slug?

    # コールバックを設定
    before_validation :generate_slug, if: :should_generate_slug?

    # スコープを定義
    scope :find_by_slug, ->(slug) { where(slug: slug) }
  end

  class_methods do
    # スラグ設定を構成
    def sluggify(source_column, options = {})
      self.slug_options = {
        source: source_column,
        separator: '-',
        history: false,
        unique: true,
        max_length: 100,
        reserved: %w[new edit show index create update destroy],
        scope: nil
      }.merge(options)
    end

    # スラグで検索
    def find_by_slug!(slug)
      find_by_slug(slug).first!
    rescue ActiveRecord::RecordNotFound
      raise ActiveRecord::RecordNotFound, "Couldn't find #{name} with slug=#{slug}"
    end

    # スラグを生成
    def generate_unique_slug(text, record_id = nil)
      return nil if text.blank?

      # 基本のスラグを生成
      base_slug = text.to_s.parameterize(separator: slug_options[:separator])

      # 最大長を適用
      base_slug = base_slug[0...slug_options[:max_length]] if slug_options[:max_length]

      # 予約語をチェック
      if slug_options[:reserved].include?(base_slug)
        base_slug = "#{base_slug}#{slug_options[:separator]}1"
      end

      # 一意性が不要な場合はそのまま返す
      return base_slug unless slug_options[:unique]

      # スコープを構築
      scope = where(slug: base_slug)
      scope = scope.where.not(id: record_id) if record_id
      scope = scope.where(slug_options[:scope] => record.send(slug_options[:scope])) if slug_options[:scope]

      # スラグが一意であればそのまま返す
      return base_slug unless scope.exists?

      # 一意なスラグを生成
      counter = 1
      unique_slug = base_slug

      while scope.where(slug: unique_slug).exists?
        unique_slug = "#{base_slug}#{slug_options[:separator]}#{counter}"
        counter += 1
      end

      unique_slug
    end
  end

  # インスタンスメソッド

  # スラグを生成
  def generate_slug
    return if slug.present? && !slug_source_changed?

    # ソース列の値を取得
    source_value = send(slug_options[:source])

    # スラグを生成
    self.slug = self.class.generate_unique_slug(source_value, id)
  end

  # スラグを再生成
  def regenerate_slug
    # ソース列の値を取得
    source_value = send(slug_options[:source])

    # 古いスラグを保存
    old_slug = slug

    # 新しいスラグを生成
    new_slug = self.class.generate_unique_slug(source_value, id)

    # スラグを更新
    update(slug: new_slug)

    # スラグ履歴を保存
    save_slug_history(old_slug) if slug_options[:history] && old_slug != new_slug

    new_slug
  end

  # スラグ履歴を保存
  def save_slug_history(old_slug)
    return unless defined?(SlugHistory)

    SlugHistory.create(
      sluggable_type: self.class.name,
      sluggable_id: id,
      slug: old_slug
    )
  end

  # スラグソースが変更されたかどうかをチェック
  def slug_source_changed?
    source_column = slug_options[:source]
    return false unless respond_to?("#{source_column}_changed?")

    send("#{source_column}_changed?")
  end

  # スラグを検証すべきかどうかをチェック
  def should_validate_slug?
    slug_options.present?
  end

  # スラグを生成すべきかどうかをチェック
  def should_generate_slug?
    slug_options.present? && (slug.blank? || (slug_options[:force] && slug_source_changed?))
  end

  # to_paramをオーバーライド
  def to_param
    slug.present? ? slug : super
  end

  # スラグ履歴を取得
  def slug_history
    return [] unless defined?(SlugHistory) || !slug_options[:history]

    SlugHistory.where(
      sluggable_type: self.class.name,
      sluggable_id: id
    ).order(created_at: :desc).pluck(:slug)
  end

  # スラグが一意かどうかをチェック
  def slug_unique?
    return true unless slug_options[:unique]

    # スコープを構築
    scope = self.class.where(slug: slug)
    scope = scope.where.not(id: id) if persisted?
    scope = scope.where(slug_options[:scope] => send(slug_options[:scope])) if slug_options[:scope]

    !scope.exists?
  end

  # スラグが予約語かどうかをチェック
  def slug_reserved?
    slug_options[:reserved].include?(slug)
  end
end
