class NewsletterJob < ApplicationJob
  queue_as :mailers

  # ニュースレターを送信するジョブ
  def perform(newsletter_id, user_ids = nil)
    # ニュースレター情報を取得
    newsletter = find_newsletter(newsletter_id)

    # ニュースレターが見つからない場合は終了
    return unless newsletter

    # 送信対象のユーザーを取得
    users = get_target_users(user_ids, newsletter)

    # ユーザーが見つからない場合は終了
    return if users.empty?

    # 各ユーザーにニュースレターを送信
    users.each do |user|
      # ユーザー固有のコンテンツを生成
      personalized_content = personalize_content(newsletter, user)

      # 購読管理リンクを生成
      subscription_management_link = generate_subscription_link(user)

      # メール送信
      NewsletterMailer.send_newsletter(user, newsletter, personalized_content, subscription_management_link).deliver_later

      # ログ記録
      log_email_scheduled(user, newsletter)
    end

    # ニュースレター送信完了を記録
    update_newsletter_status(newsletter, users.size)
  end

  private

  # ニュースレター情報を取得
  def find_newsletter(newsletter_id)
    # ニュースレターモデルが定義されている場合
    if defined?(Newsletter)
      Newsletter.find_by(id: newsletter_id)
    else
      # シミュレーション用のニュースレター情報
      {
        id: newsletter_id,
        title: "Newsletter ##{newsletter_id}",
        content: "This is the content of newsletter ##{newsletter_id}",
        created_at: Time.current,
        template: 'default'
      }
    end
  end

  # 送信対象のユーザーを取得
  def get_target_users(user_ids, newsletter)
    if user_ids.present?
      # 指定されたユーザーIDのユーザーを取得
      User.where(id: user_ids).where(active: true)
    else
      # ニュースレターの購読者を取得
      get_newsletter_subscribers(newsletter)
    end
  end

  # ニュースレターの購読者を取得
  def get_newsletter_subscribers(newsletter)
    # ユーザー設定でニュースレターの購読を許可しているユーザーを取得
    if defined?(UserPreference)
      User.joins(:user_preference)
          .where(active: true)
          .where(user_preferences: { email_notifications: true })
    else
      # シミュレーション用
      User.where(active: true)
    end
  end

  # ユーザー固有のコンテンツを生成
  def personalize_content(newsletter, user)
    # ユーザー情報に基づいてコンテンツをパーソナライズ
    content = newsletter.is_a?(Hash) ? newsletter[:content] : newsletter.content

    # ユーザー名を置換
    content = content.gsub('{{user_name}}', "#{user.first_name} #{user.last_name}".strip)

    # ユーザーIDを置換
    content = content.gsub('{{user_id}}', user.id.to_s)

    # おすすめ商品を追加
    if content.include?('{{recommended_products}}')
      recommended_products = get_recommended_products(user)
      products_html = format_recommended_products(recommended_products)
      content = content.gsub('{{recommended_products}}', products_html)
    end

    content
  end

  # おすすめ商品を取得
  def get_recommended_products(user)
    # ユーザーの好みに基づいておすすめ商品を取得
    if defined?(Product)
      # ユーザーの購入履歴から好みのカテゴリを取得
      category_ids = if defined?(Order) && user.respond_to?(:orders)
                       user.orders.joins(order_items: :product)
                           .pluck('products.category_id')
                           .compact.uniq
                     else
                       []
                     end

      # カテゴリに基づいて商品を取得
      if category_ids.present?
        Product.where(category_id: category_ids)
               .where(is_active: true)
               .order(created_at: :desc)
               .limit(3)
      else
        # カテゴリが取得できない場合は人気商品を取得
        Product.where(is_active: true)
               .where(is_featured: true)
               .order(created_at: :desc)
               .limit(3)
      end
    else
      []
    end
  end

  # おすすめ商品をHTML形式にフォーマット
  def format_recommended_products(products)
    return '' if products.empty?

    html = '<div class="recommended-products">'
    html += '<h3>Recommended Products</h3>'
    html += '<div class="products-grid">'

    products.each do |product|
      html += '<div class="product-item">'
      html += "<img src=\"#{product.product_images.first&.image_url || ''}\" alt=\"#{product.name}\">"
      html += "<h4>#{product.name}</h4>"
      html += "<p class=\"price\">#{format_price(product.price)}</p>"
      html += "<a href=\"/products/#{product.id}\" class=\"btn\">View Product</a>"
      html += '</div>'
    end

    html += '</div>'
    html += '</div>'

    html
  end

  # 価格をフォーマット
  def format_price(price)
    "¥#{price.to_i.to_s(:delimited)}"
  end

  # 購読管理リンクを生成
  def generate_subscription_link(user)
    # 購読管理トークンを生成
    token = generate_subscription_token(user)

    # 購読管理URLを生成
    "#{base_url}/subscription/manage?token=#{token}&email=#{CGI.escape(user.email)}"
  end

  # 購読管理トークンを生成
  def generate_subscription_token(user)
    # トークンを生成
    raw_token = SecureRandom.urlsafe_base64(32)

    # トークンをハッシュ化
    hashed_token = Digest::SHA256.hexdigest(raw_token)

    # トークンを保存
    if defined?(UserToken) && user.respond_to?(:user_tokens)
      user.user_tokens.create(
        token_type: 'subscription_management',
        token: hashed_token,
        expires_at: 30.days.from_now
      )
    end

    raw_token
  end

  # ベースURLを取得
  def base_url
    # 環境に応じてベースURLを取得
    if Rails.env.production?
      'https://example.com'
    else
      'http://localhost:3000'
    end
  end

  # メール送信をログに記録
  def log_email_scheduled(user, newsletter)
    # ユーザーログに記録
    if defined?(UserLog)
      UserLog.create(
        user_id: user.id,
        action: 'newsletter_email_scheduled',
        details: {
          newsletter_id: newsletter.is_a?(Hash) ? newsletter[:id] : newsletter.id,
          newsletter_title: newsletter.is_a?(Hash) ? newsletter[:title] : newsletter.title
        }
      )
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'email_scheduled',
        message: "Newsletter email scheduled for user #{user.id}",
        details: {
          user_id: user.id,
          email_type: 'newsletter',
          newsletter_id: newsletter.is_a?(Hash) ? newsletter[:id] : newsletter.id,
          newsletter_title: newsletter.is_a?(Hash) ? newsletter[:title] : newsletter.title
        }
      )
    end

    # Railsログに記録
    Rails.logger.info("Newsletter email scheduled for user #{user.id}")
  end

  # ニュースレター送信完了を記録
  def update_newsletter_status(newsletter, sent_count)
    # ニュースレターモデルが定義されている場合
    if defined?(Newsletter) && !newsletter.is_a?(Hash)
      newsletter.update(
        sent_at: Time.current,
        sent_count: sent_count
      )
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'newsletter_sent',
        message: "Newsletter sent to #{sent_count} users",
        details: {
          newsletter_id: newsletter.is_a?(Hash) ? newsletter[:id] : newsletter.id,
          newsletter_title: newsletter.is_a?(Hash) ? newsletter[:title] : newsletter.title,
          sent_count: sent_count
        }
      )
    end

    # Railsログに記録
    Rails.logger.info("Newsletter sent to #{sent_count} users")
  end
end
