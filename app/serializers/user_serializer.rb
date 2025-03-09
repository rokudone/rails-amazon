class UserSerializer < BaseSerializer
  # 基本属性
  attributes :id, :email, :first_name, :last_name, :phone_number, :active
  attributes :last_login_at, :created_at, :updated_at

  # 機密情報は除外
  attribute :email, if: ->(user, options) { options[:include_private] }
  attribute :phone_number, if: ->(user, options) { options[:include_private] }

  # 計算属性
  attribute :full_name, method: :get_full_name
  attribute :member_since, method: :get_member_since
  attribute :account_status, method: :get_account_status

  # 関連データ
  has_one :profile, serializer: ProfileSerializer
  has_many :addresses, serializer: AddressSerializer
  has_many :payment_methods, serializer: PaymentMethodSerializer, if: ->(user, options) { options[:include_private] }
  has_one :user_preference, serializer: UserPreferenceSerializer
  has_many :orders, serializer: OrderSerializer, if: ->(user, options) { options[:include_orders] }
  has_many :reviews, serializer: ReviewSerializer, if: ->(user, options) { options[:include_reviews] }
  has_many :wishlists, serializer: WishlistSerializer, if: ->(user, options) { options[:include_wishlists] }
  has_one :cart, serializer: CartSerializer, if: ->(user, options) { options[:include_cart] }
  has_many :user_subscriptions, serializer: UserSubscriptionSerializer, if: ->(user, options) { options[:include_subscriptions] }
  has_many :user_rewards, serializer: UserRewardSerializer, if: ->(user, options) { options[:include_rewards] }

  # メタデータ
  meta :order_count, method: :count_orders
  meta :review_count, method: :count_reviews
  meta :wishlist_count, method: :count_wishlists
  meta :cart_item_count, method: :count_cart_items
  meta :reward_points, method: :calculate_reward_points

  # フルネームを取得
  def get_full_name(user)
    "#{user.first_name} #{user.last_name}".strip
  end

  # 会員期間を取得
  def get_member_since(user)
    user.created_at.strftime('%Y-%m-%d')
  end

  # アカウント状態を取得
  def get_account_status(user)
    if user.active
      if user.last_login_at && user.last_login_at > 30.days.ago
        'active'
      else
        'inactive'
      end
    else
      'suspended'
    end
  end

  # 注文数を取得
  def count_orders(user)
    user.orders.count
  end

  # レビュー数を取得
  def count_reviews(user)
    user.reviews.count
  end

  # ウィッシュリスト数を取得
  def count_wishlists(user)
    user.wishlists.count
  end

  # カートアイテム数を取得
  def count_cart_items(user)
    user.cart&.cart_items&.sum(:quantity) || 0
  end

  # ポイント合計を計算
  def calculate_reward_points(user)
    user.user_rewards.where(reward_type: 'points').sum(:points)
  end
end

# ProfileSerializer
class ProfileSerializer < BaseSerializer
  attributes :id, :birth_date, :gender, :bio, :avatar, :website, :occupation, :company

  # 年齢を計算
  attribute :age, method: :calculate_age

  # 年齢を計算
  def calculate_age(profile)
    return nil unless profile.birth_date

    now = Time.now.utc.to_date
    now.year - profile.birth_date.year - (now.month > profile.birth_date.month || (now.month == profile.birth_date.month && now.day >= profile.birth_date.day) ? 0 : 1)
  end
end

# PaymentMethodSerializer
class PaymentMethodSerializer < BaseSerializer
  attributes :id, :payment_type, :provider, :is_default

  # マスクされたカード番号
  attribute :masked_account_number, method: :mask_account_number

  # 有効期限
  attribute :expiry_date

  # カード番号をマスク
  def mask_account_number(payment_method)
    return nil unless payment_method.account_number

    # 最後の4桁以外をマスク
    "**** **** **** #{payment_method.account_number.last(4)}"
  end
end

# UserPreferenceSerializer
class UserPreferenceSerializer < BaseSerializer
  attributes :id, :email_notifications, :sms_notifications, :push_notifications
  attributes :language, :currency, :timezone, :two_factor_auth
end

# WishlistSerializer
class WishlistSerializer < BaseSerializer
  attributes :id, :name, :description, :is_public, :created_at

  # 関連データ
  has_many :wishlist_items, serializer: WishlistItemSerializer

  # アイテム数
  attribute :item_count, method: :count_items

  # アイテム数を取得
  def count_items(wishlist)
    wishlist.wishlist_items.count
  end
end

# WishlistItemSerializer
class WishlistItemSerializer < BaseSerializer
  attributes :id, :created_at

  # 関連データ
  has_one :product, serializer: ProductSerializer
  has_one :product_variant, serializer: ProductVariantSerializer
end

# CartSerializer
class CartSerializer < BaseSerializer
  attributes :id, :created_at, :updated_at

  # 関連データ
  has_many :cart_items, serializer: CartItemSerializer

  # 合計金額
  attribute :total, method: :calculate_total
  attribute :formatted_total, method: :format_total

  # アイテム数
  attribute :item_count, method: :count_items

  # 合計金額を計算
  def calculate_total(cart)
    cart.cart_items.sum { |item| item.price * item.quantity }
  end

  # 合計金額をフォーマット
  def format_total(cart)
    total = calculate_total(cart)
    "¥#{total.to_i.to_s(:delimited)}"
  end

  # アイテム数を取得
  def count_items(cart)
    cart.cart_items.sum(:quantity)
  end
end

# CartItemSerializer
class CartItemSerializer < BaseSerializer
  attributes :id, :quantity, :price, :created_at

  # 関連データ
  has_one :product, serializer: ProductSerializer
  has_one :product_variant, serializer: ProductVariantSerializer

  # 小計
  attribute :subtotal, method: :calculate_subtotal
  attribute :formatted_subtotal, method: :format_subtotal

  # 小計を計算
  def calculate_subtotal(cart_item)
    cart_item.price * cart_item.quantity
  end

  # 小計をフォーマット
  def format_subtotal(cart_item)
    subtotal = calculate_subtotal(cart_item)
    "¥#{subtotal.to_i.to_s(:delimited)}"
  end
end

# UserSubscriptionSerializer
class UserSubscriptionSerializer < BaseSerializer
  attributes :id, :plan_name, :price, :billing_cycle, :start_date, :end_date
  attributes :auto_renew, :status, :created_at

  # 金額関連の属性
  attribute :formatted_price, method: :format_price

  # 残り日数
  attribute :days_remaining, method: :calculate_days_remaining

  # 金額をフォーマット
  def format_price(subscription)
    "¥#{subscription.price.to_i.to_s(:delimited)}"
  end

  # 残り日数を計算
  def calculate_days_remaining(subscription)
    return nil unless subscription.end_date

    (subscription.end_date.to_date - Date.today).to_i
  end
end

# UserRewardSerializer
class UserRewardSerializer < BaseSerializer
  attributes :id, :reward_type, :points, :amount, :expires_at, :is_used, :created_at

  # 金額関連の属性
  attribute :formatted_amount, method: :format_amount

  # 有効期限までの日数
  attribute :days_until_expiry, method: :calculate_days_until_expiry

  # 金額をフォーマット
  def format_amount(reward)
    return nil unless reward.amount

    "¥#{reward.amount.to_i.to_s(:delimited)}"
  end

  # 有効期限までの日数を計算
  def calculate_days_until_expiry(reward)
    return nil unless reward.expires_at

    (reward.expires_at.to_date - Date.today).to_i
  end
end
