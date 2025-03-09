class UserPreference < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :language, inclusion: { in: %w[en ja fr es de zh ru] }, allow_blank: true
  validates :currency, inclusion: { in: %w[USD EUR JPY GBP CAD AUD CNY] }, allow_blank: true
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, allow_blank: true

  # カスタムメソッド
  def toggle_email_notifications!
    update(email_notifications: !email_notifications)
  end

  def toggle_sms_notifications!
    update(sms_notifications: !sms_notifications)
  end

  def toggle_push_notifications!
    update(push_notifications: !push_notifications)
  end

  def toggle_two_factor_auth!
    update(two_factor_auth: !two_factor_auth)
  end
end
