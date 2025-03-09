class SearchHistory < ApplicationRecord
  # 関連付け
  belongs_to :user, optional: true
  belongs_to :product_clicked, class_name: 'Product', optional: true

  # バリデーション
  validates :query, presence: true

  # スコープ
  scope :recent, -> { order(created_at: :desc) }
  scope :with_results, -> { where('results_count > 0') }
  scope :without_results, -> { where('results_count = 0 OR results_count IS NULL') }
  scope :clicked, -> { where(has_clicked_result: true) }
  scope :not_clicked, -> { where(has_clicked_result: false) }
  scope :by_device_type, ->(device_type) { where(device_type: device_type) }
  scope :by_browser, ->(browser) { where(browser: browser) }
  scope :by_category_path, ->(path) { where(category_path: path) }
  scope :voice_searches, -> { where(is_voice_search: true) }
  scope :image_searches, -> { where(is_image_search: true) }
  scope :autocomplete_searches, -> { where(is_autocomplete: true) }
  scope :by_session, ->(session_id) { where(session_id: session_id) }
  scope :by_ip, ->(ip) { where(ip_address: ip) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  # クラスメソッド
  def self.popular_queries(limit = 10, days = 30)
    where('created_at > ?', days.days.ago)
      .group(:query)
      .order('COUNT(*) DESC')
      .limit(limit)
      .count
  end

  def self.zero_result_queries(limit = 10, days = 30)
    where('created_at > ?', days.days.ago)
      .without_results
      .group(:query)
      .order('COUNT(*) DESC')
      .limit(limit)
      .count
  end

  def self.popular_categories(limit = 10, days = 30)
    where('created_at > ? AND category_path IS NOT NULL', days.days.ago)
      .group(:category_path)
      .order('COUNT(*) DESC')
      .limit(limit)
      .count
  end

  def self.average_search_duration(days = 30)
    where('created_at > ? AND search_duration IS NOT NULL', days.days.ago)
      .average(:search_duration)
      .to_f
      .round(2)
  end

  def self.click_through_rate(days = 30)
    total = where('created_at > ?', days.days.ago).count
    clicked = where('created_at > ? AND has_clicked_result = true', days.days.ago).count

    return 0 if total.zero?
    (clicked.to_f / total * 100).round(2)
  end

  def self.device_distribution(days = 30)
    where('created_at > ? AND device_type IS NOT NULL', days.days.ago)
      .group(:device_type)
      .order('COUNT(*) DESC')
      .count
  end

  def self.search_trends_by_hour(days = 30)
    where('created_at > ?', days.days.ago)
      .group("EXTRACT(HOUR FROM created_at)")
      .order("EXTRACT(HOUR FROM created_at)")
      .count
  end

  def self.search_trends_by_day_of_week(days = 30)
    where('created_at > ?', days.days.ago)
      .group("EXTRACT(DOW FROM created_at)")
      .order("EXTRACT(DOW FROM created_at)")
      .count
  end

  # カスタムメソッド
  def record_click!(product, position)
    update(
      has_clicked_result: true,
      product_clicked: product,
      position_clicked: position
    )
  end

  def successful?
    results_count.to_i > 0
  end

  def clicked?
    has_clicked_result?
  end

  def voice_search?
    is_voice_search?
  end

  def image_search?
    is_image_search?
  end

  def autocomplete?
    is_autocomplete?
  end

  def search_type
    if voice_search?
      '音声検索'
    elsif image_search?
      '画像検索'
    elsif autocomplete?
      'オートコンプリート'
    else
      'テキスト検索'
    end
  end

  def formatted_filters
    return [] if filters.blank?

    begin
      JSON.parse(filters)
    rescue JSON::ParserError
      filters.split(',').map(&:strip)
    end
  end

  def formatted_duration
    return nil if search_duration.nil?

    if search_duration < 1
      "#{(search_duration * 1000).round}ms"
    else
      "#{search_duration.round(2)}s"
    end
  end

  def device_info
    [device_type, browser].compact.join(' / ')
  end

  def anonymize!
    update(
      ip_address: nil,
      session_id: nil,
      browser: nil
    )
  end
end
