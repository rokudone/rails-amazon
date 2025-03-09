class UserActivity < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :activity_type, presence: true
  validates :activity_type, inclusion: { in: %w[login logout search view purchase review wishlist cart follow share] }

  # コールバック
  before_create :set_activity_time

  # スコープ
  scope :recent, -> { order(activity_time: :desc) }
  scope :by_type, ->(type) { where(activity_type: type) }
  scope :today, -> { where('activity_time >= ?', Time.current.beginning_of_day) }
  scope :yesterday, -> { where(activity_time: Time.current.yesterday.beginning_of_day..Time.current.yesterday.end_of_day) }
  scope :this_week, -> { where('activity_time >= ?', Time.current.beginning_of_week) }
  scope :this_month, -> { where('activity_time >= ?', Time.current.beginning_of_month) }
  scope :for_resource, ->(type, id = nil) {
    if id.nil?
      where(resource_type: type)
    else
      where(resource_type: type, resource_id: id)
    end
  }

  # クラスメソッド
  def self.log(user, activity_type, options = {})
    create({
      user: user,
      activity_type: activity_type,
      action: options[:action],
      ip_address: options[:ip_address],
      user_agent: options[:user_agent],
      resource_type: options[:resource_type],
      resource_id: options[:resource_id],
      details: options[:details],
      activity_time: Time.current
    })
  end

  private

  def set_activity_time
    self.activity_time ||= Time.current
  end
end
