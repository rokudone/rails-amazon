module CacheManager
  class << self
    # キャッシュから値を取得
    def get(key, options = {})
      normalized_key = normalize_key(key)

      # キャッシュから値を取得
      value = Rails.cache.read(normalized_key)

      # 値が見つからない場合はブロックを実行
      if value.nil? && block_given?
        value = yield

        # 値をキャッシュに保存
        set(key, value, options)
      end

      value
    end

    # キャッシュに値を保存
    def set(key, value, options = {})
      normalized_key = normalize_key(key)

      # 値をキャッシュに保存
      Rails.cache.write(normalized_key, value, options)

      value
    end

    # キャッシュから値を削除
    def delete(key)
      normalized_key = normalize_key(key)

      # 値をキャッシュから削除
      Rails.cache.delete(normalized_key)
    end

    # キャッシュが存在するかチェック
    def exists?(key)
      normalized_key = normalize_key(key)

      # キャッシュが存在するかチェック
      Rails.cache.exist?(normalized_key)
    end

    # キャッシュをクリア
    def clear
      Rails.cache.clear
    end

    # キャッシュをフェッチ（存在しない場合はブロックを実行して保存）
    def fetch(key, options = {})
      normalized_key = normalize_key(key)

      # キャッシュをフェッチ
      if block_given?
        Rails.cache.fetch(normalized_key, options) { yield }
      else
        Rails.cache.fetch(normalized_key, options)
      end
    end

    # 複数のキャッシュを一度に取得
    def get_multi(options = {}, *keys)
      normalized_keys = keys.map { |key| normalize_key(key) }

      # 複数のキャッシュを取得
      Rails.cache.read_multi(*normalized_keys)
    end

    # 複数のキャッシュを一度に保存
    def set_multi(hash, options = {})
      normalized_hash = {}

      # キーを正規化
      hash.each do |key, value|
        normalized_hash[normalize_key(key)] = value
      end

      # 複数のキャッシュを保存
      Rails.cache.write_multi(normalized_hash, options)
    end

    # 複数のキャッシュを一度に削除
    def delete_multi(*keys)
      normalized_keys = keys.map { |key| normalize_key(key) }

      # 複数のキャッシュを削除
      normalized_keys.each do |key|
        Rails.cache.delete(key)
      end
    end

    # パターンに一致するキャッシュを削除
    def delete_matched(pattern)
      # 実際のアプリケーションでは、キャッシュストアに応じた実装が必要
      # ここではシミュレーションのみ
      Rails.logger.info("Cache keys matching pattern '#{pattern}' would be deleted")
    end

    # キャッシュの有効期限を更新
    def touch(key, expires_in = nil)
      normalized_key = normalize_key(key)

      # キャッシュから値を取得
      value = Rails.cache.read(normalized_key)

      # 値が存在する場合は有効期限を更新
      if value
        options = {}
        options[:expires_in] = expires_in if expires_in

        Rails.cache.write(normalized_key, value, options)
        true
      else
        false
      end
    end

    # キャッシュの有効期限を取得
    def ttl(key)
      # 実際のアプリケーションでは、キャッシュストアに応じた実装が必要
      # ここではシミュレーションのみ
      Rails.logger.info("TTL for key '#{key}' would be returned")
      nil
    end

    # キャッシュをインクリメント
    def increment(key, amount = 1)
      normalized_key = normalize_key(key)

      # キャッシュをインクリメント
      Rails.cache.increment(normalized_key, amount)
    end

    # キャッシュをデクリメント
    def decrement(key, amount = 1)
      normalized_key = normalize_key(key)

      # キャッシュをデクリメント
      Rails.cache.decrement(normalized_key, amount)
    end

    # キャッシュ戦略：単一キー
    def cache_key_for(model, identifier = nil)
      if model.is_a?(ActiveRecord::Base)
        # モデルインスタンスの場合
        "#{model.class.name.underscore}/#{model.id}-#{model.updated_at.to_i}"
      elsif model.is_a?(Class) && model < ActiveRecord::Base
        # モデルクラスの場合
        if identifier
          "#{model.name.underscore}/#{identifier}"
        else
          "#{model.name.underscore}/all-#{model.maximum(:updated_at).to_i}"
        end
      else
        # その他の場合
        "#{model.to_s.underscore}/#{identifier}"
      end
    end

    # キャッシュ戦略：コレクション
    def cache_key_for_collection(collection, identifier = nil)
      # コレクションの最終更新日時を取得
      timestamp = collection.maximum(:updated_at).to_i

      # コレクションの数を取得
      count = collection.count

      # キャッシュキーを生成
      if identifier
        "#{collection.model.name.underscore}/#{identifier}-#{count}-#{timestamp}"
      else
        "#{collection.model.name.underscore}/all-#{count}-#{timestamp}"
      end
    end

    # キャッシュ戦略：クエリパラメータ
    def cache_key_for_params(controller_name, action_name, params)
      # パラメータをソートしてシリアライズ
      serialized_params = params.sort.to_h.to_json

      # パラメータのハッシュ値を計算
      params_hash = Digest::MD5.hexdigest(serialized_params)

      # キャッシュキーを生成
      "#{controller_name}/#{action_name}/#{params_hash}"
    end

    # キャッシュ戦略：ユーザー固有
    def cache_key_for_user(user_id, identifier)
      "users/#{user_id}/#{identifier}"
    end

    # キャッシュ戦略：バージョン付き
    def cache_key_with_version(key, version)
      "#{normalize_key(key)}/v#{version}"
    end

    # キャッシュ戦略：言語固有
    def cache_key_for_locale(key, locale = I18n.locale)
      "#{normalize_key(key)}/#{locale}"
    end

    # キャッシュ戦略：デバイス固有
    def cache_key_for_device(key, device_type)
      "#{normalize_key(key)}/#{device_type}"
    end

    private

    # キャッシュキーを正規化
    def normalize_key(key)
      case key
      when String, Symbol
        key.to_s
      when Array
        key.map(&:to_s).join('/')
      when Hash
        key.sort.map { |k, v| "#{k}=#{v}" }.join('&')
      when ActiveRecord::Base
        "#{key.class.name.underscore}/#{key.id}-#{key.updated_at.to_i}"
      else
        key.to_s
      end
    end
  end

  # キャッシュストア固有の実装
  module Stores
    # Redisキャッシュストア
    module Redis
      class << self
        # Redisクライアントを取得
        def client
          Rails.cache.redis
        end

        # キーのパターンに一致するキャッシュを削除
        def delete_matched(pattern)
          # Redisのキーを検索して削除
          client.keys(pattern).each do |key|
            client.del(key)
          end
        end

        # キャッシュの有効期限を取得
        def ttl(key)
          client.ttl(key)
        end

        # Redisのパイプラインを使用して複数の操作を一度に実行
        def pipelined(&block)
          client.pipelined(&block)
        end

        # Redisのトランザクションを使用して複数の操作をアトミックに実行
        def multi(&block)
          client.multi(&block)
        end

        # Redisのpub/subを使用してメッセージを発行
        def publish(channel, message)
          client.publish(channel, message)
        end

        # Redisのpub/subを使用してメッセージを購読
        def subscribe(channel, &block)
          client.subscribe(channel, &block)
        end
      end
    end

    # Memcachedキャッシュストア
    module Memcached
      class << self
        # Memcachedクライアントを取得
        def client
          Rails.cache.instance_variable_get(:@data)
        end

        # Memcachedの統計情報を取得
        def stats
          client.stats
        end

        # Memcachedのバージョンを取得
        def version
          client.version
        end
      end
    end
  end
end
