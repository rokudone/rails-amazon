class PromotionRule < ApplicationRecord
  # 関連付け
  belongs_to :promotion

  # バリデーション
  validates :rule_type, presence: true
  validates :operator, presence: true
  validates :value, presence: true

  # スコープ
  scope :mandatory, -> { where(is_mandatory: true) }
  scope :optional, -> { where(is_mandatory: false) }
  scope :by_type, ->(type) { where(rule_type: type) }
  scope :ordered, -> { order(position: :asc) }

  # カスタムメソッド
  def eligible?(order)
    case rule_type
    when 'product'
      product_rule_eligible?(order)
    when 'category'
      category_rule_eligible?(order)
    when 'customer'
      customer_rule_eligible?(order)
    when 'cart_quantity'
      cart_quantity_rule_eligible?(order)
    when 'cart_amount'
      cart_amount_rule_eligible?(order)
    when 'time'
      time_rule_eligible?
    when 'user_group'
      user_group_rule_eligible?(order)
    when 'custom'
      custom_rule_eligible?(order)
    else
      false
    end
  end

  private

  def product_rule_eligible?(order)
    product_ids = parse_value_as_array

    case operator
    when 'include'
      (order.product_ids & product_ids).any?
    when 'exclude'
      (order.product_ids & product_ids).empty?
    when 'only'
      order.product_ids.sort == product_ids.sort
    else
      false
    end
  end

  def category_rule_eligible?(order)
    category_ids = parse_value_as_array
    order_category_ids = order.items.map { |item| item.product.category_id }.uniq

    case operator
    when 'include'
      (order_category_ids & category_ids).any?
    when 'exclude'
      (order_category_ids & category_ids).empty?
    when 'only'
      order_category_ids.sort == category_ids.sort
    else
      false
    end
  end

  def customer_rule_eligible?(order)
    return false unless order.user.present?

    case operator
    when 'new_customer'
      order.user.orders.completed.count <= 1
    when 'returning_customer'
      order.user.orders.completed.count > 1
    when 'prime_member'
      order.user.prime_member?
    when 'specific_user'
      user_ids = parse_value_as_array
      user_ids.include?(order.user_id.to_s)
    else
      false
    end
  end

  def cart_quantity_rule_eligible?(order)
    quantity = order.items.sum(&:quantity)
    threshold = value.to_i

    case operator
    when 'greater_than'
      quantity > threshold
    when 'greater_than_or_equal'
      quantity >= threshold
    when 'equal'
      quantity == threshold
    when 'less_than'
      quantity < threshold
    when 'less_than_or_equal'
      quantity <= threshold
    else
      false
    end
  end

  def cart_amount_rule_eligible?(order)
    amount = order.total
    threshold = value.to_f

    case operator
    when 'greater_than'
      amount > threshold
    when 'greater_than_or_equal'
      amount >= threshold
    when 'equal'
      amount == threshold
    when 'less_than'
      amount < threshold
    when 'less_than_or_equal'
      amount <= threshold
    else
      false
    end
  end

  def time_rule_eligible?
    current_time = Time.current

    case operator
    when 'weekday'
      (1..5).include?(current_time.wday)
    when 'weekend'
      [0, 6].include?(current_time.wday)
    when 'time_range'
      time_range = parse_value_as_time_range
      time_range.cover?(current_time)
    else
      false
    end
  end

  def user_group_rule_eligible?(order)
    return false unless order.user.present?

    group_ids = parse_value_as_array
    user_group_ids = order.user.user_groups.pluck(:id).map(&:to_s)

    case operator
    when 'include'
      (user_group_ids & group_ids).any?
    when 'exclude'
      (user_group_ids & group_ids).empty?
    else
      false
    end
  end

  def custom_rule_eligible?(order)
    # カスタムルールの評価ロジック（実装は別途必要）
    # JSONBのconditionsフィールドを使用して複雑なルールを評価
    false
  end

  def parse_value_as_array
    value.to_s.split(',').map(&:strip)
  end

  def parse_value_as_time_range
    start_time, end_time = value.to_s.split('-').map(&:strip)
    Time.parse(start_time)..Time.parse(end_time)
  rescue
    Time.current..Time.current
  end
end
