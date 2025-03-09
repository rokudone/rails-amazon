class EventLog < ApplicationRecord
  # 関連付け
  belongs_to :user, optional: true
  belongs_to :loggable, polymorphic: true, optional: true

  # バリデーション
  validates :event_name, presence: true

  # スコープ
  scope :recent, -> { order(created_at: :desc) }
  scope :by_event_name, ->(name) { where(event_name: name) }
  scope :by_event_type, ->(type) { where(event_type: type) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_ip, ->(ip) { where(ip_address: ip) }
  scope :by_session, ->(session_id) { where(session_id: session_id) }
  scope :by_request_path, ->(path) { where(request_path: path) }
  scope :by_response_status, ->(status) { where(response_status: status) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :successful, -> { where(is_success: true) }
  scope :failed, -> { where(is_success: false) }
  scope :by_source, ->(source) { where(source: source) }
  scope :by_browser, ->(browser) { where(browser: browser) }
  scope :by_device_type, ->(device_type) { where(device_type: device_type) }
  scope :by_os, ->(os) { where(operating_system: os) }
  scope :system_logs, -> { where(event_type: 'system') }
  scope :user_logs, -> { where(event_type: 'user') }
  scope :error_logs, -> { where(event_type: 'error') }
  scope :security_logs, -> { where(event_type: 'security') }
  scope :info, -> { where(severity: 'info') }
  scope :warning, -> { where(severity: 'warning') }
  scope :error, -> { where(severity: 'error') }
  scope :critical, -> { where(severity: 'critical') }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  # クラスメソッド
  def self.log(event_name, options = {})
    create(
      event_name: event_name,
      event_type: options[:event_type] || 'system',
      user: options[:user],
      ip_address: options[:ip_address],
      user_agent: options[:user_agent],
      session_id: options[:session_id],
      request_method: options[:request_method],
      request_path: options[:request_path],
      request_params: options[:request_params].to_json,
      response_status: options[:response_status],
      details: options[:details],
      loggable: options[:loggable],
      severity: options[:severity] || 'info',
      duration: options[:duration],
      is_success: options[:is_success].nil? ? true : options[:is_success],
      source: options[:source] || 'web',
      browser: options[:browser],
      device_type: options[:device_type],
      operating_system: options[:operating_system]
    )
  end

  def self.log_error(event_name, error, options = {})
    error_details = {
      error_class: error.class.name,
      error_message: error.message,
      backtrace: error.backtrace&.first(10)
    }

    log(
      event_name,
      options.merge(
        event_type: 'error',
        severity: options[:severity] || 'error',
        details: error_details.to_json,
        is_success: false
      )
    )
  end

  def self.log_user_action(user, action, options = {})
    log(
      action,
      options.merge(
        event_type: 'user',
        user: user,
        severity: 'info',
        source: options[:source] || 'web'
      )
    )
  end

  def self.log_security_event(event_name, options = {})
    log(
      event_name,
      options.merge(
        event_type: 'security',
        severity: options[:severity] || 'warning'
      )
    )
  end

  def self.log_api_request(path, method, params, response_status, duration, options = {})
    log(
      "api.#{method.downcase}.#{path.gsub('/', '.')}",
      options.merge(
        event_type: 'api',
        request_method: method,
        request_path: path,
        request_params: params,
        response_status: response_status,
        duration: duration,
        is_success: response_status.to_i < 400,
        source: 'api'
      )
    )
  end

  def self.event_counts_by_day(days = 30)
    where('created_at > ?', days.days.ago)
      .group("DATE(created_at)")
      .order("DATE(created_at)")
      .count
  end

  def self.event_counts_by_type(days = 30)
    where('created_at > ?', days.days.ago)
      .group(:event_type)
      .order('COUNT(*) DESC')
      .count
  end

  def self.error_counts_by_day(days = 30)
    where('created_at > ? AND event_type = ?', days.days.ago, 'error')
      .group("DATE(created_at)")
      .order("DATE(created_at)")
      .count
  end

  def self.average_response_time(days = 30)
    where('created_at > ? AND duration IS NOT NULL', days.days.ago)
      .average(:duration)
      .to_f
      .round(2)
  end

  # カスタムメソッド
  def event_type_name
    case event_type
    when 'system'
      'システム'
    when 'user'
      'ユーザー'
    when 'error'
      'エラー'
    when 'security'
      'セキュリティ'
    when 'api'
      'API'
    else
      event_type.humanize
    end
  end

  def severity_name
    case severity
    when 'info'
      '情報'
    when 'warning'
      '警告'
    when 'error'
      'エラー'
    when 'critical'
      '重大'
    else
      severity.humanize
    end
  end

  def source_name
    case source
    when 'web'
      'ウェブ'
    when 'api'
      'API'
    when 'admin'
      '管理画面'
    when 'background_job'
      'バックグラウンドジョブ'
    when 'console'
      'コンソール'
    else
      source.humanize
    end
  end

  def formatted_duration
    return nil if duration.nil?

    if duration < 1
      "#{(duration * 1000).round}ms"
    else
      "#{duration.round(2)}s"
    end
  end

  def parsed_details
    return {} if details.blank?

    begin
      JSON.parse(details)
    rescue JSON::ParserError
      { raw: details }
    end
  end

  def parsed_request_params
    return {} if request_params.blank?

    begin
      JSON.parse(request_params)
    rescue JSON::ParserError
      { raw: request_params }
    end
  end

  def user_info
    return nil if user.nil?
    "#{user.id} (#{user.email})"
  end

  def device_info
    [device_type, browser, operating_system].compact.join(' / ')
  end

  def request_info
    "#{request_method} #{request_path}"
  end

  def anonymize!
    update(
      ip_address: nil,
      session_id: nil,
      user_agent: nil,
      request_params: nil
    )
  end
end
