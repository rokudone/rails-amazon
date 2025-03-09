module EventDispatcher
  class << self
    # イベントを発行
    def publish(event_name, payload = {})
      # イベント名を正規化
      normalized_event_name = normalize_event_name(event_name)

      # イベントオブジェクトを作成
      event = create_event(normalized_event_name, payload)

      # イベントをログに記録
      log_event(event)

      # イベントを処理
      process_event(event)

      # イベントをデータベースに記録
      persist_event(event)

      # イベントを非同期で処理
      process_event_async(event)

      event
    end

    # イベントを購読
    def subscribe(event_pattern, handler = nil, &block)
      # イベントパターンを正規化
      normalized_pattern = normalize_event_name(event_pattern)

      # ハンドラーを取得
      handler = block if block_given?

      # ハンドラーが指定されていない場合はエラー
      unless handler
        raise ArgumentError, "Event handler is required"
      end

      # 購読情報を作成
      subscription = {
        pattern: normalized_pattern,
        handler: handler
      }

      # 購読情報を保存
      subscriptions << subscription

      # 購読IDを返す
      subscription.object_id
    end

    # イベント購読を解除
    def unsubscribe(subscription_id)
      # 購読情報を検索
      subscription = subscriptions.find { |s| s.object_id == subscription_id }

      # 購読情報が見つからない場合はfalseを返す
      return false unless subscription

      # 購読情報を削除
      subscriptions.delete(subscription)

      true
    end

    # 全てのイベント購読を解除
    def unsubscribe_all
      # 購読情報をクリア
      subscriptions.clear

      true
    end

    # イベント購読リストを取得
    def list_subscriptions
      # 購読情報のコピーを返す
      subscriptions.map do |subscription|
        {
          id: subscription.object_id,
          pattern: subscription[:pattern],
          handler: subscription[:handler].to_s
        }
      end
    end

    # イベント履歴を取得
    def event_history(limit = 10)
      # イベント履歴のコピーを返す
      event_log.last(limit)
    end

    # イベント履歴をクリア
    def clear_history
      # イベント履歴をクリア
      event_log.clear

      true
    end

    private

    # イベント名を正規化
    def normalize_event_name(event_name)
      event_name.to_s.downcase
    end

    # イベントオブジェクトを作成
    def create_event(event_name, payload)
      {
        id: SecureRandom.uuid,
        name: event_name,
        payload: payload,
        timestamp: Time.current
      }
    end

    # イベントをログに記録
    def log_event(event)
      # イベント履歴に追加
      event_log << event

      # イベント履歴が長すぎる場合は古いイベントを削除
      event_log.shift if event_log.size > max_event_history

      # ログにも記録
      if defined?(LogManager)
        LogManager.event(event[:name], event[:payload])
      else
        Rails.logger.info("Event: #{event[:name]} #{event[:payload].inspect}")
      end
    end

    # イベントを処理
    def process_event(event)
      # イベントに一致する購読情報を検索
      matching_subscriptions = find_matching_subscriptions(event[:name])

      # 一致する購読情報がない場合は何もしない
      return if matching_subscriptions.empty?

      # 各購読情報のハンドラーを実行
      matching_subscriptions.each do |subscription|
        begin
          execute_handler(subscription[:handler], event)
        rescue => e
          # ハンドラーの実行に失敗した場合はログに記録
          Rails.logger.error("Error processing event #{event[:name]}: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
        end
      end
    end

    # イベントを非同期で処理
    def process_event_async(event)
      # EventProcessorJobが定義されている場合は非同期で処理
      if defined?(EventProcessorJob)
        EventProcessorJob.perform_later(event)
      end
    end

    # イベントをデータベースに記録
    def persist_event(event)
      # Eventモデルが定義されている場合はデータベースに記録
      if defined?(Event)
        Event.create(
          event_type: event[:name],
          data: event[:payload],
          occurred_at: event[:timestamp]
        )
      end
    end

    # イベント名に一致する購読情報を検索
    def find_matching_subscriptions(event_name)
      subscriptions.select do |subscription|
        pattern_matches?(subscription[:pattern], event_name)
      end
    end

    # パターンがイベント名に一致するかチェック
    def pattern_matches?(pattern, event_name)
      # パターンが '*' の場合は全てのイベントに一致
      return true if pattern == '*'

      # パターンが 'namespace.*' の形式の場合は前方一致
      if pattern.end_with?('.*')
        namespace = pattern[0...-2]
        return event_name.start_with?(namespace)
      end

      # それ以外の場合は完全一致
      pattern == event_name
    end

    # ハンドラーを実行
    def execute_handler(handler, event)
      if handler.is_a?(Proc)
        # Procの場合は直接実行
        handler.call(event)
      elsif handler.is_a?(Class) && handler.method_defined?(:handle)
        # クラスの場合はインスタンスを作成して実行
        handler.new.handle(event)
      elsif handler.is_a?(Symbol) || handler.is_a?(String)
        # シンボルまたは文字列の場合はメソッド名として実行
        send(handler, event)
      else
        # それ以外の場合はエラー
        raise ArgumentError, "Invalid event handler: #{handler}"
      end
    end

    # 購読情報リスト
    def subscriptions
      @subscriptions ||= []
    end

    # イベント履歴
    def event_log
      @event_log ||= []
    end

    # イベント履歴の最大サイズ
    def max_event_history
      100
    end
  end

  # イベントハンドラーの基底クラス
  class EventHandler
    # イベントを処理
    def handle(event)
      # イベント名に基づいてメソッドを呼び出し
      method_name = "on_#{event[:name].gsub('.', '_')}"

      if respond_to?(method_name)
        send(method_name, event[:payload])
      else
        on_event(event[:name], event[:payload])
      end
    end

    # デフォルトのイベントハンドラー
    def on_event(event_name, payload)
      # サブクラスでオーバーライド
    end
  end

  # イベントリスナーモジュール
  module EventListener
    extend ActiveSupport::Concern

    included do
      # クラスメソッドを追加
      class_attribute :event_handlers, default: {}

      # インスタンス初期化時にイベントを購読
      after_initialize :subscribe_to_events

      # インスタンス破棄時にイベント購読を解除
      before_destroy :unsubscribe_from_events
    end

    # クラスメソッド
    class_methods do
      # イベントハンドラーを定義
      def on_event(event_pattern, method_name = nil, &block)
        # メソッド名またはブロックが必要
        handler = if block_given?
                    block
                  elsif method_name
                    method_name
                  else
                    "on_#{event_pattern.gsub('.', '_')}"
                  end

        # イベントハンドラーを登録
        event_handlers[event_pattern] = handler
      end
    end

    # イベントを購読
    def subscribe_to_events
      @subscription_ids = []

      # 各イベントハンドラーを購読
      self.class.event_handlers.each do |event_pattern, handler|
        # ハンドラーがシンボルまたは文字列の場合はメソッド名として扱う
        if handler.is_a?(Symbol) || handler.is_a?(String)
          method_name = handler
          handler = ->(event) { send(method_name, event[:payload]) }
        end

        # イベントを購読
        subscription_id = EventDispatcher.subscribe(event_pattern, handler)

        # 購読IDを保存
        @subscription_ids << subscription_id
      end
    end

    # イベント購読を解除
    def unsubscribe_from_events
      # 各購読を解除
      @subscription_ids.each do |subscription_id|
        EventDispatcher.unsubscribe(subscription_id)
      end

      # 購読IDをクリア
      @subscription_ids = []
    end
  end
end
