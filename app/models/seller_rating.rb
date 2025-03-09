class SellerRating < ApplicationRecord
  # 関連付け
  belongs_to :user
  belongs_to :seller
  belongs_to :order, optional: true

  # バリデーション
  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :user_id, uniqueness: { scope: [:seller_id, :dimension], message: "すでにこの販売者の評価を投稿しています" }
  validates :dimension, presence: true, if: -> { !dimension.nil? }

  # コールバック
  before_save :set_approved_at, if: -> { is_approved_changed? && is_approved? }
  after_save :update_seller_rating, if: -> { saved_change_to_rating? || saved_change_to_is_approved? }
  after_destroy :update_seller_rating

  # スコープ
  scope :approved, -> { where(is_approved: true) }
  scope :pending, -> { where(is_approved: false, status: 'pending') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :featured, -> { where(is_featured: true) }
  scope :verified_purchase, -> { where(is_verified_purchase: true) }
  scope :anonymous, -> { where(is_anonymous: true) }
  scope :by_dimension, ->(dimension) { where(dimension: dimension) }
  scope :by_rating, ->(rating) { where(rating: rating) }
  scope :by_rating_range, ->(min, max) { where('rating >= ? AND rating <= ?', min, max) }
  scope :recent, -> { order(created_at: :desc) }
  scope :helpful, -> { order(helpful_votes_count: :desc) }

  # クラスメソッド
  def self.average_by_dimension(seller_id, dimension)
    where(seller_id: seller_id, dimension: dimension, is_approved: true).average(:rating).to_f.round(1)
  end

  def self.distribution_by_dimension(seller_id, dimension)
    where(seller_id: seller_id, dimension: dimension, is_approved: true).group(:rating).count
  end

  def self.dimensions_for_seller(seller_id)
    where(seller_id: seller_id, is_approved: true).pluck(:dimension).uniq
  end

  # カスタムメソッド
  def approve!
    update(is_approved: true, status: 'approved', approved_at: Time.current)
  end

  def reject!(reason = nil)
    update(is_approved: false, status: 'rejected', rejection_reason: reason)
  end

  def feature!
    update(is_featured: true)
  end

  def unfeature!
    update(is_featured: false)
  end

  def anonymous!
    update(is_anonymous: true)
  end

  def identified!
    update(is_anonymous: false)
  end

  def vote_helpful!(user)
    # 実装は別途必要（評価投票テーブルが必要）
    increment!(:helpful_votes_count)
  end

  def vote_unhelpful!(user)
    # 実装は別途必要（評価投票テーブルが必要）
    increment!(:unhelpful_votes_count)
  end

  def helpful_percentage
    return 0 if total_votes.zero?
    (helpful_votes_count.to_f / total_votes * 100).round(1)
  end

  def total_votes
    helpful_votes_count + unhelpful_votes_count
  end

  private

  def set_approved_at
    self.approved_at = Time.current
  end

  def update_seller_rating
    seller.update_ratings_stats if seller.present?
  end
end
