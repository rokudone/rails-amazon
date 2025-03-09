class Review < ApplicationRecord
  # 関連付け
  belongs_to :user
  belongs_to :product
  has_many :review_images, dependent: :destroy
  has_many :review_votes, dependent: :destroy

  # バリデーション
  validates :content, presence: true
  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :user_id, uniqueness: { scope: :product_id, message: "すでにこの商品のレビューを投稿しています" }

  # コールバック
  before_save :set_approved_at, if: -> { is_approved_changed? && is_approved? }
  after_save :update_product_rating, if: -> { saved_change_to_rating? || saved_change_to_is_approved? }

  # スコープ
  scope :approved, -> { where(is_approved: true) }
  scope :pending, -> { where(is_approved: false, status: 'pending') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :featured, -> { where(is_featured: true) }
  scope :verified_purchase, -> { where(verified_purchase: true) }
  scope :with_images, -> { joins(:review_images).distinct }
  scope :recent, -> { order(created_at: :desc) }
  scope :helpful, -> { order(helpful_votes_count: :desc) }
  scope :by_rating, ->(rating) { where(rating: rating) }
  scope :by_rating_range, ->(min, max) { where('rating >= ? AND rating <= ?', min, max) }

  # カスタムメソッド
  def helpful_percentage
    return 0 if total_votes.zero?
    (helpful_votes_count.to_f / total_votes * 100).round(1)
  end

  def total_votes
    helpful_votes_count + unhelpful_votes_count
  end

  def approve!
    update(is_approved: true, status: 'approved', approved_at: Time.current)
  end

  def reject!(reason = nil)
    update(is_approved: false, status: 'rejected', rejection_reason: reason)
  end

  def featured!
    update(is_featured: true)
  end

  def unfeatured!
    update(is_featured: false)
  end

  def vote_helpful!(user)
    review_votes.find_or_create_by(user: user, is_helpful: true)
    update_vote_counts
  end

  def vote_unhelpful!(user)
    review_votes.find_or_create_by(user: user, is_helpful: false)
    update_vote_counts
  end

  private

  def set_approved_at
    self.approved_at = Time.current
  end

  def update_product_rating
    product.update_average_rating if product.present?
  end

  def update_vote_counts
    update(
      helpful_votes_count: review_votes.where(is_helpful: true).count,
      unhelpful_votes_count: review_votes.where(is_helpful: false).count
    )
  end
end
