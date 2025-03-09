class Question < ApplicationRecord
  # 関連付け
  belongs_to :user
  belongs_to :product
  has_many :answers, dependent: :destroy

  # バリデーション
  validates :content, presence: true, length: { minimum: 10, maximum: 1000 }

  # コールバック
  before_save :set_approved_at, if: -> { is_approved_changed? && is_approved? }
  after_save :update_answers_count
  after_save :update_is_answered

  # スコープ
  scope :approved, -> { where(is_approved: true) }
  scope :pending, -> { where(is_approved: false, status: 'pending') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :featured, -> { where(is_featured: true) }
  scope :answered, -> { where(is_answered: true) }
  scope :unanswered, -> { where(is_answered: false) }
  scope :recent, -> { order(created_at: :desc) }
  scope :popular, -> { order(votes_count: :desc) }
  scope :by_product_category, ->(category_id) { joins(:product).where(products: { category_id: category_id }) }

  # カスタムメソッド
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

  def upvote!(user)
    # 実装は別途必要（質問投票テーブルが必要）
    increment!(:votes_count)
  end

  def best_answer
    answers.find_by(is_best_answer: true)
  end

  def seller_answers
    answers.where(is_seller_answer: true)
  end

  def amazon_answers
    answers.where(is_amazon_answer: true)
  end

  def approved_answers
    answers.approved
  end

  private

  def set_approved_at
    self.approved_at = Time.current
  end

  def update_answers_count
    update_column(:answers_count, answers.approved.count) if persisted?
  end

  def update_is_answered
    update_column(:is_answered, answers_count > 0) if persisted?
  end
end
