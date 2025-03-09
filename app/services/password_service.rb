class PasswordService
  attr_reader :user

  def initialize(user = nil)
    @user = user
  end

  # パスワードハッシュ化
  def hash_password(password)
    BCrypt::Password.create(password)
  end

  # パスワード検証
  def verify_password(password, password_digest)
    BCrypt::Password.new(password_digest) == password
  rescue BCrypt::Errors::InvalidHash
    false
  end

  # パスワード強度チェック
  def password_strength(password)
    return :weak if password.length < 8

    score = 0

    # 長さによるスコア
    score += [password.length / 2, 10].min

    # 文字種類によるスコア
    score += 1 if password =~ /[a-z]/
    score += 1 if password =~ /[A-Z]/
    score += 1 if password =~ /[0-9]/
    score += 2 if password =~ /[^a-zA-Z0-9]/

    # 文字の繰り返しによるスコア減少
    score -= 1 if password =~ /(.)\1{2,}/

    # 連続した文字によるスコア減少
    score -= 1 if password =~ /(abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz)/i
    score -= 1 if password =~ /(123|234|345|456|567|678|789|890)/

    # 一般的なパスワードパターンによるスコア減少
    common_patterns = [
      /password/i, /123456/, /qwerty/i, /admin/i, /welcome/i, /letmein/i,
      /monkey/i, /abc123/i, /football/i, /iloveyou/i, /trustno1/i
    ]

    common_patterns.each do |pattern|
      score -= 2 if password =~ pattern
    end

    # スコアに基づく強度評価
    if score < 5
      :weak
    elsif score < 10
      :medium
    else
      :strong
    end
  end

  # パスワードリセット
  def reset_password
    return false unless @user

    # リセットトークンの生成
    token = generate_token

    # ユーザー情報の更新
    @user.update(
      reset_password_token: token,
      reset_password_sent_at: Time.current
    )

    # ユーザーログの記録
    @user.user_logs.create(
      log_type: 'password_reset_requested',
      details: { timestamp: Time.current.iso8601 }.to_json
    )

    token
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
    strength = password_strength(new_password)

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

  # パスワードリセットの完了
  def complete_reset(token, new_password)
    # トークンでユーザーを検索
    @user = User.find_by(reset_password_token: token)

    unless @user
      @error = 'Invalid token'
      return false
    end

    # トークンの有効期限をチェック
    if @user.reset_password_sent_at < 24.hours.ago
      @error = 'Token has expired'
      return false
    end

    # 新しいパスワードの強度をチェック
    strength = password_strength(new_password)

    if strength == :weak
      @error = 'Password is too weak'
      return false
    end

    # パスワードを更新
    if @user.update(
      password: new_password,
      reset_password_token: nil,
      reset_password_sent_at: nil
    )
      # ユーザーログの記録
      @user.user_logs.create(
        log_type: 'password_reset_completed',
        details: { timestamp: Time.current.iso8601 }.to_json
      )

      # 全セッションを無効化
      SessionService.new(@user).invalidate_all

      true
    else
      @error = @user.errors.full_messages.join(', ')
      false
    end
  end

  # エラーメッセージの取得
  def error_message
    @error
  end

  private

  # トークン生成
  def generate_token
    SecureRandom.hex(20)
  end
end
