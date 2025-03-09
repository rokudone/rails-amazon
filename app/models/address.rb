class Address < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :address_line1, :city, :postal_code, :country, presence: true
  validates :address_type, inclusion: { in: %w[billing shipping both] }, allow_blank: true
  validates :postal_code, format: { with: /\A[a-zA-Z0-9\-\s]{3,10}\z/ }
  validates :phone_number, format: { with: /\A\d{10,15}\z/ }, allow_blank: true

  # コールバック
  before_save :ensure_only_one_default_address, if: -> { is_default_changed? && is_default? }

  # スコープ
  scope :default, -> { where(is_default: true) }
  scope :billing, -> { where(address_type: ['billing', 'both']) }
  scope :shipping, -> { where(address_type: ['shipping', 'both']) }

  private

  def ensure_only_one_default_address
    user.addresses.where.not(id: id).update_all(is_default: false) if user
  end
end
