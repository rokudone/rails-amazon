module Cacheable
  extend ActiveSupport::Concern

  included do
    # キャッシュ設定を定義するクラス変数
    class_attribute :cache_options, default: {}

    # コールバックを設定
    after_commit :invalidate_cache, on: [:create, :update, :destroy]
  end

  class_methods do
    # キャッシュ設定を構成
    def configure_cache(options = {})
      self.cache_options = {
        expires_in: 1.hour,
        race_condition_ttl: 10.seconds
      }.merge(options)
    end

    # キャッシュキーを生成
    def cache_key_for(id_or_object, scope = nil)
      case id_or_object
      when self
        # モデルインスタンスの場合
        object = id_or_object
        scope_suffix = scope ? "/#{scope}" : ""
        "#{model_name.cache_key}/#{object.id}-#{object.updated_at.to_i}#{scope_suffix}"
      when Integer, String
        # IDの場合
        id = id_or_object.to_s
        scope_suffix = scope ? "/#{scope}" : ""
        "#{model_name.cache_key}/#{id}#{scope_suffix}"
      else
        raise ArgumentError, "Invalid argument: #{id_or_object.inspect}"
      end
    end

    # コレクションのキャッシュキーを生成
    def collection_cache_key(scope = nil, query_params = nil)
      # 基本のキー
      key = "#{model_name.plural}/collection"

      # スコープが指定されている場合
      key += "/#{scope}" if scope.present?

      # クエリパラメータが指定されている場合
      if query_params.present?
        # パラメータをソートしてシリアライズ
        params_str = query_params.sort.map { |k, v| "#{k}=#{v}" }.join('&')
        key += "/#{Digest::MD5.hexdigest(params_str)}"
      end

      # 最終更新日時とカウントを追加
      timestamp = maximum(:updated_at).try(:to_i) || Time.current.to_i
      count = count(:all)

      "#{key}/#{timestamp}-#{count}"
    end

    # キャッシュから単一レコードを取得または保存
    def fetch_cached(id, scope = nil, options = {})
      # キャッシュキーを生成
      cache_key = cache_key_for(id, scope)

      # キャッシュオプションをマージ
      cache_options_with_overrides = cache_options.merge(options)

      # キャッシュから取得または保存
      Rails.cache.fetch(cache_key, cache_options_with_overrides) do
        find_by(id: id)
      end
    end

    # キャッシュからコレクションを取得または保存
    def fetch_cached_collection(scope = nil, query_params = nil, options = {})
      # キャッシュキーを生成
      cache_key = collection_cache_key(scope, query_params)

      # キャッシュオプションをマージ
      cache_options_with_overrides = cache_options.merge(options)

      # キャッシュから取得または保存
      Rails.cache.fetch(cache_key, cache_options_with_overrides) do
        # スコープが指定されている場合
        result = scope.present? ? send(scope) : all

        # クエリパラメータが指定されている場合
        if query_params.present? && respond_to?(:filter_by)
          result = result.filter_by(query_params)
        end

        # 結果を取得
        result.to_a
      end
    end

    # キャッシュを無効化
    def invalidate_cache(id = nil, scope = nil)
      if id.present?
        # 特定のレコードのキャッシュを無効化
        cache_key = cache_key_for(id, scope)
        Rails.cache.delete(cache_key)
      else
        # コレクションのキャッシュを無効化
        cache_key = collection_cache_key(scope)
        Rails.cache.delete(cache_key)

        # パターンに一致するキャッシュを無効化
        if defined?(CacheManager) && CacheManager.respond_to?(:delete_matched)
          CacheManager.delete_matched("#{model_name.cache_key}/*")
        end
      end
    end

    # キャッシュを再構築
    def rebuild_cache(id = nil, scope = nil)
      if id.present?
        # 特定のレコードのキャッシュを再構築
        record = find_by(id: id)
        if record
          cache_key = cache_key_for(id, scope)
          Rails.cache.write(cache_key, record, cache_options)
        end
      else
        # コレクションのキャッシュを再構築
        collection = scope.present? ? send(scope) : all
        cache_key = collection_cache_key(scope)
        Rails.cache.write(cache_key, collection.to_a, cache_options)
      end
    end
  end

  # インスタンスメソッド

  # キャッシュキーを生成
  def cache_key(scope = nil)
    self.class.cache_key_for(self, scope)
  end

  # キャッシュから取得または保存
  def fetch_cached(scope = nil, options = {})
    # キャッシュキーを生成
    cache_key = self.cache_key(scope)

    # キャッシュオプションをマージ
    cache_options_with_overrides = self.class.cache_options.merge(options)

    # キャッシュから取得または保存
    Rails.cache.fetch(cache_key, cache_options_with_overrides) do
      self
    end
  end

  # 関連オブジェクトをキャッシュから取得または保存
  def fetch_cached_association(association_name, options = {})
    # キャッシュキーを生成
    cache_key = "#{self.cache_key}/#{association_name}"

    # キャッシュオプションをマージ
    cache_options_with_overrides = self.class.cache_options.merge(options)

    # キャッシュから取得または保存
    Rails.cache.fetch(cache_key, cache_options_with_overrides) do
      send(association_name)
    end
  end

  # キャッシュを無効化
  def invalidate_cache(scope = nil)
    # キャッシュキーを生成
    cache_key = self.cache_key(scope)

    # キャッシュを削除
    Rails.cache.delete(cache_key)

    # 関連するコレクションのキャッシュも無効化
    self.class.invalidate_cache(nil, scope)
  end

  # コールバック：キャッシュを無効化
  def invalidate_cache
    # インスタンスのキャッシュを無効化
    cache_key = self.cache_key
    Rails.cache.delete(cache_key)

    # 関連するコレクションのキャッシュも無効化
    self.class.invalidate_cache

    # パターンに一致するキャッシュを無効化
    if defined?(CacheManager) && CacheManager.respond_to?(:delete_matched)
      CacheManager.delete_matched("#{self.class.model_name.cache_key}/#{self.id}-*")
    end
  end
end
