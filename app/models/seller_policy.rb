class SellerPolicy < ApplicationRecord
  # 関連付け
  belongs_to :seller
  belongs_to :updated_by, class_name: 'User', optional: true
  belongs_to :approved_by, class_name: 'User', optional: true

  # バリデーション
  validates :policy_type, presence: true
  validates :content, presence: true
  validates :policy_type, uniqueness: { scope: :seller_id, message: "このタイプのポリシーはすでに存在します" }

  # コールバック
  before_save :set_last_updated_at
  before_save :set_approved_at, if: -> { is_approved_changed? && is_approved? }
  before_save :increment_version, if: -> { content_changed? }
  after_save :notify_customers, if: -> { saved_change_to_content? && is_approved? }

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :approved, -> { where(is_approved: true) }
  scope :pending, -> { where(is_approved: false) }
  scope :by_type, ->(type) { where(policy_type: type) }
  scope :return_policies, -> { where(policy_type: 'return') }
  scope :shipping_policies, -> { where(policy_type: 'shipping') }
  scope :privacy_policies, -> { where(policy_type: 'privacy') }
  scope :terms_policies, -> { where(policy_type: 'terms') }
  scope :recent, -> { order(last_updated_at: :desc) }

  # カスタムメソッド
  def activate!
    update(is_active: true)
  end

  def deactivate!
    update(is_active: false)
  end

  def approve!(approver)
    update(
      is_approved: true,
      approved_by: approver,
      approved_at: Time.current
    )
  end

  def reject!(reason = nil)
    update(
      is_approved: false,
      approval_notes: reason
    )
  end

  def update_content!(new_content, updater)
    update(
      content: new_content,
      updated_by: updater,
      is_approved: false # 内容が変更されたら再承認が必要
    )
  end

  def policy_type_name
    case policy_type
    when 'return'
      '返品ポリシー'
    when 'shipping'
      '配送ポリシー'
    when 'privacy'
      'プライバシーポリシー'
    when 'terms'
      '利用規約'
    when 'warranty'
      '保証ポリシー'
    when 'payment'
      '支払いポリシー'
    else
      policy_type.humanize
    end
  end

  def active?
    is_active?
  end

  def approved?
    is_approved?
  end

  def pending?
    !is_approved?
  end

  def effective?
    active? && approved? && (effective_date.nil? || effective_date <= Date.current)
  end

  def formatted_content
    # HTMLフォーマットなどの処理（実装は別途必要）
    content
  end

  def content_summary(length = 100)
    ActionController::Base.helpers.strip_tags(content).truncate(length)
  end

  def days_since_update
    return 0 if last_updated_at.nil?
    (Date.current - last_updated_at.to_date).to_i
  end

  def days_since_approval
    return nil if approved_at.nil?
    (Date.current - approved_at.to_date).to_i
  end

  private

  def set_last_updated_at
    self.last_updated_at = Time.current
  end

  def set_approved_at
    self.approved_at = Time.current
  end

  def increment_version
    if version.present?
      version_parts = version.split('.')
      if version_parts.size >= 2
        major, minor = version_parts.map(&:to_i)
        self.version = "#{major}.#{minor + 1}"
      else
        self.version = "1.1"
      end
    else
      self.version = "1.0"
    end
  end

  def notify_customers
    # ポリシー変更の通知処理（実装は別途必要）
  end
end
