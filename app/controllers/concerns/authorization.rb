module Authorization
  extend ActiveSupport::Concern

  included do
    # 認可関連の設定を定義するクラス変数
    class_attribute :authorization_options, default: {}

    # ヘルパーメソッドを定義
    helper_method :can?, :cannot?, :authorize!

    # フィルターを設定
    before_action :check_authorization, if: :authorization_required?
  end

  class_methods do
    # 認可設定を構成
    def configure_authorization(options = {})
      self.authorization_options = {
        required: true,
        except: [],
        only: nil,
        resource_param: :id,
        resource_class: nil,
        skip_resource_loading: false,
        unauthorized_message: 'You are not authorized to perform this action',
        unauthorized_redirect: '/'
      }.merge(options)
    end

    # 認可が必要なアクションを設定
    def authorize_only(*actions)
      self.authorization_options[:only] = actions
      self.authorization_options[:except] = nil
    end

    # 認可が不要なアクションを設定
    def skip_authorization(*actions)
      self.authorization_options[:except] = actions
      self.authorization_options[:only] = nil
    end

    # リソースクラスを設定
    def authorize_resource(resource_class, options = {})
      self.authorization_options[:resource_class] = resource_class
      self.authorization_options.merge!(options)
    end
  end

  # アクションに対する権限をチェック
  def can?(action, resource = nil)
    # AuthorizationServiceが定義されている場合は使用
    if defined?(AuthorizationService) && AuthorizationService.respond_to?(:can?)
      AuthorizationService.can?(current_user, action, resource)
    else
      # 簡易的な権限チェック
      case action.to_sym
      when :read
        true
      when :create
        user_signed_in?
      when :update, :destroy
        user_signed_in? && (resource.respond_to?(:user_id) ? resource.user_id == current_user&.id : false)
      else
        false
      end
    end
  end

  # アクションに対する権限がないかどうかをチェック
  def cannot?(action, resource = nil)
    !can?(action, resource)
  end

  # 権限をチェックし、権限がない場合は例外を発生
  def authorize!(action, resource = nil)
    # 権限がない場合
    unless can?(action, resource)
      # CustomExceptionsが定義されている場合は使用
      if defined?(CustomExceptions) && defined?(CustomExceptions::AuthorizationError)
        raise CustomExceptions::AuthorizationError, authorization_options[:unauthorized_message]
      else
        # 標準の例外を発生
        raise StandardError, authorization_options[:unauthorized_message]
      end
    end

    true
  end

  # 認可をチェック
  def check_authorization
    # リソースを読み込み
    resource = load_resource_for_authorization unless authorization_options[:skip_resource_loading]

    # アクションに対応する権限アクションを取得
    permission_action = permission_action_for_controller_action

    # 権限をチェック
    authorize!(permission_action, resource)
  rescue => e
    # APIリクエストの場合
    if api_request?
      # 認可エラーを返す
      respond_to do |format|
        format.json { render json: { error: e.message }, status: :forbidden }
        format.xml { render xml: { error: e.message }, status: :forbidden }
        format.any { head :forbidden }
      end
    else
      # エラーメッセージを設定
      flash[:alert] = e.message

      # リダイレクト
      redirect_to authorization_options[:unauthorized_redirect]
    end

    return false
  end

  # 認可用のリソースを読み込み
  def load_resource_for_authorization
    # リソースクラスが設定されていない場合はnilを返す
    return nil unless authorization_options[:resource_class]

    # リソースIDを取得
    resource_id = params[authorization_options[:resource_param]]

    # リソースIDが存在しない場合はnilを返す
    return nil unless resource_id

    # リソースクラスを取得
    resource_class = authorization_options[:resource_class].is_a?(String) ?
                     authorization_options[:resource_class].constantize :
                     authorization_options[:resource_class]

    # リソースを取得
    resource_class.find(resource_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  # コントローラアクションに対応する権限アクションを取得
  def permission_action_for_controller_action
    case action_name.to_sym
    when :index, :show
      :read
    when :new, :create
      :create
    when :edit, :update
      :update
    when :destroy
      :destroy
    else
      action_name.to_sym
    end
  end

  # APIリクエストかどうかをチェック
  def api_request?
    # Authenticationコンサーンが含まれている場合はそのメソッドを使用
    return super if defined?(super)

    # リクエストフォーマットがJSONまたはXMLの場合
    request.format.json? || request.format.xml? ||
      # または、URLにAPIが含まれている場合
      request.path.include?('/api/')
  end

  # 認可が必要かどうかをチェック
  def authorization_required?
    # 認可が必要ない場合はfalseを返す
    return false unless authorization_options[:required]

    # 特定のアクションのみ認可が必要な場合
    if authorization_options[:only].present?
      return authorization_options[:only].include?(action_name.to_sym)
    end

    # 特定のアクション以外は認可が必要な場合
    if authorization_options[:except].present?
      return !authorization_options[:except].include?(action_name.to_sym)
    end

    # デフォルトでは認可が必要
    true
  end

  # ユーザーがサインインしているかどうかをチェック
  def user_signed_in?
    # Authenticationコンサーンが含まれている場合はそのメソッドを使用
    return super if defined?(super)

    # 現在のユーザーが存在するかどうかをチェック
    current_user.present?
  end

  # 現在のユーザーを取得
  def current_user
    # Authenticationコンサーンが含まれている場合はそのメソッドを使用
    return super if defined?(super)

    # セッションからユーザーIDを取得
    user_id = session[:user_id]

    # ユーザーIDが存在する場合はユーザーを取得
    @current_user ||= User.find_by(id: user_id) if user_id
  end
end
