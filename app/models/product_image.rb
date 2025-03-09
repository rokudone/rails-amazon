class ProductImage < ApplicationRecord
  # 関連付け
  belongs_to :product
  belongs_to :product_variant, optional: true

  # バリデーション
  validates :image_url, presence: true, length: { maximum: 2048 }
  validates :alt_text, length: { maximum: 255 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :only_one_primary_per_product

  # スコープ
  scope :ordered, -> { order(position: :asc) }
  scope :primary, -> { where(is_primary: true) }
  scope :for_variant, ->(variant_id) { where(product_variant_id: variant_id) }

  # コールバック
  before_save :ensure_position
  after_save :update_other_primary_images, if: -> { is_primary? && is_primary_changed? }

  # カスタムメソッド
  def make_primary!
    update(is_primary: true)
  end

  def thumbnail_url
    # 仮定: サムネイル生成ロジックが後で実装される
    image_url
  end

  def medium_url
    # 仮定: 中サイズ画像生成ロジックが後で実装される
    image_url
  end

  def large_url
    # 仮定: 大サイズ画像生成ロジックが後で実装される
    image_url
  end

  private

  def ensure_position
    self.position ||= 0
  end

  def only_one_primary_per_product
    return unless is_primary?
    return unless is_primary_changed? || new_record?

    if product && ProductImage.where(product_id: product_id, is_primary: true)
                              .where.not(id: id).exists?
      errors.add(:is_primary, "は既に他の画像で設定されています")
    end
  end

  def update_other_primary_images
    ProductImage.where(product_id: product_id, is_primary: true)
                .where.not(id: id)
                .update_all(is_primary: false)
  end
end
