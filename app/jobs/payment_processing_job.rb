class PaymentProcessingJob < ApplicationJob
  queue_as :payments

  # 支払い処理を行うジョブ
  def perform(payment_id)
    # 支払い情報を取得
    payment = Payment.find_by(id: payment_id)

    # 支払いが見つからない場合は終了
    return unless payment

    # 支払いが処理済みの場合は終了
    return if payment.status == 'completed' || payment.status == 'failed' || payment.status == 'refunded'

    # 注文情報を取得
    order = payment.order

    # 注文が見つからない場合は終了
    return unless order

    # ユーザー情報を取得
    user = order.user

    # ユーザーが見つからない場合は終了
    return unless user

    # 支払い処理を開始
    begin
      # 支払いステータスを処理中に更新
      update_payment_status(payment, 'processing', 'Payment processing started')

      # 支払い方法を取得
      payment_method = get_payment_method(payment, user)

      # 支払い方法が見つからない場合はエラー
      unless payment_method
        raise "Payment method not found for payment #{payment.id}"
      end

      # 支払いゲートウェイで処理
      process_with_gateway(payment, payment_method)

      # 支払い確認
      verify_payment(payment)

      # 支払いステータスを完了に更新
      update_payment_status(payment, 'completed', 'Payment processing completed')

      # 注文ステータスを更新
      update_order_status(order, 'paid', 'Payment completed')

      # 支払い完了通知
      send_payment_notification(payment, order, user)

      # 支払い完了後の処理
      after_payment_completed(payment, order, user)
    rescue => e
      # エラーが発生した場合
      handle_error(payment, order, user, e)
    end
  end

  private

  # 支払いステータスを更新
  def update_payment_status(payment, status, notes = nil)
    # 支払いステータスを更新
    payment.update(status: status)

    # 支払いトランザクションを記録
    if defined?(PaymentTransaction) && payment.respond_to?(:payment_transactions)
      payment.payment_transactions.create(
        transaction_type: 'status_update',
        status: status,
        amount: payment.amount,
        provider_response: { notes: notes }.to_json
      )
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'payment_status_updated',
        message: "Payment #{payment.id} status updated to #{status}",
        details: {
          payment_id: payment.id,
          order_id: payment.order_id,
          status: status,
          notes: notes
        }
      )
    end

    # Railsログに記録
    Rails.logger.info("Payment #{payment.id} status updated to #{status}")
  end

  # 注文ステータスを更新
  def update_order_status(order, status, notes = nil)
    # 注文ステータスを更新
    order.update(status: status)

    # 注文ログを記録
    if defined?(OrderLog) && order.respond_to?(:order_logs)
      order.order_logs.create(
        status: status,
        notes: notes
      )
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'order_status_updated',
        message: "Order #{order.id} status updated to #{status}",
        details: {
          order_id: order.id,
          status: status,
          notes: notes
        }
      )
    end

    # Railsログに記録
    Rails.logger.info("Order #{order.id} status updated to #{status}")
  end

  # 支払い方法を取得
  def get_payment_method(payment, user)
    # 支払い方法IDが指定されている場合
    if payment.payment_method_id.present?
      # 支払い方法を取得
      PaymentMethod.find_by(id: payment.payment_method_id)
    else
      # ユーザーのデフォルト支払い方法を取得
      user.payment_methods.find_by(is_default: true)
    end
  end

  # 支払いゲートウェイで処理
  def process_with_gateway(payment, payment_method)
    # 支払いゲートウェイに応じて処理
    case payment_method.payment_type
    when 'credit_card'
      process_credit_card_payment(payment, payment_method)
    when 'paypal'
      process_paypal_payment(payment, payment_method)
    when 'bank_transfer'
      process_bank_transfer_payment(payment, payment_method)
    else
      # その他の支払い方法
      process_other_payment(payment, payment_method)
    end
  end

  # クレジットカード支払い処理
  def process_credit_card_payment(payment, payment_method)
    # 支払いサービスを使用して処理
    if defined?(PaymentService)
      payment_service = PaymentService.new(payment, payment.order, payment.order.user)
      result = payment_service.process_payment(
        order_id: payment.order_id,
        payment_method_id: payment_method.id,
        amount: payment.amount
      )

      # 支払いが失敗した場合はエラー
      unless result
        raise "Credit card payment failed: #{payment_service.error_message}"
      end
    else
      # シミュレーション用
      # 成功率90%のシミュレーション
      if rand <= 0.9
        payment.update(
          transaction_id: SecureRandom.hex(10),
          processed_at: Time.current
        )
      else
        raise "Credit card payment failed: Card declined"
      end
    end
  end

  # PayPal支払い処理
  def process_paypal_payment(payment, payment_method)
    # PayPal APIを使用して処理
    # 実際のアプリケーションでは、PayPal APIを使用して支払いを処理

    # シミュレーション用
    # 成功率95%のシミュレーション
    if rand <= 0.95
      payment.update(
        transaction_id: "PP-#{SecureRandom.hex(8)}",
        processed_at: Time.current
      )
    else
      raise "PayPal payment failed: Payment rejected"
    end
  end

  # 銀行振込支払い処理
  def process_bank_transfer_payment(payment, payment_method)
    # 銀行振込の場合は、支払い確認待ちとして処理
    payment.update(
      status: 'pending_confirmation',
      processed_at: Time.current
    )

    # 支払い確認ジョブをスケジュール
    if defined?(PaymentConfirmationJob)
      PaymentConfirmationJob.set(wait: 1.day).perform_later(payment.id)
    end
  end

  # その他の支払い処理
  def process_other_payment(payment, payment_method)
    # その他の支払い方法の場合は、支払い確認待ちとして処理
    payment.update(
      status: 'pending_confirmation',
      processed_at: Time.current
    )
  end

  # 支払い確認
  def verify_payment(payment)
    # トランザクションIDが存在する場合は確認
    if payment.transaction_id.present?
      # 支払いサービスを使用して確認
      if defined?(PaymentService)
        payment_service = PaymentService.new(payment, payment.order, payment.order.user)
        result = payment_service.verify_payment(payment.transaction_id)

        # 確認が失敗した場合はエラー
        unless result
          raise "Payment verification failed: #{payment_service.error_message}"
        end
      else
        # シミュレーション用
        # 成功率98%のシミュレーション
        if rand <= 0.98
          payment.update(verified_at: Time.current)
        else
          raise "Payment verification failed: Transaction not found"
        end
      end
    end
  end

  # 支払い完了通知
  def send_payment_notification(payment, order, user)
    # ユーザーに通知
    if defined?(NotificationService)
      NotificationService.notify(
        recipient_type: 'user',
        recipient_id: user.id,
        notification_type: 'payment_completed',
        title: 'Payment Completed',
        message: "Your payment of #{format_amount(payment.amount, payment.currency)} for order ##{order.order_number} has been completed.",
        reference_id: payment.id,
        reference_type: 'Payment'
      )
    end

    # メール送信
    if defined?(PaymentMailer)
      PaymentMailer.payment_confirmation(payment).deliver_later
    end
  end

  # 金額をフォーマット
  def format_amount(amount, currency)
    # 通貨に応じてフォーマット
    case currency
    when 'JPY'
      "¥#{amount.to_i.to_s(:delimited)}"
    when 'USD'
      "$#{amount.to_f.round(2)}"
    when 'EUR'
      "€#{amount.to_f.round(2)}"
    else
      "#{amount} #{currency}"
    end
  end

  # 支払い完了後の処理
  def after_payment_completed(payment, order, user)
    # 注文処理ジョブを実行
    if defined?(OrderProcessingJob)
      OrderProcessingJob.perform_later(order.id)
    end

    # 請求書生成
    generate_invoice(payment, order, user)

    # 分析データ更新
    update_analytics(payment, order, user)
  end

  # 請求書生成
  def generate_invoice(payment, order, user)
    # 請求書が定義されている場合
    if defined?(Invoice) && order.respond_to?(:invoice)
      # 請求書が存在しない場合は作成
      unless order.invoice
        invoice = Invoice.create(
          order_id: order.id,
          invoice_number: "INV-#{order.order_number}",
          issued_at: Time.current,
          due_at: Time.current,
          status: 'paid',
          total: order.total
        )

        # 請求書メール送信
        if defined?(InvoiceMailer)
          InvoiceMailer.send_invoice(invoice).deliver_later
        end
      end
    end
  end

  # 分析データ更新
  def update_analytics(payment, order, user)
    # 分析データ更新ジョブを実行
    if defined?(AnalyticsUpdateJob)
      AnalyticsUpdateJob.perform_later('payment_completed', {
        payment_id: payment.id,
        order_id: order.id,
        user_id: user.id,
        amount: payment.amount,
        payment_method: payment.payment_method
      })
    end
  end

  # エラー処理
  def handle_error(payment, order, user, error)
    # エラーメッセージを取得
    error_message = error.message

    # 支払いステータスを失敗に更新
    update_payment_status(payment, 'failed', "Error: #{error_message}")

    # エラーをログに記録
    Rails.logger.error("Payment processing error for payment #{payment.id}: #{error_message}")
    Rails.logger.error(error.backtrace.join("\n"))

    # エラーを通知
    if defined?(ErrorHandler)
      ErrorHandler.handle_error(error, { payment_id: payment.id, order_id: order.id })
    end

    # ユーザーに通知
    notify_payment_failure(payment, order, user, error_message)
  end

  # 支払い失敗通知
  def notify_payment_failure(payment, order, user, error_message)
    # ユーザーに通知
    if defined?(NotificationService)
      NotificationService.notify(
        recipient_type: 'user',
        recipient_id: user.id,
        notification_type: 'payment_failed',
        title: 'Payment Failed',
        message: "Your payment for order ##{order.order_number} could not be processed. Please update your payment information.",
        reference_id: payment.id,
        reference_type: 'Payment'
      )
    end

    # メール送信
    if defined?(PaymentMailer)
      PaymentMailer.payment_failed(payment, error_message).deliver_later
    end

    # 管理者に通知
    if defined?(NotificationService)
      NotificationService.notify(
        recipient_type: 'role',
        recipient_id: 'payment_admin',
        notification_type: 'payment_failed',
        title: 'Payment Failed',
        message: "Payment #{payment.id} for order #{order.id} failed: #{error_message}",
        reference_id: payment.id,
        reference_type: 'Payment'
      )
    end
  end
end
