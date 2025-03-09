class Cart < ApplicationRecord
  # 関連付け
  belongs_to :user, optional: true
  belongs_to :shipping_address, class_name: 'Address', optional: true
  belongs_to :billing_address, class_name: 'Address', optional: true
  belongs_to :converted_to_order, class_name: 'Order', optional: true

  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items

  # バリデーション
  validates :session_id, presence: true, if: -> { user_id.blank? }
  validates :status, presence: true

  # コールバック
  before_validation :set_default_values, if: :new_record?
  before_save :update_totals
  before_save :set_last_activity_at

  # スコープ
  scope :active, -> { where(status: 'active') }
  scope :abandoned, -> { where(status: 'abandoned') }
  scope :converted, -> { where(status: 'converted') }
  scope :merged, -> { where(status: 'merged') }
  scope :guest_carts, -> { where(is_guest: true) }
  scope :user_carts, -> { where(is_guest: false) }
  scope :with_items, -> { where('items_count > 0') }
  scope :empty, -> { where(items_count: 0) }
  scope :recent, -> { order(last_activity_at: :desc) }
  scope :recently_abandoned, -> { abandoned.where('last_activity_at > ?', 7.days.ago) }
  scope :with_coupon, -> { where.not(coupon_code: nil) }

  # クラスメソッド
  def self.find_or_create_for_user(user)
    cart = active.find_by(user: user)
    return cart if cart.present?

    create(user: user, status: 'active', is_guest: false)
  end

  def self.find_or_create_for_session(session_id)
    cart = active.find_by(session_id: session_id)
    return cart if cart.present?

    create(session_id: session_id, status: 'active', is_guest: true)
  end

  def self.merge_carts!(guest_cart, user_cart)
    return user_cart if guest_cart.nil? || user_cart.nil?

    # ゲストカートのアイテムをユーザーカートに移動
    guest_cart.cart_items.each do |item|
      existing_item = user_cart.cart_items.find_by(product_id: item.product_id, product_variant_id: item.product_variant_id)

      if existing_item
        # 既存のアイテムがある場合は数量を加算
        existing_item.update(quantity: existing_item.quantity + item.quantity)
      else
        # 既存のアイテムがない場合は新しいアイテムを作成
        item.update(cart: user_cart)
      end
    end

    # ゲストカートのクーポンをユーザーカートに適用（ユーザーカートにクーポンがない場合）
    if guest_cart.coupon_code.present? && user_cart.coupon_code.blank?
      user_cart.update(coupon_code: guest_cart.coupon_code)
    end

    # ゲストカートをマージ済みとしてマーク
    guest_cart.update(status: 'merged')

    # ユーザーカートを更新
    user_cart.update_totals
    user_cart.save

    user_cart
  end

  def self.cleanup_abandoned_carts!(days_old = 30)
    where(status: 'active')
      .where('last_activity_at < ?', days_old.days.ago)
      .update_all(status: 'abandoned')
  end

  def self.most_abandoned_products(limit = 10)
    joins(:cart_items)
      .where(status: 'abandoned')
      .group('cart_items.product_id')
      .order('COUNT(cart_items.id) DESC')
      .limit(limit)
      .count
  end

  # カスタムメソッド
  def add_item(product, quantity = 1, options = {})
    variant_id = options[:variant_id]
    is_gift = options[:is_gift] || false
    gift_message = options[:gift_message]
    has_gift_wrap = options[:has_gift_wrap] || false
    gift_wrap_id = options[:gift_wrap_id]

    item = cart_items.find_or_initialize_by(
      product_id: product.id,
      product_variant_id: variant_id
    )

    if item.new_record?
      item.quantity = quantity
      item.unit_price = product.price
      item.seller_id = product.seller_id
      item.is_gift = is_gift
      item.gift_message = gift_message
      item.has_gift_wrap = has_gift_wrap
      item.gift_wrap_id = gift_wrap_id
      item.added_at = Time.current
    else
      item.quantity += quantity
    end

    item.total_price = item.unit_price * item.quantity
    item.last_modified_at = Time.current

    if item.save
      update_totals
      save
      item
    else
      false
    end
  end

  def remove_item(product, variant_id = nil)
    conditions = { product_id: product.id }
    conditions[:product_variant_id] = variant_id if variant_id.present?

    item = cart_items.find_by(conditions)

    if item&.destroy
      update_totals
      save
      true
    else
      false
    end
  end

  def update_item_quantity(product, quantity, variant_id = nil)
    conditions = { product_id: product.id }
    conditions[:product_variant_id] = variant_id if variant_id.present?

    item = cart_items.find_by(conditions)

    if item&.update(quantity: quantity, total_price: item.unit_price * quantity, last_modified_at: Time.current)
      update_totals
      save
      item
    else
      false
    end
  end

  def clear!
    cart_items.destroy_all
    update_totals
    save
  end

  def empty?
    cart_items.empty?
  end

  def item_count
    cart_items.sum(:quantity)
  end

  def apply_coupon(coupon_code)
    self.coupon_code = coupon_code
    update_totals
    save
  end

  def remove_coupon
    self.coupon_code = nil
    self.discount_amount = 0
    update_totals
    save
  end

  def mark_as_abandoned!
    update(status: 'abandoned')
  end

  def mark_as_converted!(order)
    update(
      status: 'converted',
      converted_at: Time.current,
      converted_to_order: order
    )
  end

  def active?
    status == 'active'
  end

  def abandoned?
    status == 'abandoned'
  end

  def converted?
    status == 'converted'
  end

  def merged?
    status == 'merged'
  end

  def guest?
    is_guest?
  end

  def days_since_last_activity
    return 0 if last_activity_at.nil?
    (Date.current - last_activity_at.to_date).to_i
  end

  def update_totals
    # アイテム数の更新
    self.items_count = cart_items.sum(:quantity)

    # 小計の計算
    self.total_amount = cart_items.sum(:total_price)

    # クーポン割引の適用
    apply_coupon_discount if coupon_code.present?

    # 税金の計算
    calculate_tax

    # 配送料の計算
    calculate_shipping

    # 最終金額の計算
    self.final_amount = total_amount - (discount_amount || 0) + (tax_amount || 0) + (shipping_amount || 0)
  end

  private

  def set_default_values
    self.status ||= 'active'
    self.items_count ||= 0
    self.total_amount ||= 0
    self.discount_amount ||= 0
    self.tax_amount ||= 0
    self.shipping_amount ||= 0
    self.final_amount ||= 0
    self.currency ||= 'JPY'
    self.last_activity_at ||= Time.current
  end

  def set_last_activity_at
    self.last_activity_at = Time.current
  end

  def apply_coupon_discount
    # クーポン割引の計算ロジック（実装は別途必要）
    coupon = Coupon.find_by(code: coupon_code, is_active: true)

    if coupon && coupon.applicable?(self, user)
      self.discount_amount = coupon.calculate_discount(self)
    else
      self.discount_amount = 0
      self.coupon_code = nil
    end
  end

  def calculate_tax
    # 税金の計算ロジック（実装は別途必要）
    # 例: 消費税10%
    self.tax_amount = (total_amount - (discount_amount || 0)) * 0.1
  end

  def calculate_shipping
    # 配送料の計算ロジック（実装は別途必要）
    # 例: 5000円以上は送料無料、それ以下は一律500円
    self.shipping_amount = total_amount >= 5000 ? 0 : 500
  end
end
