class TokenService
  attr_reader :token, :payload, :expires_at

  def initialize(user = nil, token = nil)
    @user = user
    @token = token
  end

  # JWTトークン生成
  def generate
    return nil unless @user

    @payload = {
      user_id: @user.id,
      email: @user.email,
      role: @user.role,
      exp: expiration_time.to_i,
      iat: Time.current.to_i,
      jti: SecureRandom.uuid
    }

    @token = JWT.encode(@payload, secret_key, algorithm)
    @expires_at = Time.at(@payload[:exp])

    @token
  end

  # トークン検証
  def verify
    return false unless @token

    begin
      decoded = JWT.decode(@token, secret_key, true, { algorithm: algorithm })
      @payload = decoded[0]
      @expires_at = Time.at(@payload['exp']) if @payload['exp']

      # JTIが無効化されていないか確認
      return false if revoked?

      true
    rescue JWT::DecodeError
      @error = 'Invalid token'
      false
    rescue JWT::ExpiredSignature
      @error = 'Token has expired'
      false
    rescue JWT::InvalidIatError
      @error = 'Invalid issued at time'
      false
    rescue => e
      @error = "Token verification failed: #{e.message}"
      false
    end
  end

  # トークン更新
  def refresh
    return nil unless verify

    # 古いトークンを無効化
    revoke

    # 新しいユーザー情報を取得
    @user = User.find(@payload['user_id'])

    # 新しいトークンを生成
    generate
  end

  # トークン無効化
  def revoke
    return false unless verify

    # JTIを無効化リストに追加
    jti = @payload['jti']
    exp = @payload['exp']

    # Redisが利用可能な場合はRedisに保存
    if defined?(Redis) && Redis.current
      Redis.current.set("revoked_token:#{jti}", exp, ex: (exp - Time.current.to_i))
    else
      # 代替手段として、データベースに保存
      RevokedToken.create(jti: jti, exp: Time.at(exp))
    end

    true
  end

  # ペイロードの取得
  def payload
    verify unless @payload
    @payload
  end

  # エラーメッセージの取得
  def error_message
    @error
  end

  private

  # 秘密鍵の取得
  def secret_key
    Rails.application.credentials.secret_key_base
  end

  # アルゴリズムの取得
  def algorithm
    'HS256'
  end

  # 有効期限の取得
  def expiration_time
    24.hours.from_now
  end

  # トークンが無効化されているかどうか
  def revoked?
    jti = @payload['jti']

    # Redisが利用可能な場合はRedisから確認
    if defined?(Redis) && Redis.current
      Redis.current.exists?("revoked_token:#{jti}")
    else
      # 代替手段として、データベースから確認
      RevokedToken.exists?(jti: jti)
    end
  end
end

# トークン無効化を管理するモデル
# 実際の実装では、このモデルに対応するテーブルを作成する必要があります
class RevokedToken < ApplicationRecord
  validates :jti, presence: true, uniqueness: true
  validates :exp, presence: true

  # 期限切れのトークンを削除
  def self.remove_expired
    where('exp < ?', Time.current).delete_all
  end
end
