module Authentication
  extend ActiveSupport::Concern

  included do
    # 認証関連の設定を定義するクラス変数
    class_attribute :authentication_options, default: {}

    # ヘルパーメソッドを定義
    helper_method :current_user, :user_signed_in?, :authenticate_user!

    # フィルターを設定
    before_action :authenticate_user!, if: :authentication_required?
  end

  class_methods do
    # 認証設定を構成
    def configure_authentication(options = {})
      self.authentication_options = {
        required: true,
        except: [],
        only: nil,
        store_location: true,
        redirect_url: '/login',
        api_token_header: 'Authorization',
        api_token_param: 'api_token',
        api_response_format: :json
      }.merge(options)
    end

    # 認証が必要なアクションを設定
    def authenticate_only(*actions)
      self.authentication_options[:only] = actions
      self.authentication_options[:except] = nil
    end

    # 認証が不要なアクションを設定
    def skip_authentication(*actions)
      self.authentication_options[:except] = actions
      self.authentication_options[:only] = nil
    end
  end

  # 現在のユーザーを取得
  def current_user
    # セッションからユーザーIDを取得
    return @current_user if defined?(@current_user)

    # APIリクエストの場合はトークンから認証
    if api_request?
      @current_user = authenticate_with_token
    else
      # セッションからユーザーIDを取得
      user_id = session[:user_id]

      # ユーザーIDが存在する場合はユーザーを取得
      @current_user = User.find_by(id: user_id) if user_id
    end
  end

  # ユーザーがサインインしているかどうかをチェック
  def user_signed_in?
    current_user.present?
  end

  # ユーザーを認証
  def authenticate_user!
    # ユーザーがサインインしていない場合
    unless user_signed_in?
      # APIリクエストの場合
      if api_request?
        # 認証エラーを返す
        respond_to do |format|
          format.json { render json: { error: 'Unauthorized' }, status: :unauthorized }
          format.xml { render xml: { error: 'Unauthorized' }, status: :unauthorized }
          format.any { head :unauthorized }
        end
      else
        # 現在のURLを保存
        store_location if authentication_options[:store_location]

        # ログインページにリダイレクト
        redirect_to authentication_options[:redirect_url], alert: 'Please sign in to continue'
      end

      return false
    end

    true
  end

  # 現在のURLを保存
  def store_location
    # GETリクエストの場合のみ保存
    if request.get?
      session[:return_to] = request.fullpath
    end
  end

  # 保存されたURLにリダイレクト
  def redirect_back_or_default(default = '/')
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end

  # ユーザーをサインイン
  def sign_in(user)
    # セッションにユーザーIDを保存
    session[:user_id] = user.id

    # 現在のユーザーを設定
    @current_user = user

    # ユーザーのセッション情報を更新
    if defined?(UserSession) && user.respond_to?(:user_sessions)
      user.user_sessions.create(
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        last_activity_at: Time.current
      )
    end

    # ユーザーのログイン情報を更新
    if user.respond_to?(:last_sign_in_at)
      user.update(
        last_sign_in_at: Time.current,
        last_sign_in_ip: request.remote_ip,
        sign_in_count: user.sign_in_count.to_i + 1
      )
    end
  end

  # ユーザーをサインアウト
  def sign_out
    # 現在のユーザーセッションを削除
    if defined?(UserSession) && current_user&.respond_to?(:user_sessions)
      current_user.user_sessions.where(ip_address: request.remote_ip).destroy_all
    end

    # セッションからユーザーIDを削除
    session[:user_id] = nil

    # 現在のユーザーをリセット
    @current_user = nil
  end

  # APIリクエストかどうかをチェック
  def api_request?
    # リクエストフォーマットがJSONまたはXMLの場合
    request.format.json? || request.format.xml? ||
      # または、URLにAPIが含まれている場合
      request.path.include?('/api/') ||
      # または、APIトークンが含まれている場合
      api_token.present?
  end

  # APIトークンを取得
  def api_token
    # ヘッダーからトークンを取得
    token_header = request.headers[authentication_options[:api_token_header]]

    # ヘッダーからトークンを抽出
    if token_header.present? && token_header.start_with?('Bearer ')
      token = token_header.gsub('Bearer ', '')
    else
      # パラメータからトークンを取得
      token = params[authentication_options[:api_token_param]]
    end

    token
  end

  # トークンからユーザーを認証
  def authenticate_with_token
    # トークンが存在しない場合はnilを返す
    return nil unless api_token.present?

    # トークンサービスが定義されている場合は使用
    if defined?(TokenService) && TokenService.respond_to?(:verify)
      # トークンを検証
      user_id = TokenService.verify(api_token)

      # ユーザーIDが存在する場合はユーザーを取得
      User.find_by(id: user_id) if user_id
    else
      # APIトークンからユーザーを取得
      User.find_by(api_token: api_token)
    end
  end

  # 認証が必要かどうかをチェック
  def authentication_required?
    # 認証が必要ない場合はfalseを返す
    return false unless authentication_options[:required]

    # 特定のアクションのみ認証が必要な場合
    if authentication_options[:only].present?
      return authentication_options[:only].include?(action_name.to_sym)
    end

    # 特定のアクション以外は認証が必要な場合
    if authentication_options[:except].present?
      return !authentication_options[:except].include?(action_name.to_sym)
    end

    # デフォルトでは認証が必要
    true
  end
end
