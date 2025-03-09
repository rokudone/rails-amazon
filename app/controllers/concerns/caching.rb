module Caching
  extend ActiveSupport::Concern

  included do
    # キャッシュ関連の設定を定義するクラス変数
    class_attribute :caching_options, default: {}
  end

  class_methods do
    # キャッシュ設定を構成
    def configure_caching(options = {})
      self.caching_options = {
        enabled: true,
        expires_in: 1.hour,
        race_condition_ttl: 10.seconds,
        cache_path: nil,
        skip_digest: false,
        cache_suffix: nil,
        cache_if: nil,
        cache_unless: nil,
        cache_actions: nil,
        skip_actions: nil
      }.merge(options)
    end

    # キャッシュするアクションを設定
    def cache_actions(*actions, **options)
      self.caching_options[:cache_actions] = actions
      self.caching_options.merge!(options)
    end

    # キャッシュしないアクションを設定
    def skip_caching(*actions)
      self.caching_options[:skip_actions] = actions
    end
  end

  # キャッシュキーを生成
  def cache_key(suffix = nil)
    # コントローラとアクション名を取得
    controller = controller_name
    action = action_name

    # パラメータを取得
    param_digest = Digest::MD5.hexdigest(filtered_params.to_s)

    # キャッシュパスが設定されている場合
    if caching_options[:cache_path].present?
      # キャッシュパスがProcの場合
      if caching_options[:cache_path].is_a?(Proc)
        path = caching_options[:cache_path].call(self)
      # キャッシュパスがシンボルまたは文字列の場合
      elsif caching_options[:cache_path].is_a?(Symbol) || caching_options[:cache_path].is_a?(String)
        path = send(caching_options[:cache_path])
      else
        path = "#{controller}/#{action}"
      end
    else
      path = "#{controller}/#{action}"
    end

    # サフィックスを追加
    suffix ||= caching_options[:cache_suffix]

    # サフィックスがProcの場合
    if suffix.is_a?(Proc)
      suffix = suffix.call(self)
    # サフィックスがシンボルまたは文字列の場合
    elsif suffix.is_a?(Symbol)
      suffix = send(suffix)
    end

    # キャッシュキーを構築
    key = ["views", path, param_digest]
    key << suffix if suffix.present?

    # ダイジェストを追加
    unless caching_options[:skip_digest]
      key << Rails.application.config.assets.digest
    end

    # ユーザー固有のキャッシュの場合
    if respond_to?(:current_user) && current_user
      key << "user-#{current_user.id}"
    end

    # ロケール固有のキャッシュの場合
    if defined?(I18n) && I18n.locale
      key << "locale-#{I18n.locale}"
    end

    key.join('/')
  end

  # フィルタリングされたパラメータを取得
  def filtered_params
    # キャッシュに影響するパラメータのみを抽出
    params.to_unsafe_h.except(
      'controller', 'action', 'format', 'utf8', 'authenticity_token',
      '_method', 'commit', 'page', 'per_page'
    )
  end

  # キャッシュすべきかどうかをチェック
  def should_cache?
    # キャッシュが無効な場合
    return false unless caching_options[:enabled]

    # 特定のアクションのみキャッシュする場合
    if caching_options[:cache_actions].present?
      return false unless caching_options[:cache_actions].include?(action_name.to_sym)
    end

    # 特定のアクションをキャッシュしない場合
    if caching_options[:skip_actions].present?
      return false if caching_options[:skip_actions].include?(action_name.to_sym)
    end

    # 条件付きキャッシュ
    if caching_options[:cache_if].present?
      # Procの場合
      if caching_options[:cache_if].is_a?(Proc)
        return false unless caching_options[:cache_if].call(self)
      # シンボルまたは文字列の場合
      elsif caching_options[:cache_if].is_a?(Symbol) || caching_options[:cache_if].is_a?(String)
        return false unless send(caching_options[:cache_if])
      end
    end

    # 条件付きキャッシュ（否定）
    if caching_options[:cache_unless].present?
      # Procの場合
      if caching_options[:cache_unless].is_a?(Proc)
        return false if caching_options[:cache_unless].call(self)
      # シンボルまたは文字列の場合
      elsif caching_options[:cache_unless].is_a?(Symbol) || caching_options[:cache_unless].is_a?(String)
        return false if send(caching_options[:cache_unless])
      end
    end

    # GETリクエストのみキャッシュ
    return false unless request.get?

    # APIリクエストはキャッシュしない
    return false if request.format.json? || request.format.xml?

    true
  end

  # キャッシュからデータを取得または保存
  def cache_fetch(key = nil, options = {})
    # キャッシュすべきかどうかをチェック
    return yield unless should_cache?

    # キャッシュキーを生成
    cache_key = key || self.cache_key

    # オプションをマージ
    options = caching_options.slice(:expires_in, :race_condition_ttl).merge(options)

    # キャッシュから取得または保存
    Rails.cache.fetch(cache_key, options) { yield }
  end

  # キャッシュを無効化
  def invalidate_cache(key = nil, suffix = nil)
    # キャッシュキーを生成
    cache_key = key || self.cache_key(suffix)

    # キャッシュを削除
    Rails.cache.delete(cache_key)
  end

  # キャッシュヘッダーを設定
  def set_cache_headers(options = {})
    # オプションをマージ
    options = {
      public: false,
      max_age: 60,
      must_revalidate: true
    }.merge(options)

    # キャッシュヘッダーを設定
    if options[:public]
      # パブリックキャッシュ
      response.headers['Cache-Control'] = "public, max-age=#{options[:max_age]}"
    elsif options[:private]
      # プライベートキャッシュ
      response.headers['Cache-Control'] = "private, max-age=#{options[:max_age]}"
    elsif options[:no_cache]
      # キャッシュなし
      response.headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
      response.headers['Pragma'] = 'no-cache'
      response.headers['Expires'] = '0'
    else
      # デフォルト
      cache_control = "max-age=#{options[:max_age]}"
      cache_control << ', must-revalidate' if options[:must_revalidate]
      cache_control << ', no-transform' if options[:no_transform]

      response.headers['Cache-Control'] = cache_control
    end

    # ETagを設定
    if options[:etag]
      response.headers['ETag'] = options[:etag]
    end

    # Last-Modifiedを設定
    if options[:last_modified]
      response.headers['Last-Modified'] = options[:last_modified].httpdate
    end
  end

  # キャッシュを無効化するヘッダーを設定
  def set_no_cache_headers
    response.headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'
  end

  # 条件付きGETリクエストをチェック
  def check_conditional_get(etag: nil, last_modified: nil)
    # ETagを設定
    if etag
      fresh_when(etag: etag, last_modified: last_modified)
      return false unless performed?
    # Last-Modifiedを設定
    elsif last_modified
      fresh_when(last_modified: last_modified)
      return false unless performed?
    end

    true
  end

  # キャッシュされたアクション
  def cached_action(options = {})
    # キャッシュすべきかどうかをチェック
    return yield unless should_cache?

    # オプションをマージ
    options = caching_options.slice(:expires_in, :race_condition_ttl).merge(options)

    # キャッシュキーを生成
    cache_key = options[:key] || self.cache_key(options[:suffix])

    # キャッシュから取得または保存
    result = Rails.cache.fetch(cache_key, options) { yield }

    # 結果を返す
    result
  end
end
