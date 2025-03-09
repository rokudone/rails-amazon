class PasswordResetJob < ApplicationJob
  queue_as :mailers

  # パスワードリセットメールを送信するジョブ
  def perform(user_id, reset_token)
    # ユーザー情報を取得
    user = User.find_by(id: user_id)

    # ユーザーが見つからない場合は終了
    return unless user

    # リセットトークンが指定されていない場合は生成
    reset_token ||= generate_reset_token(user)

    # リセットトークンをユーザーに設定
    update_user_reset_token(user, reset_token)

    # メール送信
    UserMailer.password_reset(user, reset_token).deliver_now

    # ログ記録
    log_email_sent(user, reset_token)
  end

  private

  # リセットトークンを生成
  def generate_reset_token(user)
    # セキュアなランダムトークンを生成
    SecureRandom.urlsafe_base64(32)
  end

  # ユーザーのリセットトークンを更新
  def update_user_reset_token(user, reset_token)
    # リセットトークンとその有効期限を設定
    user.update(
      reset_password_token: reset_token,
      reset_password_sent_at: Time.current
    )
  end

  # メール送信をログに記録
  def log_email_sent(user, reset_token)
    # ユーザーログに記録
    if defined?(UserLog)
      UserLog.create(
        user_id: user.id,
        action: 'password_reset_email_sent',
        details: {
          reset_token_digest: Digest::SHA256.hexdigest(reset_token)
        }
      )
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'email_sent',
        message: "Password reset email sent to user #{user.id}",
        details: {
          user_id: user.id,
          email_type: 'password_reset',
          reset_token_digest: Digest::SHA256.hexdigest(reset_token)
        }
      )
    end

    # Railsログに記録
    Rails.logger.info("Password reset email sent to user #{user.id}")
  end
end
