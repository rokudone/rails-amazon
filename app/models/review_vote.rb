class ReviewVote < ApplicationRecord
  # 関連付け
  belongs_to :user
  belongs_to :review
  has_one :product, through: :review

  # バリデーション
  validates :user_id, uniqueness: { scope: :review_id, message: "すでにこのレビューに投票しています" }
  validates :is_helpful, inclusion: { in: [true, false] }

  # コールバック
  after_save :update_review_vote_counts
  after_destroy :update_review_vote_counts

  # スコープ
  scope :helpful, -> { where(is_helpful: true) }
  scope :unhelpful, -> { where(is_helpful: false) }
  scope :reported, -> { where(is_reported: true) }
  scope :by_reason, ->(reason) { where("reason LIKE ?", "%#{reason}%") }
  scope :recent, -> { order(created_at: :desc) }

  # カスタムメソッド
  def mark_helpful!
    update(is_helpful: true)
  end

  def mark_unhelpful!
    update(is_helpful: false)
  end

  def report!(reason = nil)
    update(is_reported: true, report_reason: reason)
  end

  def unreport!
    update(is_reported: false, report_reason: nil)
  end

  # クラスメソッド
  def self.vote_counts_for_review(review_id)
    where(review_id: review_id).group(:is_helpful).count
  end

  def self.reported_votes_count
    where(is_reported: true).count
  end

  private

  def update_review_vote_counts
    if review.present?
      helpful_count = review.review_votes.where(is_helpful: true).count
      unhelpful_count = review.review_votes.where(is_helpful: false).count

      review.update_columns(
        helpful_votes_count: helpful_count,
        unhelpful_votes_count: unhelpful_count
      )
    end
  end
end
