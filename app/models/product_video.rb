class ProductVideo < ApplicationRecord
  # 関連付け
  belongs_to :product

  # バリデーション
  validates :video_url, presence: true, length: { maximum: 2048 }
  validates :thumbnail_url, length: { maximum: 2048 }
  validates :title, length: { maximum: 255 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # スコープ
  scope :ordered, -> { order(position: :asc) }

  # コールバック
  before_save :ensure_position
  before_save :ensure_thumbnail

  # カスタムメソッド
  def video_type
    if video_url.include?('youtube.com') || video_url.include?('youtu.be')
      'youtube'
    elsif video_url.include?('vimeo.com')
      'vimeo'
    else
      'other'
    end
  end

  def video_id
    case video_type
    when 'youtube'
      if video_url.include?('youtube.com/watch?v=')
        video_url.split('v=').last.split('&').first
      elsif video_url.include?('youtu.be/')
        video_url.split('youtu.be/').last.split('?').first
      end
    when 'vimeo'
      video_url.split('vimeo.com/').last.split('?').first
    else
      nil
    end
  end

  def embed_url
    case video_type
    when 'youtube'
      "https://www.youtube.com/embed/#{video_id}"
    when 'vimeo'
      "https://player.vimeo.com/video/#{video_id}"
    else
      video_url
    end
  end

  def display_title
    title.presence || product.name
  end

  private

  def ensure_position
    self.position ||= 0
  end

  def ensure_thumbnail
    return if thumbnail_url.present?

    # 仮定: サムネイル生成ロジックが後で実装される
    # YouTubeの場合はサムネイルURLを自動生成
    if video_type == 'youtube' && video_id.present?
      self.thumbnail_url = "https://img.youtube.com/vi/#{video_id}/hqdefault.jpg"
    end
  end
end
