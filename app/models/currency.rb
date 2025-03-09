class Currency < ApplicationRecord
  # 関連付け
  belongs_to :updated_by, class_name: 'User', optional: true
  has_many :countries, dependent: :nullify

  # バリデーション
  validates :code, presence: true, uniqueness: true, length: { is: 3 }
  validates :name, presence: true
  validates :symbol, presence: true
  validates :decimal_places, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :exchange_rate_to_default, numericality: { greater_than: 0 }
  validate :only_one_default_currency

  # コールバック
  before_save :set_exchange_rate_updated_at, if: -> { exchange_rate_to_default_changed? }
  after_save :update_related_currencies, if: -> { saved_change_to_is_default? && is_default? }
  after_save :clear_cache

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :default, -> { where(is_default: true) }
  scope :ordered, -> { order(position: :asc) }
  scope :by_code, ->(code) { where(code: code.upcase) }

  # クラスメソッド
  def self.default_currency
    Rails.cache.fetch('default_currency') do
      default.first || first
    end
  end

  def self.get_exchange_rate(from_code, to_code)
    return 1.0 if from_code.upcase == to_code.upcase

    from_currency = by_code(from_code).first
    to_currency = by_code(to_code).first

    return nil if from_currency.nil? || to_currency.nil?

    # デフォルト通貨を経由してレートを計算
    from_rate = from_currency.exchange_rate_to_default
    to_rate = to_currency.exchange_rate_to_default

    (1.0 / from_rate) * to_rate
  end

  def self.convert(amount, from_code, to_code)
    rate = get_exchange_rate(from_code, to_code)
    return nil if rate.nil?

    (amount * rate).round(2)
  end

  def self.format_amount(amount, currency_code = nil)
    currency = currency_code.present? ? by_code(currency_code).first : default_currency
    return amount.to_s if currency.nil?

    # 金額のフォーマット
    formatted_amount = sprintf("%.#{currency.decimal_places}f", amount)

    # フォーマットパターンの適用
    format = currency.format || '%s%v'
    format.gsub('%s', currency.symbol).gsub('%v', formatted_amount)
  end

  def self.update_exchange_rates!(rates_data, updater = nil)
    default_currency = default_currency

    transaction do
      rates_data.each do |code, rate|
        currency = by_code(code).first
        next if currency.nil? || currency.is_default?

        currency.update(
          exchange_rate_to_default: rate,
          updated_by: updater
        )
      end
    end
  end

  def self.clear_all_cache
    Rails.cache.delete('default_currency')
    Rails.cache.delete_matched('currency:*')
  end

  # カスタムメソッド
  def activate!
    update(is_active: true)
  end

  def deactivate!
    update(is_active: false)
  end

  def set_as_default!
    update(is_default: true)
  end

  def update_exchange_rate!(rate, updater = nil)
    update(
      exchange_rate_to_default: rate,
      updated_by: updater
    )
  end

  def format_amount(amount)
    # 金額のフォーマット
    formatted_amount = sprintf("%.#{decimal_places}f", amount)

    # フォーマットパターンの適用
    format_pattern = format || '%s%v'
    format_pattern.gsub('%s', symbol).gsub('%v', formatted_amount)
  end

  def convert_to(amount, target_currency)
    return amount if code == target_currency.code

    # デフォルト通貨を経由してレートを計算
    from_rate = exchange_rate_to_default
    to_rate = target_currency.exchange_rate_to_default

    converted = (amount / from_rate) * to_rate
    converted.round(target_currency.decimal_places)
  end

  def convert_from(amount, source_currency)
    return amount if code == source_currency.code

    # デフォルト通貨を経由してレートを計算
    from_rate = source_currency.exchange_rate_to_default
    to_rate = exchange_rate_to_default

    converted = (amount / from_rate) * to_rate
    converted.round(decimal_places)
  end

  def exchange_rate_updated_recently?
    return false if exchange_rate_updated_at.nil?
    exchange_rate_updated_at > 24.hours.ago
  end

  def days_since_rate_update
    return nil if exchange_rate_updated_at.nil?
    (Date.current - exchange_rate_updated_at.to_date).to_i
  end

  private

  def set_exchange_rate_updated_at
    self.exchange_rate_updated_at = Time.current
  end

  def only_one_default_currency
    if is_default? && is_default_changed? && Currency.where.not(id: id).where(is_default: true).exists?
      errors.add(:is_default, "デフォルト通貨は1つだけ設定できます")
    end
  end

  def update_related_currencies
    if is_default?
      # 他のすべての通貨のデフォルトフラグをfalseに設定
      Currency.where.not(id: id).update_all(is_default: false)

      # デフォルト通貨の為替レートを1.0に設定
      update_column(:exchange_rate_to_default, 1.0)
    end
  end

  def clear_cache
    Rails.cache.delete('default_currency')
    Rails.cache.delete("currency:#{code}")
  end
end
