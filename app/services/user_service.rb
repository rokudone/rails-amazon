class UserService
  attr_reader :user

  def initialize(user = nil)
    @user = user
  end

  # ユーザー管理
  def create(params)
    @user = User.new(params)

    if @user.save
      # プロフィールの作成
      create_profile(params[:profile]) if params[:profile].present?

      # ユーザーログの記録
      @user.user_logs.create(
        log_type: 'registration',
        details: { timestamp: Time.current.iso8601 }.to_json
      )

      true
    else
      false
    end
  end

  # ユーザー更新
  def update(params)
    return false unless @user

    if @user.update(params)
      # ユーザーログの記録
      @user.user_logs.create(
        log_type: 'profile_update',
        details: { timestamp: Time.current.iso8601 }.to_json
      )

      true
    else
      false
    end
  end

  # ユーザー検索
  def search(options = {})
    users = User.all

    # キーワード検索
    if options[:query].present?
      users = users.where(
        'email LIKE :query OR first_name LIKE :query OR last_name LIKE :query OR phone_number LIKE :query',
        query: "%#{options[:query]}%"
      )
    end

    # アクティブステータスでフィルタリング
    users = users.where(active: options[:active]) if options[:active].present?

    # ロールでフィルタリング
    users = users.where(role: options[:role]) if options[:role].present?

    # 日付範囲でフィルタリング
    users = users.where('created_at >= ?', options[:start_date]) if options[:start_date].present?
    users = users.where('created_at <= ?', options[:end_date]) if options[:end_date].present?

    # ソート
    users = apply_sort(users, options[:sort])

    # ページネーション
    page = options[:page] || 1
    per_page = options[:per_page] || 20

    users.page(page).per(per_page)
  end

  # ユーザー認証
  def authenticate(email, password)
    user = User.find_by(email: email)

    if user&.authenticate(password)
      if user.active?
        @user = user
        @user.update(last_login_at: Time.current)

        # ユーザーログの記録
        @user.user_logs.create(
          log_type: 'login',
          details: { timestamp: Time.current.iso8601 }.to_json
        )

        true
      else
        @error = 'Account is inactive or locked'
        false
      end
    else
      # 失敗したログイン試行を記録
      if user
        user.increment_failed_attempts!

        # ユーザーログの記録
        user.user_logs.create(
          log_type: 'failed_login',
          details: { timestamp: Time.current.iso8601 }.to_json
        )
      end

      @error = 'Invalid email or password'
      false
    end
  end

  # アカウントロック
  def lock_account
    return false unless @user

    if @user.lock_account!
      # ユーザーログの記録
      @user.user_logs.create(
        log_type: 'account_locked',
        details: { timestamp: Time.current.iso8601 }.to_json
      )

      true
    else
      false
    end
  end

  # アカウントロック解除
  def unlock_account
    return false unless @user

    if @user.unlock_account!
      # ユーザーログの記録
      @user.user_logs.create(
        log_type: 'account_unlocked',
        details: { timestamp: Time.current.iso8601 }.to_json
      )

      true
    else
      false
    end
  end

  # パスワード変更
  def change_password(current_password, new_password)
    return false unless @user

    # 現在のパスワードを確認
    unless @user.authenticate(current_password)
      @error = 'Current password is incorrect'
      return false
    end

    # 新しいパスワードの強度をチェック
    password_service = PasswordService.new
    strength = password_service.password_strength(new_password)

    if strength == :weak
      @error = 'Password is too weak'
      return false
    end

    # パスワードを更新
    if @user.update(password: new_password)
      # ユーザーログの記録
      @user.user_logs.create(
        log_type: 'password_changed',
        details: { timestamp: Time.current.iso8601 }.to_json
      )

      # 全セッションを無効化（オプション）
      SessionService.new(@user).invalidate_all

      true
    else
      @error = @user.errors.full_messages.join(', ')
      false
    end
  end

  # パスワードリセット
  def reset_password
    return false unless @user

    # パスワードリセットトークンの生成
    password_service = PasswordService.new(@user)
    token = password_service.reset_password

    if token
      # メール送信などの処理
      # UserMailer.reset_password_email(@user, token).deliver_later

      true
    else
      @error = 'Failed to generate reset token'
      false
    end
  end

  # ユーザーアクティビティの取得
  def activities(options = {})
    return [] unless @user

    activities = @user.user_activities

    # アクティビティタイプでフィルタリング
    activities = activities.where(activity_type: options[:activity_type]) if options[:activity_type].present?

    # 日付範囲でフィルタリング
    activities = activities.where('created_at >= ?', options[:start_date]) if options[:start_date].present?
    activities = activities.where('created_at <= ?', options[:end_date]) if options[:end_date].present?

    # ソート
    case options[:sort]
    when 'newest'
      activities = activities.order(created_at: :desc)
    when 'oldest'
      activities = activities.order(created_at: :asc)
    else
      activities = activities.order(created_at: :desc)
    end

    # ページネーション
    page = options[:page] || 1
    per_page = options[:per_page] || 20

    activities.page(page).per(per_page)
  end

  # ユーザーログの取得
  def logs(options = {})
    return [] unless @user

    logs = @user.user_logs

    # ログタイプでフィルタリング
    logs = logs.where(log_type: options[:log_type]) if options[:log_type].present?

    # 日付範囲でフィルタリング
    logs = logs.where('created_at >= ?', options[:start_date]) if options[:start_date].present?
    logs = logs.where('created_at <= ?', options[:end_date]) if options[:end_date].present?

    # ソート
    case options[:sort]
    when 'newest'
      logs = logs.order(created_at: :desc)
    when 'oldest'
      logs = logs.order(created_at: :asc)
    else
      logs = logs.order(created_at: :desc)
    end

    # ページネーション
    page = options[:page] || 1
    per_page = options[:per_page] || 20

    logs.page(page).per(per_page)
  end

  # ユーザーデバイスの取得
  def devices(options = {})
    return [] unless @user

    devices = @user.user_devices

    # デバイスタイプでフィルタリング
    devices = devices.where(device_type: options[:device_type]) if options[:device_type].present?

    # ソート
    case options[:sort]
    when 'newest'
      devices = devices.order(created_at: :desc)
    when 'last_used'
      devices = devices.order(last_used_at: :desc)
    else
      devices = devices.order(last_used_at: :desc)
    end

    devices
  end

  # ユーザーセッションの取得
  def sessions(options = {})
    return [] unless @user

    sessions = @user.user_sessions

    # アクティブセッションのみ
    sessions = sessions.where('expired_at IS NULL OR expired_at > ?', Time.current) if options[:active_only]

    # ソート
    case options[:sort]
    when 'newest'
      sessions = sessions.order(created_at: :desc)
    else
      sessions = sessions.order(created_at: :desc)
    end

    sessions
  end

  # エラーメッセージの取得
  def error_message
    @error || @user&.errors&.full_messages&.join(', ')
  end

  private

  # プロフィールの作成
  def create_profile(profile_params)
    @user.create_profile(profile_params)
  end

  # ソートの適用
  def apply_sort(users, sort)
    case sort
    when 'newest'
      users.order(created_at: :desc)
    when 'oldest'
      users.order(created_at: :asc)
    when 'name'
      users.order(:first_name, :last_name)
    when 'email'
      users.order(:email)
    when 'last_login'
      users.order(last_login_at: :desc)
    else
      users.order(created_at: :desc)
    end
  end
end
