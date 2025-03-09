class SellerDocument < ApplicationRecord
  # 関連付け
  belongs_to :seller
  belongs_to :verified_by, class_name: 'User', optional: true

  # バリデーション
  validates :document_type, presence: true
  validates :file_url, presence: true
  validates :content_type, inclusion: { in: ['application/pdf', 'image/jpeg', 'image/png', 'application/msword',
                                            'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
                                       message: "は対応していないファイル形式です" },
                          allow_blank: true
  validates :file_size, numericality: { less_than_or_equal_to: 10.megabytes,
                                       message: "は10MB以下にしてください" },
                       allow_blank: true
  validate :expiry_date_in_future, if: -> { expiry_date.present? }

  # コールバック
  before_save :set_verified_at, if: -> { is_verified_changed? && is_verified? }
  after_create :notify_admin_of_new_document
  after_save :update_seller_verification_status, if: -> { saved_change_to_is_verified? }

  # スコープ
  scope :verified, -> { where(is_verified: true) }
  scope :unverified, -> { where(is_verified: false) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_document_type, ->(type) { where(document_type: type) }
  scope :required, -> { where(is_required: true) }
  scope :optional, -> { where(is_required: false) }
  scope :expired, -> { where('expiry_date < ?', Date.current) }
  scope :expiring_soon, -> { where('expiry_date > ? AND expiry_date < ?', Date.current, 30.days.from_now) }
  scope :valid, -> { where('expiry_date IS NULL OR expiry_date > ?', Date.current) }
  scope :recent, -> { order(created_at: :desc) }

  # カスタムメソッド
  def verify!(verifier)
    update(
      is_verified: true,
      verified_by: verifier,
      verified_at: Time.current,
      status: 'approved'
    )
  end

  def reject!(reason = nil)
    update(
      is_verified: false,
      status: 'rejected',
      verification_notes: reason
    )
  end

  def pending!
    update(status: 'pending')
  end

  def expired?
    expiry_date.present? && expiry_date < Date.current
  end

  def expiring_soon?
    expiry_date.present? && expiry_date > Date.current && expiry_date < 30.days.from_now
  end

  def valid?
    expiry_date.nil? || expiry_date > Date.current
  end

  def days_until_expiry
    return nil if expiry_date.nil?
    return 0 if expired?
    (expiry_date - Date.current).to_i
  end

  def file_extension
    File.extname(file_name || file_url.split('/').last).downcase
  end

  def file_icon
    case file_extension
    when '.pdf'
      'pdf-icon'
    when '.doc', '.docx'
      'word-icon'
    when '.jpg', '.jpeg', '.png', '.gif'
      'image-icon'
    else
      'file-icon'
    end
  end

  def human_readable_file_size
    return nil if file_size.nil?

    if file_size < 1024
      "#{file_size} B"
    elsif file_size < 1024 * 1024
      "#{(file_size / 1024.0).round(1)} KB"
    else
      "#{(file_size / (1024.0 * 1024.0)).round(1)} MB"
    end
  end

  def document_type_name
    case document_type
    when 'business_license'
      '事業許可証'
    when 'tax_certificate'
      '課税証明書'
    when 'identity_proof'
      '本人確認書類'
    when 'bank_statement'
      '銀行取引明細書'
    when 'address_proof'
      '住所証明書'
    else
      document_type.humanize
    end
  end

  private

  def expiry_date_in_future
    if expiry_date.present? && expiry_date < Date.current
      errors.add(:expiry_date, "は現在より後の日付にしてください")
    end
  end

  def set_verified_at
    self.verified_at = Time.current
  end

  def notify_admin_of_new_document
    # 管理者に通知を送る処理（実装は別途必要）
  end

  def update_seller_verification_status
    # 必要な書類がすべて検証されたら販売者の検証ステータスを更新
    if is_verified? && seller.present?
      required_docs = SellerDocument.where(seller: seller, is_required: true)
      verified_docs = required_docs.where(is_verified: true)

      if required_docs.count == verified_docs.count
        seller.verify!
      end
    end
  end
end
