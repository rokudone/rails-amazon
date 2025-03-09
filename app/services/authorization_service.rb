class AuthorizationService
  attr_reader :user, :resource, :action

  def initialize(user, resource = nil, action = nil)
    @user = user
    @resource = resource
    @action = action
  end

  # 権限確認
  def authorized?
    return false unless @user

    # 管理者は全ての操作が可能
    return true if admin?

    # リソースとアクションに基づく権限確認
    case @resource
    when :user
      authorize_user
    when :product
      authorize_product
    when :order
      authorize_order
    when :seller
      authorize_seller
    when :admin
      authorize_admin
    else
      # デフォルトでは、リソースが指定されていない場合は認証済みユーザーのみ許可
      true
    end
  end

  # 管理者かどうか
  def admin?
    @user.role == 'admin'
  end

  # セラーかどうか
  def seller?
    Seller.exists?(user_id: @user.id, active: true, verified: true)
  end

  # リソースの所有者かどうか
  def owner?(resource)
    return false unless resource && @user

    case resource
    when User
      resource.id == @user.id
    when Order
      resource.user_id == @user.id
    when Product
      # 商品の所有者（セラー）かどうか
      seller = Seller.find_by(user_id: @user.id)
      seller && SellerProduct.exists?(seller_id: seller.id, product_id: resource.id)
    when Review, Question, Answer
      resource.user_id == @user.id
    when Cart, Wishlist
      resource.user_id == @user.id
    when Address, PaymentMethod
      resource.user_id == @user.id
    else
      # その他のリソースはデフォルトで所有者ではない
      false
    end
  end

  # ロールベースのアクセス制御
  def has_role?(role)
    @user.role == role
  end

  # 特定の権限を持っているかどうか
  def has_permission?(permission)
    return true if admin?

    @user.user_permissions.exists?(permission_name: permission)
  end

  private

  # ユーザーリソースの権限確認
  def authorize_user
    case @action
    when :view
      # 自分自身または管理者のみ閲覧可能
      @resource.nil? || owner?(@resource) || admin?
    when :create
      # 新規ユーザー作成は誰でも可能
      true
    when :update, :delete
      # 自分自身または管理者のみ更新・削除可能
      owner?(@resource) || admin?
    else
      false
    end
  end

  # 商品リソースの権限確認
  def authorize_product
    case @action
    when :view
      # 商品の閲覧は誰でも可能
      true
    when :create, :update, :delete
      # 商品の作成・更新・削除はセラーまたは管理者のみ可能
      seller? || admin?
    else
      false
    end
  end

  # 注文リソースの権限確認
  def authorize_order
    case @action
    when :view
      # 自分の注文または管理者のみ閲覧可能
      @resource.nil? || owner?(@resource) || admin?
    when :create
      # 注文の作成は認証済みユーザーのみ可能
      true
    when :update, :delete
      # 注文の更新・削除は管理者のみ可能
      admin?
    else
      false
    end
  end

  # セラーリソースの権限確認
  def authorize_seller
    case @action
    when :view
      # セラー情報の閲覧は誰でも可能
      true
    when :create
      # セラー登録は認証済みユーザーのみ可能
      true
    when :update, :delete
      # セラー情報の更新・削除は自分自身または管理者のみ可能
      owner?(@resource) || admin?
    else
      false
    end
  end

  # 管理者リソースの権限確認
  def authorize_admin
    # 管理者リソースへのアクセスは管理者のみ可能
    admin?
  end
end
