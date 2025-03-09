class Wishlist < ApplicationRecord
  # 関連付け
  belongs_to :user
  has_many :wishlist_items, dependent: :destroy
  has_many :products, through: :wishlist_items

  # バリデーション
  validates :name, presence: true
  validates :user_id, uniqueness: { scope: :name, message: "すでに同じ名前のウィッシュリストを持っています" }

  # コールバック
  before_validation :set_default_name, if: -> { name.blank? }
  before_create :generate_sharing_token
  before_save :set_last_modified_at, if: -> { new_record? || changed? }
  after_save :ensure_default_wishlist, if: -> { is_default_changed? && is_default? }
  after_create :set_as_default_if_first

  # スコープ
  scope :active, -> { where(status: 'active') }
  scope :archived, -> { where(status: 'archived') }
  scope :deleted, -> { where(status: 'deleted') }
  scope :public_wishlists, -> { where(is_public: true) }
  scope :private_wishlists, -> { where(is_public: false) }
  scope :default_wishlists, -> { where(is_default: true) }
  scope :by_occasion, ->(occasion) { where(occasion: occasion) }
  scope :upcoming_occasions, -> { where('occasion_date >= ?', Date.current).order(occasion_date: :asc) }
  scope :recent, -> { order(last_modified_at: :desc) }
  scope :with_items, -> { where('items_count > 0') }
  scope :empty, -> { where(items_count: 0) }

  # クラスメソッド
  def self.find_by_sharing_token(token)
    find_by(sharing_token: token, is_public: true, status: 'active')
  end

  def self.create_default_wishlist(user)
    create(
      user: user,
      name: 'マイウィッシュリスト',
      is_default: true,
      is_public: false,
      status: 'active'
    )
  end

  def self.most_popular_products(limit = 10)
    joins(:wishlist_items)
      .group('wishlist_items.product_id')
      .order('COUNT(wishlist_items.id) DESC')
      .limit(limit)
      .count
  end

  # カスタムメソッド
  def add_item(product, options = {})
    item = wishlist_items.find_or_initialize_by(product: product)

    item.quantity = options[:quantity] if options[:quantity].present?
    item.priority = options[:priority] if options[:priority].present?
    item.note = options[:note] if options[:note].present?
    item.notify_on_price_drop = options[:notify_on_price_drop] if options[:notify_on_price_drop].present?
    item.price_at_addition = product.price if item.new_record?
    item.added_at = Time.current if item.new_record?

    if item.save
      update_items_count
      update_last_modified
      item
    else
      false
    end
  end

  def remove_item(product)
    item = wishlist_items.find_by(product: product)

    if item&.destroy
      update_items_count
      update_last_modified
      true
    else
      false
    end
  end

  def update_item_quantity(product, quantity)
    item = wishlist_items.find_by(product: product)

    if item&.update(quantity: quantity)
      update_last_modified
      item
    else
      false
    end
  end

  def mark_item_as_purchased(product, purchaser = nil)
    item = wishlist_items.find_by(product: product)

    if item&.update(is_purchased: true, purchased_by: purchaser, purchased_at: Time.current)
      update_last_modified
      item
    else
      false
    end
  end

  def mark_item_as_unpurchased(product)
    item = wishlist_items.find_by(product: product)

    if item&.update(is_purchased: false, purchased_by: nil, purchased_at: nil)
      update_last_modified
      item
    else
      false
    end
  end

  def contains?(product)
    wishlist_items.exists?(product: product)
  end

  def make_public!
    update(is_public: true)
  end

  def make_private!
    update(is_public: false)
  end

  def set_as_default!
    update(is_default: true)
  end

  def unset_as_default!
    update(is_default: false)
  end

  def archive!
    update(status: 'archived')
  end

  def unarchive!
    update(status: 'active')
  end

  def soft_delete!
    update(status: 'deleted')
  end

  def restore!
    update(status: 'active')
  end

  def regenerate_sharing_token!
    update(sharing_token: generate_token)
  end

  def public_url
    return nil unless is_public? && sharing_token.present?
    "/wishlists/#{sharing_token}"
  end

  def purchased_items
    wishlist_items.where(is_purchased: true)
  end

  def unpurchased_items
    wishlist_items.where(is_purchased: false)
  end

  def purchased_percentage
    return 0 if wishlist_items.count.zero?
    (purchased_items.count.to_f / wishlist_items.count * 100).round
  end

  def total_value
    wishlist_items.sum { |item| item.product.price * item.quantity }
  end

  def days_until_occasion
    return nil if occasion_date.nil?
    return 0 if occasion_date <= Date.current
    (occasion_date - Date.current).to_i
  end

  def active?
    status == 'active'
  end

  def archived?
    status == 'archived'
  end

  def deleted?
    status == 'deleted'
  end

  def public?
    is_public?
  end

  def private?
    !is_public?
  end

  def default?
    is_default?
  end

  def empty?
    items_count.zero?
  end

  private

  def set_default_name
    self.name = 'マイウィッシュリスト'
  end

  def generate_sharing_token
    self.sharing_token = generate_token
  end

  def generate_token
    loop do
      token = SecureRandom.urlsafe_base64(8)
      break token unless Wishlist.exists?(sharing_token: token)
    end
  end

  def set_last_modified_at
    self.last_modified_at = Time.current
  end

  def ensure_default_wishlist
    if is_default?
      user.wishlists.where.not(id: id).update_all(is_default: false)
    end
  end

  def set_as_default_if_first
    set_as_default! if user.wishlists.count == 1
  end

  def update_items_count
    update_column(:items_count, wishlist_items.count)
  end

  def update_last_modified
    update_column(:last_modified_at, Time.current)
  end
end
