class Answer < ApplicationRecord
  # 関連付け
  belongs_to :user
  belongs_to :question
  has_one :product, through: :question

  # バリデーション
  validates :content, presence: true, length: { minimum: 10, maximum: 2000 }

  # コールバック
  before_save :set_approved_at, if: -> { is_approved_changed? && is_approved? }
  after_save :update_question_status, if: -> { saved_change_to_is_approved? || saved_change_to_is_best_answer? }
  after_create :notify_question_owner
  after_save :clear_other_best_answers, if: -> { saved_change_to_is_best_answer? && is_best_answer? }

  # スコープ
  scope :approved, -> { where(is_approved: true) }
  scope :pending, -> { where(is_approved: false, status: 'pending') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :seller_answers, -> { where(is_seller_answer: true) }
  scope :amazon_answers, -> { where(is_amazon_answer: true) }
  scope :best_answers, -> { where(is_best_answer: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :helpful, -> { order(helpful_votes_count: :desc) }

  # カスタムメソッド
  def approve!
    update(is_approved: true, status: 'approved', approved_at: Time.current)
  end

  def reject!(reason = nil)
    update(is_approved: false, status: 'rejected', rejection_reason: reason)
  end

  def mark_as_best!
    update(is_best_answer: true)
  end

  def unmark_as_best!
    update(is_best_answer: false)
  end

  def mark_as_seller_answer!
    update(is_seller_answer: true)
  end

  def mark_as_amazon_answer!
    update(is_amazon_answer: true)
  end

  def vote_helpful!(user)
    # 実装は別途必要（回答投票テーブルが必要）
    increment!(:helpful_votes_count)
  end

  def vote_unhelpful!(user)
    # 実装は別途必要（回答投票テーブルが必要）
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

  def update_question_status
    question.update_answers_count if question.present?
  end

  def notify_question_owner
    # 質問者に通知を送る処理（実装は別途必要）
  end

  def clear_other_best_answers
    if is_best_answer?
      question.answers.where.not(id: id).update_all(is_best_answer: false)
    end
  end
end
