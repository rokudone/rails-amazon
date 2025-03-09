class CartItem < ApplicationRecord
  # 関連付け
  belongs_to :cart
  belongs_to :product
  belongs_to :product_variant, optional: true
  belongs_to :seller, optional: true
  belongs_to :gift_wrap, optional: true

  # バリデーション
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :product_id, uniqueness: { scope: [:cart_id, :product_variant_id], message: "すでにカートに追加されています" }

  # コールバック
  before_validation :set_total_price
  before_validation :set_timestamps, if: :new_record?
  after_save :update_cart_totals
  after_destroy :update_cart_totals

  # スコープ
  scope :active, -> { where(is_saved_for_later: false) }
  scope :saved_for_later, -> { where(is_saved_for_later: true) }
  scope :gifts, -> { where(is_gift: true) }
  scope :with_gift_wrap, -> { where(has_gift_wrap: true) }
  scope :in_stock, -> { where(status: 'in_stock') }
  scope :out_of_stock, -> { where(status: 'out_of_stock') }
  scope :back_ordered, -> { where(status: 'back_ordered') }
  scope :by_seller, ->(seller_id) { where(seller_id: seller_id) }
  scope :recent, -> { order(added_at: :desc) }

  # カスタムメソッド
  def save_for_later!
    update(is_saved_for_later: true)
  end

  def move_to_cart!
    update(is_saved_for_later: false)
  end

  def mark_as_gift!(message = nil)
    update(is_gift: true, gift_message: message)
  end

  def unmark_as_gift!
    update(is_gift: false, gift_message: nil)
  end

  def add_gift_wrap!(gift_wrap)
    update(has_gift_wrap: true, gift_wrap: gift_wrap)
  end

  def remove_gift_wrap!
    update(has_gift_wrap: false, gift_wrap: nil)
  end

  def increment_quantity!(amount = 1)
    update(quantity: quantity + amount)
  end

  def decrement_quantity!(amount = 1)
    new_quantity = [quantity - amount, 1].max
    update(quantity: new_quantity)
  end

  def update_status!
    # 在庫状況の確認ロジック（実装は別途必要）
    inventory = Inventory.find_by(product: product)

    if inventory.nil?
      self.status = 'unknown'
    elsif inventory.quantity >= quantity
      self.status = 'in_stock'
    elsif inventory.quantity > 0
      self.status = 'limited_stock'
    elsif inventory.backorderable?
      self.status = 'back_ordered'
    else
      self.status = 'out_of_stock'
    end

    save
  end

  def price_changed?
    return false unless product.present?
    unit_price != product.price
  end

  def update_price!
    return false unless product.present?
    update(unit_price: product.price, total_price: product.price * quantity)
  end

  def subtotal
    unit_price * quantity
  end

  def gift_wrap_cost
    return 0 unless has_gift_wrap? && gift_wrap.present?
    gift_wrap.price * quantity
  end

  def total_with_gift_wrap
    subtotal + gift_wrap_cost
  end

  def saved_amount
    return 0 unless product.present?
    original_price = product.original_price || unit_price
    discount = original_price - unit_price
    discount > 0 ? discount * quantity : 0
  end

  def discount_percentage
    return 0 unless product.present?
    original_price = product.original_price || unit_price
    return 0 if original_price.zero?

    discount = original_price - unit_price
    discount > 0 ? (discount / original_price * 100).round : 0
  end

  def variant_options
    return [] unless product_variant.present?

    # バリアントのオプション情報を取得（実装は別途必要）
    product_variant.option_values
  end

  def selected_options_text
    return nil if selected_options.blank?

    begin
      options = JSON.parse(selected_options)
      options.map { |k, v| "#{k}: #{v}" }.join(', ')
    rescue JSON::ParserError
      selected_options
    end
  end

  def in_stock?
    status == 'in_stock'
  end

  def out_of_stock?
    status == 'out_of_stock'
  end

  def back_ordered?
    status == 'back_ordered'
  end

  def limited_stock?
    status == 'limited_stock'
  end

  def status_text
    case status
    when 'in_stock'
      '在庫あり'
    when 'limited_stock'
      '残りわずか'
    when 'out_of_stock'
      '在庫切れ'
    when 'back_ordered'
      '入荷待ち'
    else
      '状態不明'
    end
  end

  def days_in_cart
    return 0 if added_at.nil?
    (Date.current - added_at.to_date).to_i
  end

  private

  def set_total_price
    self.total_price = unit_price * quantity if unit_price.present? && quantity.present?
  end

  def set_timestamps
    self.added_at ||= Time.current
    self.last_modified_at ||= Time.current
  end

  def update_cart_totals
    cart.update_totals if cart.present?
  end
end
