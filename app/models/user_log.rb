class UserLog < ApplicationRecord
  belongs_to :user

  # スコープ
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_ip, ->(ip) { where(ip_address: ip) }
  scope :today, -> { where('created_at >= ?', Time.current.beginning_of_day) }
  scope :this_week, -> { where('created_at >= ?', Time.current.beginning_of_week) }
  scope :this_month, -> { where('created_at >= ?', Time.current.beginning_of_month) }
end
