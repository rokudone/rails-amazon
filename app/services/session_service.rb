class SessionService
  attr_reader :session, :user, :token

  def initialize(user = nil, token = nil, request = nil)
    @user = user
    @token = token
    @request = request
  end

  # セッション作成
  def create
    return false unless @user && @request

    # トークンの生成
    token_service = TokenService.new(@user)
    @token = token_service.generate

    # セッションの作成
    @session = @user.user_sessions.create(
      token: @token,
      ip_address: @request.remote_ip,
      user_agent: @request.user_agent,
      device_type: detect_device_type(@request.user_agent),
      expired_at: token_service.expires_at
    )

    # デバイス情報の記録
    record_device

    # ユーザーアクティビティの記録
    record_activity('login')

    true
  end

  # セッション検証
  def verify
    return false unless @token

    # トークンの検証
    token_service = TokenService.new(nil, @token)
    return false unless token_service.verify

    # ユーザーの取得
    @user = User.find_by(id: token_service.payload['user_id'])
    return false unless @user

    # セッションの取得
    @session = @user.user_sessions.find_by(token: @token)
    return false unless @session

    # セッションが有効期限内かどうか確認
    if @session.expired_at && @session.expired_at <= Time.current
      @error = 'Session has expired'
      return false
    end

    # ユーザーがアクティブかどうか確認
    unless @user.active?
      @error = 'User is inactive'
      return false
    end

    # ユーザーアクティビティの記録
    record_activity('session_verified') if @request

    true
  end

  # セッション無効化
  def invalidate
    return false unless verify

    # セッションの無効化
    @session.update(expired_at: Time.current)

    # トークンの無効化
    token_service = TokenService.new(nil, @token)
    token_service.revoke

    # ユーザーアクティビティの記録
    record_activity('logout') if @request

    true
  end

  # 全セッション無効化
  def invalidate_all
    return false unless @user

    # ユーザーの全セッションを無効化
    @user.user_sessions.update_all(expired_at: Time.current)

    # ユーザーアクティビティの記録
    record_activity('logout_all') if @request

    true
  end

  # エラーメッセージの取得
  def error_message
    @error
  end

  private

  # デバイスタイプの検出
  def detect_device_type(user_agent)
    return 'unknown' unless user_agent

    user_agent = user_agent.downcase

    if user_agent.match?(/mobile|android|iphone|ipad|ipod/)
      'mobile'
    elsif user_agent.match?(/tablet/)
      'tablet'
    else
      'desktop'
    end
  end

  # デバイス情報の記録
  def record_device
    return unless @user && @request

    # デバイスの特定
    device_identifier = generate_device_identifier

    # 既存のデバイスを検索
    device = @user.user_devices.find_by(device_identifier: device_identifier)

    if device
      # 既存のデバイスを更新
      device.update(
        last_used_at: Time.current,
        user_agent: @request.user_agent,
        ip_address: @request.remote_ip
      )
    else
      # 新しいデバイスを作成
      @user.user_devices.create(
        device_identifier: device_identifier,
        device_type: detect_device_type(@request.user_agent),
        device_name: detect_device_name(@request.user_agent),
        user_agent: @request.user_agent,
        ip_address: @request.remote_ip,
        last_used_at: Time.current
      )
    end
  end

  # デバイス識別子の生成
  def generate_device_identifier
    user_agent = @request.user_agent || ''
    ip_address = @request.remote_ip || ''

    # ユーザーエージェントとIPアドレスからハッシュを生成
    Digest::SHA256.hexdigest("#{user_agent}|#{ip_address}|#{@user.id}")
  end

  # デバイス名の検出
  def detect_device_name(user_agent)
    return 'Unknown Device' unless user_agent

    user_agent = user_agent.downcase

    if user_agent.include?('iphone')
      'iPhone'
    elsif user_agent.include?('ipad')
      'iPad'
    elsif user_agent.include?('android')
      if user_agent.include?('mobile')
        'Android Phone'
      else
        'Android Tablet'
      end
    elsif user_agent.include?('windows')
      'Windows PC'
    elsif user_agent.include?('macintosh') || user_agent.include?('mac os x')
      'Mac'
    elsif user_agent.include?('linux')
      'Linux PC'
    else
      'Unknown Device'
    end
  end

  # ユーザーアクティビティの記録
  def record_activity(activity_type)
    return unless @user && @request

    @user.user_activities.create(
      activity_type: activity_type,
      ip_address: @request.remote_ip,
      user_agent: @request.user_agent,
      details: {
        path: @request.path,
        method: @request.method,
        referer: @request.referer
      }.to_json
    )
  end
end
