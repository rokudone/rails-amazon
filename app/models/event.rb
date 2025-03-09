class Event < ApplicationRecord
  # 関連付け
  belongs_to :campaign, optional: true
  belongs_to :promotion, optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :event_logs, as: :loggable, dependent: :nullify

  # バリデーション
  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :event_type, presence: true
  validate :end_date_after_start_date

  # コールバック
  before_save :set_status

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :current, -> { where('start_date <= ? AND end_date >= ?', Time.current, Time.current) }
  scope :upcoming, -> { where('start_date > ?', Time.current) }
  scope :past, -> { where('end_date < ?', Time.current) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :featured, -> { where(is_featured: true) }
  scope :by_priority, -> { order(priority: :desc) }
  scope :sales, -> { where(event_type: 'sale') }
  scope :promotions, -> { where(event_type: 'promotion') }
  scope :holidays, -> { where(event_type: 'holiday') }
  scope :product_launches, -> { where(event_type: 'product_launch') }
  scope :recurring, -> { where(is_recurring: true) }
  scope :non_recurring, -> { where(is_recurring: false) }

  # カスタムメソッド
  def active?
    is_active && current?
  end

  def current?
    start_date <= Time.current && end_date >= Time.current
  end

  def upcoming?
    start_date > Time.current
  end

  def past?
    end_date < Time.current
  end

  def activate!
    update(is_active: true)
  end

  def deactivate!
    update(is_active: false)
  end

  def feature!
    update(is_featured: true)
  end

  def unfeature!
    update(is_featured: false)
  end

  def days_until_start
    return 0 if start_date <= Date.current
    (start_date.to_date - Date.current).to_i
  end

  def days_until_end
    return 0 if end_date <= Date.current
    (end_date.to_date - Date.current).to_i
  end

  def duration_in_days
    (end_date.to_date - start_date.to_date).to_i + 1
  end

  def progress_percentage
    return 0 if upcoming?
    return 100 if past?

    total_duration = (end_date - start_date).to_i
    elapsed = (Time.current - start_date).to_i

    [(elapsed.to_f / total_duration * 100).round, 100].min
  end

  def event_type_name
    case event_type
    when 'sale'
      'セール'
    when 'promotion'
      'プロモーション'
    when 'holiday'
      '祝日'
    when 'product_launch'
      '新商品発売'
    when 'clearance'
      'クリアランス'
    when 'flash_sale'
      'タイムセール'
    when 'seasonal'
      'シーズンイベント'
    else
      event_type.humanize
    end
  end

  def status_name
    case status
    when 'scheduled'
      '予定'
    when 'active'
      '実施中'
    when 'completed'
      '終了'
    when 'cancelled'
      'キャンセル'
    else
      status.humanize
    end
  end

  def formatted_date_range
    if start_date.to_date == end_date.to_date
      start_date.strftime('%Y年%m月%d日')
    else
      "#{start_date.strftime('%Y年%m月%d日')} 〜 #{end_date.strftime('%Y年%m月%d日')}"
    end
  end

  def next_occurrence
    return nil unless is_recurring && recurrence_pattern.present?

    # 繰り返しパターンに基づいて次回の開催日を計算
    # 例: 'weekly', 'monthly', 'yearly'など
    case recurrence_pattern
    when 'daily'
      Date.current + 1.day
    when 'weekly'
      Date.current + 1.week
    when 'biweekly'
      Date.current + 2.weeks
    when 'monthly'
      Date.current + 1.month
    when 'quarterly'
      Date.current + 3.months
    when 'yearly'
      Date.current + 1.year
    else
      nil
    end
  end

  def create_next_occurrence!
    return nil unless is_recurring && recurrence_pattern.present?

    next_start = next_occurrence
    return nil if next_start.nil?

    duration = duration_in_days - 1
    next_end = next_start + duration.days

    Event.create(
      name: name,
      description: description,
      start_date: next_start,
      end_date: next_end,
      is_active: true,
      event_type: event_type,
      banner_image_url: banner_image_url,
      landing_page_url: landing_page_url,
      is_featured: is_featured,
      priority: priority,
      campaign: campaign,
      promotion: promotion,
      created_by: created_by,
      is_recurring: is_recurring,
      recurrence_pattern: recurrence_pattern,
      timezone: timezone
    )
  end

  def metadata_hash
    return {} if metadata.blank?

    begin
      JSON.parse(metadata)
    rescue JSON::ParserError
      {}
    end
  end

  def log_event(action, details = {})
    event_logs.create(
      event_name: "#{event_type}.#{action}",
      event_type: 'event',
      details: details.to_json
    )
  end

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "は開始日より後の日付にしてください")
    end
  end

  def set_status
    self.status = if Time.current < start_date
                    'scheduled'
                  elsif Time.current > end_date
                    'completed'
                  elsif is_active
                    'active'
                  else
                    'cancelled'
                  end
  end
end
