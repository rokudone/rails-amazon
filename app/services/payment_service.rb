class PaymentService
  attr_reader :payment, :order, :user

  def initialize(payment = nil, order = nil, user = nil)
    @payment = payment
    @order = order
    @user = user
  end

  # 支払い処理
  def process_payment(params)
    @order = Order.find_by(id: params[:order_id])
    return false unless @order

    # 支払い方法の取得
    payment_method = if params[:payment_method_id].present?
                      PaymentMethod.find_by(id: params[:payment_method_id])
                    else
                      @order.payment_method
                    end

    return false unless payment_method

    # 支払い金額の取得
    amount = params[:amount] || @order.total

    # 支払いの作成
    @payment = Payment.new(
      order_id: @order.id,
      amount: amount,
      payment_method: payment_method.payment_type,
      payment_method_id: payment_method.id,
      status: 'processing',
      currency: params[:currency] || @order.currency || 'USD'
    )

    if @payment.save
      # 支払い処理の実行
      result = execute_payment(params[:payment_details])

      if result[:success]
        # 支払い成功
        @payment.update(
          status: 'completed',
          transaction_id: result[:transaction_id]
        )

        # 支払い処理の記録
        PaymentTransaction.create(
          payment_id: @payment.id,
          amount: @payment.amount,
          transaction_type: 'payment',
          status: 'completed',
          transaction_id: result[:transaction_id],
          provider_response: result[:response].to_json
        )

        # 注文ステータスの更新
        @order.update(status: 'paid')

        # 注文ログの作成
        @order.order_logs.create(
          status: 'paid',
          notes: "Payment completed: #{@payment.payment_method}",
          user_id: @user&.id
        )

        true
      else
        # 支払い失敗
        @payment.update(status: 'failed')

        # 支払い処理の記録
        PaymentTransaction.create(
          payment_id: @payment.id,
          amount: @payment.amount,
          transaction_type: 'payment',
          status: 'failed',
          provider_response: result[:response].to_json
        )

        @error = result[:error]
        false
      end
    else
      @error = @payment.errors.full_messages.join(', ')
      false
    end
  end

  # 支払い検証
  def verify_payment(transaction_id)
    # 支払いの検証処理
    # 実際の実装では、決済ゲートウェイAPIを使用して支払いを検証

    # 支払いの取得
    @payment = Payment.find_by(transaction_id: transaction_id)
    return false unless @payment

    # 支払い検証の実行
    result = verify_payment_with_gateway(transaction_id)

    if result[:success]
      # 検証成功
      if @payment.status != 'completed'
        @payment.update(status: 'completed')

        # 注文ステータスの更新
        if @payment.order && @payment.order.status != 'paid'
          @payment.order.update(status: 'paid')

          # 注文ログの作成
          @payment.order.order_logs.create(
            status: 'paid',
            notes: "Payment verified: #{@payment.payment_method}",
            user_id: @user&.id
          )
        end
      end

      true
    else
      # 検証失敗
      @error = result[:error]
      false
    end
  end

  # 支払い履歴
  def payment_history(options = {})
    return [] unless @user

    payments = Payment.joins(:order).where(orders: { user_id: @user.id })

    # ステータスでフィルタリング
    payments = payments.where(status: options[:status]) if options[:status].present?

    # 日付範囲でフィルタリング
    payments = payments.where('payments.created_at >= ?', options[:start_date]) if options[:start_date].present?
    payments = payments.where('payments.created_at <= ?', options[:end_date]) if options[:end_date].present?

    # 金額範囲でフィルタリング
    payments = payments.where('amount >= ?', options[:min_amount]) if options[:min_amount].present?
    payments = payments.where('amount <= ?', options[:max_amount]) if options[:max_amount].present?

    # ソート
    case options[:sort]
    when 'newest'
      payments = payments.order('payments.created_at DESC')
    when 'oldest'
      payments = payments.order('payments.created_at ASC')
    when 'amount_desc'
      payments = payments.order(amount: :desc)
    when 'amount_asc'
      payments = payments.order(amount: :asc)
    else
      payments = payments.order('payments.created_at DESC')
    end

    # ページネーション
    page = options[:page] || 1
    per_page = options[:per_page] || 20

    payments.page(page).per(per_page)
  end

  # 返金処理
  def process_refund(params)
    @payment = Payment.find_by(id: params[:payment_id])
    return false unless @payment && @payment.status == 'completed'

    # 返金金額の取得
    amount = params[:amount] || @payment.amount

    # 返金理由の取得
    reason = params[:reason] || 'Customer requested refund'

    # 返金処理の実行
    result = execute_refund(@payment.transaction_id, amount, reason)

    if result[:success]
      # 返金成功
      @payment.update(status: 'refunded')

      # 支払い処理の記録
      PaymentTransaction.create(
        payment_id: @payment.id,
        amount: amount,
        transaction_type: 'refund',
        status: 'completed',
        transaction_id: result[:transaction_id],
        provider_response: result[:response].to_json
      )

      # 注文ステータスの更新
      if @payment.order
        @payment.order.update(status: 'refunded')

        # 注文ログの作成
        @payment.order.order_logs.create(
          status: 'refunded',
          notes: "Payment refunded: #{amount} #{@payment.currency}",
          user_id: @user&.id
        )
      end

      true
    else
      # 返金失敗
      @error = result[:error]
      false
    end
  end

  # 支払い方法の検証
  def validate_payment_method(payment_method_id, amount)
    payment_method = PaymentMethod.find_by(id: payment_method_id)
    return false unless payment_method

    # 支払い方法の有効性チェック
    case payment_method.payment_type
    when 'credit_card'
      # クレジットカードの有効期限チェック
      if payment_method.expiry_year && payment_method.expiry_month
        expiry_date = Date.new(payment_method.expiry_year.to_i, payment_method.expiry_month.to_i, 1).end_of_month
        if expiry_date < Date.current
          @error = 'Credit card has expired'
          return false
        end
      end
    when 'paypal'
      # PayPalアカウントの検証
      # 実際の実装では、PayPal APIを使用して検証
    when 'bank_transfer'
      # 銀行口座の検証
      # 実際の実装では、銀行APIを使用して検証
    end

    true
  end

  # エラーメッセージの取得
  def error_message
    @error || @payment&.errors&.full_messages&.join(', ')
  end

  private

  # 支払い処理の実行
  def execute_payment(payment_details)
    # 実際の実装では、決済ゲートウェイAPIを使用して支払いを処理
    # ここではシミュレーションのみ

    # 支払い成功の確率（テスト用）
    success_rate = 0.9

    if rand <= success_rate
      # 支払い成功
      {
        success: true,
        transaction_id: SecureRandom.hex(10),
        response: {
          status: 'approved',
          message: 'Payment approved',
          timestamp: Time.current.iso8601
        }
      }
    else
      # 支払い失敗
      {
        success: false,
        error: 'Payment declined by processor',
        response: {
          status: 'declined',
          message: 'Payment declined',
          error_code: 'card_declined',
          timestamp: Time.current.iso8601
        }
      }
    end
  end

  # 支払い検証の実行
  def verify_payment_with_gateway(transaction_id)
    # 実際の実装では、決済ゲートウェイAPIを使用して支払いを検証
    # ここではシミュレーションのみ

    # 検証成功の確率（テスト用）
    success_rate = 0.95

    if rand <= success_rate
      # 検証成功
      {
        success: true,
        response: {
          status: 'verified',
          message: 'Payment verified',
          transaction_id: transaction_id,
          timestamp: Time.current.iso8601
        }
      }
    else
      # 検証失敗
      {
        success: false,
        error: 'Payment verification failed',
        response: {
          status: 'failed',
          message: 'Payment verification failed',
          error_code: 'verification_failed',
          timestamp: Time.current.iso8601
        }
      }
    end
  end

  # 返金処理の実行
  def execute_refund(transaction_id, amount, reason)
    # 実際の実装では、決済ゲートウェイAPIを使用して返金を処理
    # ここではシミュレーションのみ

    # 返金成功の確率（テスト用）
    success_rate = 0.95

    if rand <= success_rate
      # 返金成功
      {
        success: true,
        transaction_id: SecureRandom.hex(10),
        response: {
          status: 'approved',
          message: 'Refund approved',
          original_transaction_id: transaction_id,
          amount: amount,
          reason: reason,
          timestamp: Time.current.iso8601
        }
      }
    else
      # 返金失敗
      {
        success: false,
        error: 'Refund declined by processor',
        response: {
          status: 'declined',
          message: 'Refund declined',
          error_code: 'refund_declined',
          original_transaction_id: transaction_id,
          timestamp: Time.current.iso8601
        }
      }
    end
  end
end
