class Profile < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :gender, inclusion: { in: %w[male female other prefer_not_to_say] }, allow_blank: true
  validates :bio, length: { maximum: 1000 }
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp }, allow_blank: true
  validates :occupation, :company, length: { maximum: 100 }

  # カスタムメソッド
  def age
    return nil unless birth_date
    now = Time.current.to_date
    now.year - birth_date.year - (now.month > birth_date.month || (now.month == birth_date.month && now.day >= birth_date.day) ? 0 : 1)
  end
end
