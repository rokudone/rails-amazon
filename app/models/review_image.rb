class ReviewImage < ApplicationRecord
  # 関連付け
  belongs_to :review
  has_one :product, through: :review
  has_one :user, through: :review

  # バリデーション
  validates :image_url, presence: true
  validates :content_type, inclusion: { in: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
                                       message: "は対応していないファイル形式です" },
                          allow_blank: true
  validates :file_size, numericality: { less_than_or_equal_to: 10.megabytes,
                                       message: "は10MB以下にしてください" },
                       allow_blank: true

  # コールバック
  before_save :set_approved_at, if: -> { is_approved_changed? && is_approved? }
  after_create :process_image
  after_destroy :cleanup_image

  # スコープ
  scope :approved, -> { where(is_approved: true) }
  scope :pending, -> { where(is_approved: false, status: 'pending') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :ordered, -> { order(position: :asc) }
  scope :by_content_type, ->(type) { where(content_type: type) }

  # カスタムメソッド
  def approve!
    update(is_approved: true, status: 'approved', approved_at: Time.current)
  end

  def reject!(reason = nil)
    update(is_approved: false, status: 'rejected', rejection_reason: reason)
  end

  def thumbnail_url
    # サムネイル生成ロジック（実装は別途必要）
    "#{image_url.gsub(/(\.\w+)$/, '_thumb\1')}"
  end

  def medium_url
    # 中サイズ画像生成ロジック（実装は別途必要）
    "#{image_url.gsub(/(\.\w+)$/, '_medium\1')}"
  end

  def large_url
    # 大サイズ画像生成ロジック（実装は別途必要）
    "#{image_url.gsub(/(\.\w+)$/, '_large\1')}"
  end

  def set_as_primary!
    ReviewImage.transaction do
      review.review_images.update_all(position: 1)
      update(position: 0)
    end
  end

  private

  def set_approved_at
    self.approved_at = Time.current
  end

  def process_image
    # 画像処理ロジック（実装は別途必要）
    # - サムネイル生成
    # - リサイズ
    # - メタデータ抽出
    # - 不適切コンテンツチェック
  end

  def cleanup_image
    # 画像ファイル削除ロジック（実装は別途必要）
  end
end
