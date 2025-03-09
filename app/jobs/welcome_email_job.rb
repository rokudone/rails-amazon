class WelcomeEmailJob < ApplicationJob
  queue_as :mailers

  # 新規ユーザー歓迎メールを送信するジョブ
  def perform(user_id)
    # ユーザー情報を取得
    user = User.find_by(id: user_id)

    # ユーザーが見つからない場合は終了
    return unless user

    # プロフィール情報を取得
    profile = user.profile

    # アカウント情報を取得
    account_info = get_account_info(user, profile)

    # おすすめ商品を取得
    recommended_products = get_recommended_products(user)

    # メール送信
    UserMailer.welcome(user, account_info, recommended_products).deliver_now

    # ログ記録
    log_email_sent(user, account_info)
  end

  private

  # アカウント情報を取得
  def get_account_info(user, profile)
    # アカウント情報を構築
    account_info = {
      email: user.email,
      name: "#{user.first_name} #{user.last_name}".strip,
      created_at: user.created_at,
      account_type: get_account_type(user)
    }

    # プロフィール情報がある場合は追加
    if profile
      account_info[:profile] = {
        avatar: profile.avatar,
        bio: profile.bio,
        occupation: profile.occupation,
        company: profile.company
      }
    end

    # ユーザー設定情報がある場合は追加
    if user.respond_to?(:user_preference) && user.user_preference
      account_info[:preferences] = {
        email_notifications: user.user_preference.email_notifications,
        language: user.user_preference.language,
        currency: user.user_preference.currency
      }
    end

    account_info
  end

  # アカウントタイプを取得
  def get_account_type(user)
    # ユーザーの権限に基づいてアカウントタイプを決定
    if user.respond_to?(:admin?) && user.admin?
      'admin'
    elsif user.respond_to?(:seller?) && user.seller?
      'seller'
    else
      'customer'
    end
  end

  # おすすめ商品を取得
  def get_recommended_products(user)
    # おすすめ商品を取得
    # 実際のアプリケーションでは、ユーザーの好みや行動履歴に基づいておすすめ商品を取得
    if defined?(Product)
      Product.where(is_featured: true).limit(5).map do |product|
        {
          id: product.id,
          name: product.name,
          price: product.price,
          image_url: product.product_images.first&.image_url
        }
      end
    else
      []
    end
  end

  # メール送信をログに記録
  def log_email_sent(user, account_info)
    # ユーザーログに記録
    if defined?(UserLog)
      UserLog.create(
        user_id: user.id,
        action: 'welcome_email_sent',
        details: {
          account_type: account_info[:account_type]
        }
      )
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'email_sent',
        message: "Welcome email sent to user #{user.id}",
        details: {
          user_id: user.id,
          email_type: 'welcome',
          account_type: account_info[:account_type]
        }
      )
    end

    # Railsログに記録
    Rails.logger.info("Welcome email sent to user #{user.id}")
  end
end
