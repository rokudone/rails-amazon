class Country < ApplicationRecord
  # 関連付け
  belongs_to :currency, optional: true
  has_many :regions, dependent: :destroy
  has_many :addresses, dependent: :nullify
  has_many :users, through: :addresses

  # バリデーション
  validates :code, presence: true, uniqueness: true, length: { is: 2 }
  validates :name, presence: true, uniqueness: true

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :shipping_available, -> { where(is_shipping_available: true) }
  scope :billing_available, -> { where(is_billing_available: true) }
  scope :by_region, ->(region) { where(region: region) }
  scope :by_subregion, ->(subregion) { where(subregion: subregion) }
  scope :ordered, -> { order(position: :asc) }
  scope :alphabetical, -> { order(name: :asc) }

  # クラスメソッド
  def self.default_country
    find_by(code: 'JP') || first
  end

  def self.find_by_code(code)
    where('UPPER(code) = ?', code.upcase).first
  end

  def self.find_by_name(name)
    where('name ILIKE ? OR native_name ILIKE ?', "%#{name}%", "%#{name}%").first
  end

  def self.countries_with_regions
    includes(:regions).where.not(regions: { id: nil })
  end

  def self.grouped_by_region
    active.order(:region, :name).group_by(&:region)
  end

  def self.import_from_json(json_data)
    countries_data = JSON.parse(json_data)

    transaction do
      countries_data.each do |data|
        country = find_or_initialize_by(code: data['code'])

        country.update!(
          name: data['name'],
          native_name: data['native_name'],
          phone_code: data['phone_code'],
          capital: data['capital'],
          currency_code: data['currency_code'],
          tld: data['tld'],
          region: data['region'],
          subregion: data['subregion'],
          latitude: data['latitude'],
          longitude: data['longitude'],
          flag_image_url: data['flag_image_url'],
          is_active: true
        )

        # 通貨の関連付け
        if data['currency_code'].present?
          currency = Currency.find_by(code: data['currency_code'])
          country.update(currency: currency) if currency.present?
        end
      end
    end
  end

  # カスタムメソッド
  def activate!
    update(is_active: true)
  end

  def deactivate!
    update(is_active: false)
  end

  def enable_shipping!
    update(is_shipping_available: true)
  end

  def disable_shipping!
    update(is_shipping_available: false)
  end

  def enable_billing!
    update(is_billing_available: true)
  end

  def disable_billing!
    update(is_billing_available: false)
  end

  def flag_url
    flag_image_url.presence || "/assets/flags/#{code.downcase}.png"
  end

  def formatted_phone_code
    phone_code.present? ? "+#{phone_code}" : nil
  end

  def address_format_hash
    return {} if address_format.blank?

    begin
      JSON.parse(address_format)
    rescue JSON::ParserError
      {}
    end
  end

  def postal_code_format_hash
    return {} if postal_code_format.blank?

    begin
      JSON.parse(postal_code_format)
    rescue JSON::ParserError
      {}
    end
  end

  def format_address(address_data)
    format = address_format_hash['format'] || '{name}\n{address1}\n{address2}\n{city}, {state} {zip}\n{country}'

    # プレースホルダーを実際の値で置換
    format.gsub('{name}', address_data[:name].to_s)
          .gsub('{address1}', address_data[:address1].to_s)
          .gsub('{address2}', address_data[:address2].to_s)
          .gsub('{city}', address_data[:city].to_s)
          .gsub('{state}', address_data[:state].to_s)
          .gsub('{zip}', address_data[:zip].to_s)
          .gsub('{country}', name)
  end

  def validate_postal_code(postal_code)
    return true if postal_code_format.blank?

    format = postal_code_format_hash['regex']
    return true if format.blank?

    regex = Regexp.new(format)
    regex.match?(postal_code)
  end

  def has_regions?
    regions.exists?
  end

  def region_name
    region.presence || 'その他'
  end

  def subregion_name
    subregion.presence || 'その他'
  end

  def currency_symbol
    currency&.symbol || '¥'
  end

  def currency_code
    currency&.code || 'JPY'
  end

  def shipping_available?
    is_shipping_available?
  end

  def billing_available?
    is_billing_available?
  end

  def active?
    is_active?
  end
end
