module RateLimiting
  extend ActiveSupport::Concern

  included do
    # レート制限関連の設定を定義するクラス変数
    class_attribute :rate_limit_options, default: {}

    # フィルターを設定
    before_action :check_rate_limit, if: :rate_limiting_enabled?
  end

  class_methods do
    # レート制限設定を構成
    def configure_rate_limiting(options = {})
      self.rate_limit_options = {
        enabled: true,
        limit: 100,
        period: 1.hour,
        by: :ip,
        only: nil,
        except: [],
        throttle: true,
        throttle_with: :throttle_request,
        key_prefix: 'rate_limit',
        cache_store: nil
      }.merge(options)
    end

    # レート制限を適用するアクションを設定
    def rate_limit_only(*actions, **options)
      self.rate_limit_options[:only] = actions
      self.rate_limit_options.merge!(options)
    end

    # レート制限を適用しないアクションを設定
    def skip_rate_limiting(*actions)
      self.rate_limit_options[:except] = actions
    end
  end

  # レート制限キーを生成
  def rate_limit_key
    # コントローラとアクション名を取得
    controller = controller_name
    action = action_name

    # レート制限の対象を取得
    by = rate_limit_options[:by]

    # 対象に応じてキーを生成
    identifier = case by
                 when :ip
                   request.remote_ip
                 when :user
                   current_user&.id || request.remote_ip
                 when :user_agent
                   request.user_agent
                 when :account
                   current_user&.account_id || request.remote_ip
                 when Proc
                   by.call(self)
                 when Symbol, String
                   send(by)
                 else
                   request.remote_ip
                 end

    # キーを生成
    "#{rate_limit_options[:key_prefix]}:#{controller}:#{action}:#{identifier}"
  end

  # レート制限をチェック
  def check_rate_limit
    # レート制限キーを生成
    key = rate_limit_key

    # 現在の時間を取得
    now = Time.current.to_i

    # 期間を秒単位で取得
    period = rate_limit_options[:period].to_i

    # 期間の開始時間を計算
    period_start = now - period

    # キャッシュストアを取得
    cache_store = rate_limit_options[:cache_store] || Rails.cache

    # レート制限情報を取得
    rate_limit_info = cache_store.fetch(key, expires_in: period) do
      { count: 0, reset_at: now + period }
    end

    # カウントを増やす
    rate_limit_info[:count] += 1

    # レート制限情報を更新
    cache_store.write(key, rate_limit_info, expires_in: period)

    # レート制限ヘッダーを設定
    set_rate_limit_headers(rate_limit_info)

    # レート制限を超えた場合
    if rate_limit_info[:count] > rate_limit_options[:limit]
      # スロットリングが有効な場合
      if rate_limit_options[:throttle]
        # スロットリングメソッドを取得
        throttle_method = rate_limit_options[:throttle_with]

        # スロットリングメソッドを実行
        if throttle_method.is_a?(Symbol) || throttle_method.is_a?(String)
          send(throttle_method)
        elsif throttle_method.is_a?(Proc)
          throttle_method.call(self)
        else
          throttle_request
        end

        return false
      end
    end

    true
  end

  # レート制限ヘッダーを設定
  def set_rate_limit_headers(rate_limit_info)
    # レート制限ヘッダーを設定
    response.headers['X-RateLimit-Limit'] = rate_limit_options[:limit].to_s
    response.headers['X-RateLimit-Remaining'] = [0, rate_limit_options[:limit] - rate_limit_info[:count]].max.to_s
    response.headers['X-RateLimit-Reset'] = rate_limit_info[:reset_at].to_s
  end

  # リクエストをスロットリング
  def throttle_request
    # APIリクエストの場合
    if request.format.json? || request.format.xml?
      # レート制限エラーを返す
      respond_to do |format|
        format.json { render json: { error: 'Rate limit exceeded' }, status: :too_many_requests }
        format.xml { render xml: { error: 'Rate limit exceeded' }, status: :too_many_requests }
        format.any { head :too_many_requests }
      end
    else
      # エラーページを表示
      render 'errors/rate_limit', status: :too_many_requests
    end
  end

  # レート制限が有効かどうかをチェック
  def rate_limiting_enabled?
    # レート制限が無効な場合
    return false unless rate_limit_options[:enabled]

    # 特定のアクションのみレート制限を適用する場合
    if rate_limit_options[:only].present?
      return false unless rate_limit_options[:only].include?(action_name.to_sym)
    end

    # 特定のアクションにレート制限を適用しない場合
    if rate_limit_options[:except].present?
      return false if rate_limit_options[:except].include?(action_name.to_sym)
    end

    true
  end

  # レート制限情報を取得
  def get_rate_limit_info
    # レート制限キーを生成
    key = rate_limit_key

    # キャッシュストアを取得
    cache_store = rate_limit_options[:cache_store] || Rails.cache

    # レート制限情報を取得
    rate_limit_info = cache_store.fetch(key) || { count: 0, reset_at: Time.current.to_i + rate_limit_options[:period].to_i }

    # レート制限情報を返す
    {
      limit: rate_limit_options[:limit],
      remaining: [0, rate_limit_options[:limit] - rate_limit_info[:count]].max,
      reset_at: Time.at(rate_limit_info[:reset_at]),
      used: rate_limit_info[:count]
    }
  end

  # レート制限をリセット
  def reset_rate_limit
    # レート制限キーを生成
    key = rate_limit_key

    # キャッシュストアを取得
    cache_store = rate_limit_options[:cache_store] || Rails.cache

    # レート制限情報を削除
    cache_store.delete(key)
  end
end
