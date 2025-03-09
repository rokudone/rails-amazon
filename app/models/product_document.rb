class ProductDocument < ApplicationRecord
  # 関連付け
  belongs_to :product

  # バリデーション
  validates :document_url, presence: true, length: { maximum: 2048 }
  validates :title, length: { maximum: 255 }
  validates :document_type, length: { maximum: 50 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # スコープ
  scope :ordered, -> { order(position: :asc) }
  scope :by_type, ->(type) { where(document_type: type) }

  # コールバック
  before_save :ensure_position
  before_save :ensure_title
  before_save :detect_document_type

  # カスタムメソッド
  def file_extension
    File.extname(document_url).gsub('.', '').downcase if document_url.present?
  end

  def file_size
    # 仮定: ファイルサイズ取得ロジックが後で実装される
    nil
  end

  def display_title
    title.presence || File.basename(document_url, '.*').titleize
  end

  def icon_class
    case file_extension
    when 'pdf'
      'fa-file-pdf'
    when 'doc', 'docx'
      'fa-file-word'
    when 'xls', 'xlsx'
      'fa-file-excel'
    when 'ppt', 'pptx'
      'fa-file-powerpoint'
    when 'txt'
      'fa-file-alt'
    when 'zip', 'rar', '7z'
      'fa-file-archive'
    else
      'fa-file'
    end
  end

  private

  def ensure_position
    self.position ||= 0
  end

  def ensure_title
    return if title.present?
    self.title = File.basename(document_url, '.*').titleize if document_url.present?
  end

  def detect_document_type
    return if document_type.present?

    self.document_type = case file_extension
                         when 'pdf'
                           'PDF'
                         when 'doc', 'docx'
                           'Word'
                         when 'xls', 'xlsx'
                           'Excel'
                         when 'ppt', 'pptx'
                           'PowerPoint'
                         when 'txt'
                           'Text'
                         when 'zip', 'rar', '7z'
                           'Archive'
                         else
                           'Other'
                         end
  end
end
