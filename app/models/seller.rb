class Seller < ApplicationRecord
  # 関連付け
  belongs_to :user
  belongs_to :approved_by, class_name: 'User', optional: true

  has_many :products, dependent: :nullify
  has_many :seller_ratings, dependent: :destroy
  has_many :seller_products, dependent: :destroy
  has_many :seller_documents, dependent: :destroy
  has_many :seller_transactions, dependent: :destroy
  has_many :seller_policies, dependent: :destroy
  has_many :seller_performances, dependent: :destroy
  has_many :advertisements, dependent: :nullify

  # バリデーション
  validates :company_name, presence: true, length: { maximum: 255 }
  validates :contact_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :tax_identifier, uniqueness: true, allow_blank: true
  validates :business_type, presence: true
  validates :status, inclusion: { in: ['pending', 'approved', 'suspended', 'rejected'] }

  # コールバック
  before_save :set_approved_at, if: -> { status_changed? && status == 'approved' }
  before_save :set_verified_at, if: -> { is_verified_changed? && is_verified? }

  # スコープ
  scope :approved, -> { where(status: 'approved') }
  scope :pending, -> { where(status: 'pending') }
  scope :suspended, -> { where(status: 'suspended') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :verified, -> { where(is_verified: true) }
  scope :featured, -> { where(is_featured: true) }
  scope :active, -> { approved.where('last_active_at > ?', 30.days.ago) }
  scope :by_business_type, ->(type) { where(business_type: type) }
  scope :top_rated, -> { approved.order(average_rating: :desc) }
  scope :most_products, -> { approved.order(products_count: :desc) }
  scope :recently_joined, -> { approved.order(approved_at: :desc) }

  # カスタムメソッド
  def approve!(approver = nil)
    update(
      status: 'approved',
      approved_by: approver,
      approved_at: Time.current
    )
  end

  def reject!(reason = nil)
    update(
      status: 'rejected',
      rejection_reason: reason
    )
  end

  def suspend!(reason = nil)
    update(
      status: 'suspended',
      suspension_reason: reason
    )
  end

  def reactivate!
    update(status: 'approved')
  end

  def verify!
    update(is_verified: true, verified_at: Time.current)
  end

  def unverify!
    update(is_verified: false, verified_at: nil)
  end

  def feature!
    update(is_featured: true)
  end

  def unfeature!
    update(is_featured: false)
  end

  def update_last_active!
    update(last_active_at: Time.current)
  end

  def update_ratings_stats!
    ratings = seller_ratings.where(is_approved: true)

    update(
      average_rating: ratings.average(:rating).to_f.round(2),
      ratings_count: ratings.count
    )
  end

  def update_products_count!
    update(products_count: products.active.count)
  end

  def active?
    status == 'approved' && (last_active_at.nil? || last_active_at > 30.days.ago)
  end

  def pending?
    status == 'pending'
  end

  def suspended?
    status == 'suspended'
  end

  def rejected?
    status == 'rejected'
  end

  def verified?
    is_verified?
  end

  def featured?
    is_featured?
  end

  def store_url
    self[:store_url] || generate_store_url
  end

  def current_performance
    seller_performances.order(period_end: :desc).first
  end

  def eligible_for_prime?
    return false unless active? && verified?

    performance = current_performance
    return false if performance.nil?

    performance.is_eligible_for_prime?
  end

  private

  def set_approved_at
    self.approved_at = Time.current
  end

  def set_verified_at
    self.verified_at = Time.current
  end

  def generate_store_url
    slug = company_name.parameterize
    "/sellers/#{slug}-#{id}"
  end
end
