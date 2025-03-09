class UrlValidator < ActiveModel::EachValidator
  # URLの正規表現パターン
  URL_PATTERN = /\A(https?:\/\/)?([a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}|localhost)(:[0-9]{1,5})?(\/.*)?(\?.*)?(#.*)?\z/i

  # 厳格なURLの正規表現パターン
  STRICT_URL_PATTERN = /\A(https?:\/\/)([a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,})(:[0-9]{1,5})?(\/.*)?(\?.*)?(#.*)?\z/i

  # 許可されるスキーム
  ALLOWED_SCHEMES = %w[http https].freeze

  # バリデーションを実行
  def validate_each(record, attribute, value)
    # 値が空の場合は他のバリデーターに任せる
    return if value.blank? && options[:allow_blank]

    # オプションを取得
    options = {
      strict: false,
      schemes: ALLOWED_SCHEMES,
      public_suffix: false,
      check_host: false,
      allow_blank: false,
      allow_localhost: false,
      allow_ip: false
    }.merge(self.options)

    # URLをパース
    begin
      uri = URI.parse(value)
    rescue URI::InvalidURIError
      record.errors.add(attribute, options[:message] || :invalid_url)
      return
    end

    # スキームをチェック
    if options[:strict] && !uri.scheme
      record.errors.add(attribute, options[:scheme_message] || :url_without_scheme)
      return
    end

    # スキームが許可されているかチェック
    if uri.scheme && !options[:schemes].include?(uri.scheme)
      record.errors.add(attribute, options[:scheme_message] || :url_invalid_scheme, schemes: options[:schemes].join(', '))
      return
    end

    # ホストをチェック
    if uri.host.blank?
      record.errors.add(attribute, options[:host_message] || :url_without_host)
      return
    end

    # localhostをチェック
    if uri.host == 'localhost' && !options[:allow_localhost]
      record.errors.add(attribute, options[:localhost_message] || :url_localhost_not_allowed)
      return
    end

    # IPアドレスをチェック
    if uri.host =~ /\A\d+\.\d+\.\d+\.\d+\z/ && !options[:allow_ip]
      record.errors.add(attribute, options[:ip_message] || :url_ip_not_allowed)
      return
    end

    # 正規表現パターンをチェック
    pattern = options[:strict] ? STRICT_URL_PATTERN : URL_PATTERN
    unless value.match?(pattern)
      record.errors.add(attribute, options[:message] || :invalid_url)
      return
    end

    # Public Suffixをチェック
    if options[:public_suffix] && defined?(PublicSuffix)
      begin
        PublicSuffix.parse(uri.host)
      rescue PublicSuffix::DomainInvalid, PublicSuffix::DomainNotAllowed
        record.errors.add(attribute, options[:public_suffix_message] || :url_invalid_public_suffix)
        return
      end
    end

    # ホストが存在するかチェック
    if options[:check_host]
      begin
        Resolv.getaddress(uri.host)
      rescue Resolv::ResolvError
        record.errors.add(attribute, options[:check_host_message] || :url_host_not_found)
        return
      end
    end
  end

  # ヘルパーメソッド：URLが有効かどうかをチェック
  def self.valid?(url, options = {})
    validator = new(options.merge(attributes: [:url]))
    record = Struct.new(:url, :errors).new(url, ActiveModel::Errors.new(self))
    validator.validate_each(record, :url, url)
    record.errors.empty?
  end

  # ヘルパーメソッド：URLを正規化
  def self.normalize(url)
    return nil if url.blank?

    # スキームを追加
    normalized = url.strip
    normalized = "http://#{normalized}" unless normalized =~ /\A[a-z][a-z0-9+\-.]*:/i

    # URIをパース
    begin
      uri = URI.parse(normalized)
      uri.to_s
    rescue URI::InvalidURIError
      url
    end
  end

  # ヘルパーメソッド：URLからドメインを取得
  def self.domain(url)
    return nil if url.blank?

    # URIをパース
    begin
      uri = URI.parse(normalize(url))
      uri.host
    rescue URI::InvalidURIError
      nil
    end
  end

  # ヘルパーメソッド：URLからスキームを取得
  def self.scheme(url)
    return nil if url.blank?

    # URIをパース
    begin
      uri = URI.parse(url)
      uri.scheme
    rescue URI::InvalidURIError
      nil
    end
  end

  # ヘルパーメソッド：URLからパスを取得
  def self.path(url)
    return nil if url.blank?

    # URIをパース
    begin
      uri = URI.parse(url)
      uri.path.presence || '/'
    rescue URI::InvalidURIError
      nil
    end
  end

  # ヘルパーメソッド：URLからクエリパラメータを取得
  def self.query_params(url)
    return {} if url.blank?

    # URIをパース
    begin
      uri = URI.parse(url)
      return {} unless uri.query

      # クエリパラメータをパース
      params = {}
      URI.decode_www_form(uri.query).each do |key, value|
        params[key] = value
      end
      params
    rescue URI::InvalidURIError
      {}
    end
  end

  # ヘルパーメソッド：URLにクエリパラメータを追加
  def self.add_query_params(url, params)
    return url if url.blank? || params.blank?

    # URIをパース
    begin
      uri = URI.parse(url)

      # 既存のクエリパラメータを取得
      existing_params = query_params(url)

      # パラメータをマージ
      merged_params = existing_params.merge(params)

      # クエリ文字列を構築
      query_string = merged_params.map { |k, v| "#{URI.encode_www_form_component(k)}=#{URI.encode_www_form_component(v)}" }.join('&')

      # URIを更新
      uri.query = query_string.presence

      uri.to_s
    rescue URI::InvalidURIError
      url
    end
  end

  # ヘルパーメソッド：URLからクエリパラメータを削除
  def self.remove_query_params(url, *param_names)
    return url if url.blank? || param_names.empty?

    # URIをパース
    begin
      uri = URI.parse(url)
      return url unless uri.query

      # 既存のクエリパラメータを取得
      existing_params = query_params(url)

      # パラメータを削除
      param_names.each do |name|
        existing_params.delete(name.to_s)
      end

      # クエリ文字列を構築
      query_string = existing_params.map { |k, v| "#{URI.encode_www_form_component(k)}=#{URI.encode_www_form_component(v)}" }.join('&')

      # URIを更新
      uri.query = query_string.presence

      uri.to_s
    rescue URI::InvalidURIError
      url
    end
  end
end
