class GiftWrap < ApplicationRecord
  # 関連付け
  belongs_to :order
  belongs_to :order_item, optional: true

  # バリデーション
  validates :wrap_cost, numericality: { greater_than_or_equal_to: 0 }
  validates :wrap_type, inclusion: { in: ['standard', 'premium', 'luxury', 'eco_friendly', 'seasonal'] }, allow_nil: true
  validates :gift_message, length: { maximum: 500 }
  validates :gift_from, length: { maximum: 100 }
  validates :gift_to, length: { maximum: 100 }

  # スコープ
  scope :wrapped, -> { where(is_gift_wrapped: true) }
  scope :unwrapped, -> { where(is_gift_wrapped: false) }
  scope :by_wrap_type, ->(type) { where(wrap_type: type) }
  scope :with_gift_box, -> { where(include_gift_box: true) }
  scope :with_gift_receipt, -> { where(include_gift_receipt: true) }
  scope :hide_prices, -> { where(hide_prices: true) }
  scope :by_order, ->(order_id) { where(order_id: order_id) }
  scope :by_order_item, ->(order_item_id) { where(order_item_id: order_item_id) }
  scope :reusable_packaging, -> { where(is_reusable_packaging: true) }

  # コールバック
  after_save :update_order_item_gift_status, if: :saved_change_to_is_gift_wrapped?
  after_save :update_order_totals, if: :saved_change_to_wrap_cost?

  # カスタムメソッド
  def wrapped?
    is_gift_wrapped
  end

  def unwrapped?
    !is_gift_wrapped
  end

  def has_gift_box?
    include_gift_box
  end

  def has_gift_receipt?
    include_gift_receipt
  end

  def prices_hidden?
    hide_prices
  end

  def reusable_packaging?
    is_reusable_packaging
  end

  def wrap!(wrapper_name = nil)
    return false if wrapped?

    update(
      is_gift_wrapped: true,
      wrapped_by: wrapper_name,
      wrapped_at: Time.now
    )
  end

  def unwrap!
    return false unless wrapped?

    update(
      is_gift_wrapped: false,
      wrapped_by: nil,
      wrapped_at: nil
    )
  end

  def wrap_type_label
    case wrap_type
    when 'standard'
      '標準'
    when 'premium'
      'プレミアム'
    when 'luxury'
      '高級'
    when 'eco_friendly'
      'エコフレンドリー'
    when 'seasonal'
      '季節限定'
    else
      wrap_type
    end
  end

  def formatted_gift_message
    return nil if gift_message.blank?

    if gift_from.present? && gift_to.present?
      "To: #{gift_to}\n#{gift_message}\nFrom: #{gift_from}"
    elsif gift_from.present?
      "#{gift_message}\nFrom: #{gift_from}"
    elsif gift_to.present?
      "To: #{gift_to}\n#{gift_message}"
    else
      gift_message
    end
  end

  def formatted_wrapped_at
    wrapped_at&.strftime('%Y年%m月%d日 %H:%M:%S')
  end

  def self.wrap_options
    [
      { type: 'standard', name: '標準', cost: 3.99, description: '標準的なギフトラッピング' },
      { type: 'premium', name: 'プレミアム', cost: 5.99, description: '高品質な紙とリボンを使用したラッピング' },
      { type: 'luxury', name: '高級', cost: 9.99, description: '最高級の素材を使用した豪華なラッピング' },
      { type: 'eco_friendly', name: 'エコフレンドリー', cost: 4.99, description: '環境に優しい素材を使用したラッピング' },
      { type: 'seasonal', name: '季節限定', cost: 6.99, description: '季節に合わせたデザインのラッピング' }
    ]
  end

  def self.ribbon_options
    [
      { type: 'standard', name: '標準', colors: ['red', 'blue', 'green', 'gold', 'silver'] },
      { type: 'satin', name: 'サテン', colors: ['white', 'black', 'pink', 'purple', 'navy'] },
      { type: 'organza', name: 'オーガンザ', colors: ['white', 'gold', 'silver', 'multi'] },
      { type: 'grosgrain', name: 'グログラン', colors: ['red', 'blue', 'green', 'black', 'white'] },
      { type: 'velvet', name: 'ベルベット', colors: ['red', 'green', 'blue', 'purple', 'black'] }
    ]
  end

  def self.wrap_color_options
    [
      'red', 'green', 'blue', 'gold', 'silver', 'white', 'black', 'pink', 'purple',
      'kraft', 'polka_dot', 'stripes', 'floral', 'holiday', 'birthday', 'wedding'
    ]
  end

  def self.packaging_type_options
    [
      { type: 'box', name: 'ボックス' },
      { type: 'bag', name: 'バッグ' },
      { type: 'tissue', name: 'ティッシュペーパー' },
      { type: 'envelope', name: '封筒' },
      { type: 'tube', name: '筒' }
    ]
  end

  private

  def update_order_item_gift_status
    return unless order_item

    order_item.update(
      is_gift: is_gift_wrapped,
      gift_message: gift_message,
      gift_wrap_type: wrap_type,
      gift_wrap_cost: wrap_cost
    )
  end

  def update_order_totals
    return unless order

    # 注文の総額を再計算
    order.calculate_totals
    order.save
  end
end
