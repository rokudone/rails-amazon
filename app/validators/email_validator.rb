class EmailValidator < ActiveModel::EachValidator
  # メールアドレスの正規表現パターン
  # RFC 5322に準拠した基本的なパターン
  EMAIL_PATTERN = /\A[a-zA-Z0-9.!\#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\z/

  # より厳格なメールアドレスの正規表現パターン
  STRICT_EMAIL_PATTERN = /\A[a-zA-Z0-9.!\#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.(?:[a-zA-Z]{2,})\z/

  # 一般的なフリーメールドメインのリスト
  FREE_EMAIL_DOMAINS = %w[
    gmail.com yahoo.com hotmail.com outlook.com aol.com icloud.com
    mail.com zoho.com protonmail.com gmx.com yandex.com
  ].freeze

  # 使い捨てメールドメインのリスト（一部）
  DISPOSABLE_EMAIL_DOMAINS = %w[
    mailinator.com guerrillamail.com 10minutemail.com yopmail.com
    tempmail.com temp-mail.org throwawaymail.com trashmail.com
  ].freeze

  # バリデーションを実行
  def validate_each(record, attribute, value)
    # 値が空の場合は他のバリデーターに任せる
    return if value.blank?

    # オプションを取得
    options = {
      strict: false,
      mx: false,
      ban_disposable: false,
      ban_free: false,
      domain_specific: nil
    }.merge(self.options)

    # メールアドレスの形式をチェック
    pattern = options[:strict] ? STRICT_EMAIL_PATTERN : EMAIL_PATTERN
    unless value.match?(pattern)
      record.errors.add(attribute, options[:message] || :invalid_email_format)
      return
    end

    # ドメイン部分を取得
    domain = value.to_s.split('@').last.downcase

    # 使い捨てメールをチェック
    if options[:ban_disposable] && DISPOSABLE_EMAIL_DOMAINS.include?(domain)
      record.errors.add(attribute, options[:disposable_message] || :disposable_email_not_allowed)
      return
    end

    # フリーメールをチェック
    if options[:ban_free] && FREE_EMAIL_DOMAINS.include?(domain)
      record.errors.add(attribute, options[:free_message] || :free_email_not_allowed)
      return
    end

    # 特定のドメインをチェック
    if options[:domain_specific].present?
      allowed_domains = Array(options[:domain_specific])
      unless allowed_domains.any? { |d| domain.end_with?(d) }
        record.errors.add(attribute, options[:domain_message] || :domain_not_allowed)
        return
      end
    end

    # MXレコードをチェック
    if options[:mx]
      require 'resolv'
      begin
        mx_records = Resolv::DNS.open do |dns|
          dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
        end
        if mx_records.empty?
          record.errors.add(attribute, options[:mx_message] || :mx_record_not_found)
          return
        end
      rescue Resolv::ResolvError
        record.errors.add(attribute, options[:mx_message] || :mx_record_not_found)
        return
      end
    end
  end

  # ヘルパーメソッド：メールアドレスが有効かどうかをチェック
  def self.valid?(email, options = {})
    validator = new(options.merge(attributes: [:email]))
    record = Struct.new(:email, :errors).new(email, ActiveModel::Errors.new(self))
    validator.validate_each(record, :email, email)
    record.errors.empty?
  end

  # ヘルパーメソッド：メールアドレスのドメインを取得
  def self.domain(email)
    return nil if email.blank?
    email.to_s.split('@').last.downcase
  end

  # ヘルパーメソッド：メールアドレスのユーザー名を取得
  def self.username(email)
    return nil if email.blank?
    email.to_s.split('@').first
  end

  # ヘルパーメソッド：メールアドレスを正規化
  def self.normalize(email)
    return nil if email.blank?
    email.to_s.downcase.strip
  end

  # ヘルパーメソッド：メールアドレスをマスク
  def self.mask(email)
    return nil if email.blank?

    username, domain = email.to_s.split('@')
    return email unless domain

    # ユーザー名をマスク
    masked_username = if username.length > 2
                        "#{username[0]}#{'*' * (username.length - 2)}#{username[-1]}"
                      else
                        "#{'*' * username.length}"
                      end

    "#{masked_username}@#{domain}"
  end
end
