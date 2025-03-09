class SystemConfig < ApplicationRecord
  # 関連付け
  belongs_to :updated_by, class_name: 'User', optional: true

  # バリデーション
  validates :key, presence: true, uniqueness: true
  validates :value_type, presence: true
  validates :group, presence: true

  # コールバック
  before_save :set_last_updated_at
  before_save :validate_value_format
  after_save :clear_cache

  # スコープ
  scope :by_group, ->(group) { where(group: group) }
  scope :editable, -> { where(is_editable: true) }
  scope :visible, -> { where(is_visible: true) }
  scope :requires_restart, -> { where(requires_restart: true) }
  scope :encrypted, -> { where(is_encrypted: true) }
  scope :ordered, -> { order(position: :asc) }
  scope :general, -> { where(group: 'general') }
  scope :payment, -> { where(group: 'payment') }
  scope :shipping, -> { where(group: 'shipping') }
  scope :email, -> { where(group: 'email') }
  scope :social, -> { where(group: 'social') }
  scope :api, -> { where(group: 'api') }
  scope :security, -> { where(group: 'security') }

  # クラスメソッド
  def self.get(key, default = nil)
    # キャッシュから取得（実装は別途必要）
    cached_value = Rails.cache.read("system_config:#{key}")
    return cached_value unless cached_value.nil?

    config = find_by(key: key)
    return default if config.nil?

    value = config.typed_value
    Rails.cache.write("system_config:#{key}", value)
    value
  end

  def self.set(key, value, updater = nil)
    config = find_or_initialize_by(key: key)

    if config.new_record?
      config.value_type = detect_value_type(value)
      config.group = 'general'
      config.is_editable = true
      config.is_visible = true
    end

    config.value = value.to_s
    config.updated_by = updater
    config.save
  end

  def self.get_all_by_group(group)
    by_group(group).ordered.each_with_object({}) do |config, hash|
      hash[config.key] = config.typed_value
    end
  end

  def self.detect_value_type(value)
    case value
    when TrueClass, FalseClass
      'boolean'
    when Integer
      'integer'
    when Float
      'float'
    when Hash, Array
      'json'
    else
      'string'
    end
  end

  def self.clear_all_cache
    # すべてのキャッシュをクリア
    where(nil).find_each do |config|
      Rails.cache.delete("system_config:#{config.key}")
    end
  end

  # カスタムメソッド
  def typed_value
    return nil if value.nil?

    case value_type
    when 'string'
      value
    when 'integer'
      value.to_i
    when 'float'
      value.to_f
    when 'boolean'
      value.downcase == 'true'
    when 'json'
      begin
        JSON.parse(value)
      rescue JSON::ParserError
        nil
      end
    else
      value
    end
  end

  def update_value!(new_value, updater = nil)
    self.value = new_value.to_s
    self.updated_by = updater
    save
  end

  def options_array
    return [] if options.blank?

    begin
      JSON.parse(options)
    rescue JSON::ParserError
      []
    end
  end

  def validation_rules_hash
    return {} if validation_rules.blank?

    begin
      JSON.parse(validation_rules)
    rescue JSON::ParserError
      {}
    end
  end

  def group_name
    case group
    when 'general'
      '一般'
    when 'payment'
      '支払い'
    when 'shipping'
      '配送'
    when 'email'
      'メール'
    when 'social'
      'ソーシャル'
    when 'api'
      'API'
    when 'security'
      'セキュリティ'
    else
      group.humanize
    end
  end

  def value_type_name
    case value_type
    when 'string'
      '文字列'
    when 'integer'
      '整数'
    when 'float'
      '小数'
    when 'boolean'
      '真偽値'
    when 'json'
      'JSON'
    else
      value_type.humanize
    end
  end

  def formatted_value
    val = typed_value

    case value_type
    when 'boolean'
      val ? 'はい' : 'いいえ'
    when 'json'
      JSON.pretty_generate(val)
    else
      val.to_s
    end
  end

  def editable?
    is_editable?
  end

  def visible?
    is_visible?
  end

  def encrypted?
    is_encrypted?
  end

  def requires_restart?
    requires_restart?
  end

  private

  def set_last_updated_at
    self.last_updated_at = Time.current
  end

  def validate_value_format
    return if value.blank?

    case value_type
    when 'integer'
      errors.add(:value, "は整数である必要があります") unless value.to_i.to_s == value
    when 'float'
      errors.add(:value, "は小数である必要があります") unless value.to_f.to_s == value
    when 'boolean'
      errors.add(:value, "は真偽値である必要があります") unless ['true', 'false'].include?(value.downcase)
    when 'json'
      begin
        JSON.parse(value)
      rescue JSON::ParserError
        errors.add(:value, "は有効なJSONである必要があります")
      end
    end

    # バリデーションルールのチェック
    validate_with_rules if validation_rules.present?

    throw(:abort) if errors.any?
  end

  def validate_with_rules
    rules = validation_rules_hash

    if rules['required'] && value.blank?
      errors.add(:value, "は必須です")
    end

    if rules['min'] && typed_value < rules['min']
      errors.add(:value, "は#{rules['min']}以上である必要があります")
    end

    if rules['max'] && typed_value > rules['max']
      errors.add(:value, "は#{rules['max']}以下である必要があります")
    end

    if rules['pattern'] && !value.match?(Regexp.new(rules['pattern']))
      errors.add(:value, "は正規表現 #{rules['pattern']} にマッチする必要があります")
    end

    if rules['options'] && !rules['options'].include?(value)
      errors.add(:value, "は #{rules['options'].join(', ')} のいずれかである必要があります")
    end
  end

  def clear_cache
    Rails.cache.delete("system_config:#{key}")
  end
end
