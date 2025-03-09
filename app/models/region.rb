class Region < ApplicationRecord
  # 関連付け
  belongs_to :country
  has_many :addresses, dependent: :nullify

  # バリデーション
  validates :code, presence: true
  validates :name, presence: true
  validates :code, uniqueness: { scope: :country_id, message: "この国ではすでに同じコードの地域が存在します" }
  validates :name, uniqueness: { scope: :country_id, message: "この国ではすでに同じ名前の地域が存在します" }

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :shipping_available, -> { where(is_shipping_available: true) }
  scope :billing_available, -> { where(is_billing_available: true) }
  scope :by_country, ->(country_id) { where(country_id: country_id) }
  scope :by_region_type, ->(type) { where(region_type: type) }
  scope :ordered, -> { order(position: :asc) }
  scope :alphabetical, -> { order(name: :asc) }

  # クラスメソッド
  def self.find_by_code_and_country(code, country_id)
    where(code: code, country_id: country_id).first
  end

  def self.find_by_name_and_country(name, country_id)
    where('(name ILIKE ? OR native_name ILIKE ?) AND country_id = ?', "%#{name}%", "%#{name}%", country_id).first
  end

  def self.import_from_json(json_data, country)
    regions_data = JSON.parse(json_data)

    transaction do
      regions_data.each do |data|
        region = find_or_initialize_by(country: country, code: data['code'])

        region.update!(
          name: data['name'],
          native_name: data['native_name'],
          region_type: data['region_type'],
          latitude: data['latitude'],
          longitude: data['longitude'],
          is_active: true
        )
      end
    end
  end

  def self.grouped_by_country
    includes(:country).order('countries.name', :name).group_by(&:country)
  end

  def self.for_select(country_id)
    by_country(country_id).active.ordered.map { |r| [r.name, r.id] }
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

  def full_name
    "#{name}, #{country.name}"
  end

  def native_full_name
    native_name.present? ? "#{native_name}, #{country.native_name}" : full_name
  end

  def region_type_name
    case region_type
    when 'state'
      '州'
    when 'province'
      '省'
    when 'prefecture'
      '都道府県'
    when 'territory'
      '準州'
    when 'district'
      '地区'
    when 'county'
      '郡'
    when 'municipality'
      '自治体'
    else
      region_type.presence || '地域'
    end
  end

  def metadata_hash
    return {} if metadata.blank?

    begin
      JSON.parse(metadata)
    rescue JSON::ParserError
      {}
    end
  end

  def shipping_available?
    is_shipping_available? && country.shipping_available?
  end

  def billing_available?
    is_billing_available? && country.billing_available?
  end

  def active?
    is_active? && country.active?
  end

  def has_addresses?
    addresses.exists?
  end
end
