class RecentlyViewed < ApplicationRecord
  # 関連付け
  belongs_to :user
  belongs_to :product

  # バリデーション
  validates :user_id, uniqueness: { scope: :product_id, message: "すでにこの商品を閲覧履歴に追加しています" }

  # コールバック
  before_save :set_last_viewed_at

  # スコープ
  scope :recent, -> { order(last_viewed_at: :desc) }
  scope :most_viewed, -> { order(view_count: :desc) }
  scope :longest_viewed, -> { order(view_duration: :desc) }
  scope :from_search, -> { where(source: 'search') }
  scope :from_recommendation, -> { where(source: 'recommendation') }
  scope :from_category, -> { where(source: 'category') }
  scope :from_direct, -> { where(source: 'direct') }
  scope :by_device_type, ->(device_type) { where(device_type: device_type) }
  scope :added_to_cart, -> { where(added_to_cart: true) }
  scope :added_to_wishlist, -> { where(added_to_wishlist: true) }
  scope :purchased, -> { where(purchased: true) }
  scope :not_purchased, -> { where(purchased: false) }
  scope :by_session, ->(session_id) { where(session_id: session_id) }
  scope :by_date_range, ->(start_date, end_date) { where(last_viewed_at: start_date..end_date) }

  # クラスメソッド
  def self.record_view!(user, product, options = {})
    recently_viewed = find_or_initialize_by(user: user, product: product)

    recently_viewed.view_count += 1
    recently_viewed.last_viewed_at = Time.current
    recently_viewed.view_duration = options[:duration] if options[:duration].present?
    recently_viewed.source = options[:source] if options[:source].present?
    recently_viewed.device_type = options[:device_type] if options[:device_type].present?
    recently_viewed.session_id = options[:session_id] if options[:session_id].present?

    recently_viewed.save
    recently_viewed
  end

  def self.mark_as_added_to_cart!(user, product)
    recently_viewed = find_by(user: user, product: product)
    recently_viewed&.update(added_to_cart: true)
  end

  def self.mark_as_added_to_wishlist!(user, product)
    recently_viewed = find_by(user: user, product: product)
    recently_viewed&.update(added_to_wishlist: true)
  end

  def self.mark_as_purchased!(user, product)
    recently_viewed = find_by(user: user, product: product)
    recently_viewed&.update(purchased: true)
  end

  def self.cleanup_old_records!(user, max_records = 100)
    records = where(user: user).order(last_viewed_at: :desc)

    if records.count > max_records
      records.offset(max_records).destroy_all
    end
  end

  def self.popular_products(limit = 10, days = 30)
    joins(:product)
      .where('recently_vieweds.last_viewed_at > ?', days.days.ago)
      .group('products.id')
      .order('COUNT(recently_vieweds.id) DESC')
      .limit(limit)
      .count
  end

  def self.conversion_rate(days = 30)
    total = where('last_viewed_at > ?', days.days.ago).count
    purchased = where('last_viewed_at > ? AND purchased = true', days.days.ago).count

    return 0 if total.zero?
    (purchased.to_f / total * 100).round(2)
  end

  def self.cart_addition_rate(days = 30)
    total = where('last_viewed_at > ?', days.days.ago).count
    added_to_cart = where('last_viewed_at > ? AND added_to_cart = true', days.days.ago).count

    return 0 if total.zero?
    (added_to_cart.to_f / total * 100).round(2)
  end

  def self.wishlist_addition_rate(days = 30)
    total = where('last_viewed_at > ?', days.days.ago).count
    added_to_wishlist = where('last_viewed_at > ? AND added_to_wishlist = true', days.days.ago).count

    return 0 if total.zero?
    (added_to_wishlist.to_f / total * 100).round(2)
  end

  # カスタムメソッド
  def increment_view_count!
    increment!(:view_count)
    update(last_viewed_at: Time.current)
  end

  def update_view_duration!(duration)
    if view_duration.present?
      update(view_duration: view_duration + duration)
    else
      update(view_duration: duration)
    end
  end

  def mark_as_added_to_cart!
    update(added_to_cart: true)
  end

  def mark_as_added_to_wishlist!
    update(added_to_wishlist: true)
  end

  def mark_as_purchased!
    update(purchased: true)
  end

  def source_name
    case source
    when 'search'
      '検索'
    when 'recommendation'
      'おすすめ'
    when 'category'
      'カテゴリ'
    when 'direct'
      '直接アクセス'
    else
      source.humanize
    end
  end

  def device_type_name
    case device_type
    when 'desktop'
      'デスクトップ'
    when 'mobile'
      'モバイル'
    when 'tablet'
      'タブレット'
    else
      device_type.humanize
    end
  end

  def formatted_view_duration
    return nil if view_duration.nil?

    if view_duration < 60
      "#{view_duration.round}秒"
    elsif view_duration < 3600
      minutes = (view_duration / 60).floor
      seconds = (view_duration % 60).round
      "#{minutes}分#{seconds}秒"
    else
      hours = (view_duration / 3600).floor
      minutes = ((view_duration % 3600) / 60).floor
      "#{hours}時間#{minutes}分"
    end
  end

  def days_since_last_view
    return 0 if last_viewed_at.nil?
    (Date.current - last_viewed_at.to_date).to_i
  end

  private

  def set_last_viewed_at
    self.last_viewed_at = Time.current if last_viewed_at.nil?
  end
end
