class AuthenticationService
  attr_reader :user, :token, :expires_at

  def initialize(email: nil, password: nil, token: nil)
    @email = email
    @password = password
    @token = token
  end

  # ユーザー認証
  def authenticate
    return false unless @email.present? && @password.present?

    @user = User.find_by(email: @email)

    if @user&.authenticate(@password)
      if @user.active?
        @user.update(last_login_at: Time.current)
        generate_token
        create_session
        true
      else
        @error = 'Account is inactive or locked'
        false
      end
    else
      # 失敗したログイン試行を記録
      @user&.increment_failed_attempts!
      @error = 'Invalid email or password'
      false
    end
  end

  # トークン検証
  def authenticate_token
    return false unless @token.present?

    payload = decode_token
    return false unless payload

    @user = User.find_by(id: payload['user_id'])

    if @user
      session = @user.user_sessions.find_by(token: @token)

      if session && (session.expired_at.nil? || session.expired_at > Time.current)
        @expires_at = payload['exp'] ? Time.at(payload['exp']) : nil
        true
      else
        @error = 'Session expired'
        false
      end
    else
      @error = 'User not found'
      false
    end
  end

  # トークン更新
  def refresh_token
    return false unless authenticate_token

    # 古いセッションを無効化
    old_session = @user.user_sessions.find_by(token: @token)
    old_session.update(expired_at: Time.current) if old_session

    # 新しいトークンを生成
    generate_token
    create_session
    true
  end

  # ログアウト
  def logout
    return false unless authenticate_token

    session = @user.user_sessions.find_by(token: @token)
    session.update(expired_at: Time.current) if session
    true
  end

  # エラーメッセージの取得
  def error_message
    @error
  end

  private

  # トークン生成
  def generate_token
    payload = {
      user_id: @user.id,
      email: @user.email,
      exp: 24.hours.from_now.to_i
    }

    @token = JWT.encode(payload, Rails.application.credentials.secret_key_base)
    @expires_at = Time.at(payload[:exp])
  end

  # セッション作成
  def create_session
    @user.user_sessions.create(
      token: @token,
      ip_address: RequestStore.store[:remote_ip],
      user_agent: RequestStore.store[:user_agent],
      device_type: detect_device_type,
      expired_at: @expires_at
    )
  end

  # トークンデコード
  def decode_token
    begin
      decoded = JWT.decode(@token, Rails.application.credentials.secret_key_base, true, { algorithm: 'HS256' })
      decoded[0]
    rescue JWT::DecodeError, JWT::ExpiredSignature
      @error = 'Invalid or expired token'
      nil
    end
  end

  # デバイスタイプの検出
  def detect_device_type
    user_agent = RequestStore.store[:user_agent]&.downcase

    return 'unknown' unless user_agent

    if user_agent.match?(/mobile|android|iphone|ipad|ipod/)
      'mobile'
    elsif user_agent.match?(/tablet/)
      'tablet'
    else
      'desktop'
    end
  end
end
