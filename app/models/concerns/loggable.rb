module Loggable
  extend ActiveSupport::Concern

  included do
    # ログ対象のフィールドを定義するクラス変数
    class_attribute :logged_fields, default: []
    class_attribute :log_model_name, default: nil

    # コールバックを設定
    after_create :log_create
    after_update :log_update
    after_destroy :log_destroy
  end

  class_methods do
    # ログ対象のフィールドを設定
    def log_changes(*fields, model: nil)
      self.logged_fields = fields
      self.log_model_name = model
    end

    # ログモデルを取得
    def log_model
      return nil unless log_model_name
      log_model_name.to_s.classify.constantize
    rescue NameError
      nil
    end
  end

  # インスタンスメソッド

  # 作成時のログを記録
  def log_create
    return unless should_log?

    log_data = {
      loggable_type: self.class.name,
      loggable_id: self.id,
      action: 'create',
      user_id: current_user_id,
      changes: changes_for_logging,
      created_at: Time.current
    }

    create_log_entry(log_data)
  end

  # 更新時のログを記録
  def log_update
    return unless should_log?
    return unless has_relevant_changes?

    log_data = {
      loggable_type: self.class.name,
      loggable_id: self.id,
      action: 'update',
      user_id: current_user_id,
      changes: changes_for_logging,
      created_at: Time.current
    }

    create_log_entry(log_data)
  end

  # 削除時のログを記録
  def log_destroy
    return unless should_log?

    log_data = {
      loggable_type: self.class.name,
      loggable_id: self.id,
      action: 'destroy',
      user_id: current_user_id,
      changes: attributes_for_logging,
      created_at: Time.current
    }

    create_log_entry(log_data)
  end

  # カスタムアクションのログを記録
  def log_custom_action(action, data = {})
    return unless should_log?

    log_data = {
      loggable_type: self.class.name,
      loggable_id: self.id,
      action: action.to_s,
      user_id: current_user_id,
      changes: data,
      created_at: Time.current
    }

    create_log_entry(log_data)
  end

  # ログエントリを作成
  def create_log_entry(log_data)
    log_model = self.class.log_model

    if log_model
      # 専用のログモデルが定義されている場合
      log_model.create(log_data)
    elsif defined?(EventLog)
      # EventLogが定義されている場合
      EventLog.create(
        event_type: "#{self.class.name.underscore}_#{log_data[:action]}",
        message: "#{self.class.name} ##{self.id} was #{log_data[:action]}d",
        details: log_data
      )
    else
      # Railsのログに記録
      Rails.logger.info("LOG: #{log_data.to_json}")
    end
  end

  # ログを記録すべきかどうかを判定
  def should_log?
    # ログ対象のフィールドが定義されているかどうか
    self.class.logged_fields.present?
  end

  # 関連するフィールドに変更があるかどうかを判定
  def has_relevant_changes?
    return true if self.class.logged_fields.include?(:all)

    # 変更されたフィールドを取得
    changed_fields = self.saved_changes.keys.map(&:to_sym)

    # ログ対象のフィールドと変更されたフィールドの共通部分があるかどうか
    (self.class.logged_fields & changed_fields).present?
  end

  # ログ用の変更データを取得
  def changes_for_logging
    return saved_changes if self.class.logged_fields.include?(:all)

    # ログ対象のフィールドに関する変更のみを抽出
    saved_changes.select { |key, _| self.class.logged_fields.include?(key.to_sym) }
  end

  # ログ用の属性データを取得
  def attributes_for_logging
    return attributes if self.class.logged_fields.include?(:all)

    # ログ対象のフィールドに関する属性のみを抽出
    attributes.select { |key, _| self.class.logged_fields.include?(key.to_sym) }
  end

  # 現在のユーザーIDを取得
  def current_user_id
    # Current.userが定義されている場合
    return Current.user.id if defined?(Current) && Current.respond_to?(:user) && Current.user

    # Thread.currentが定義されている場合
    return Thread.current[:user_id] if Thread.current[:user_id]

    # 関連するユーザーIDがある場合
    return user_id if respond_to?(:user_id) && user_id

    # デフォルト値
    nil
  end

  # 変更履歴を取得
  def change_history
    log_model = self.class.log_model

    if log_model
      # 専用のログモデルが定義されている場合
      log_model.where(loggable_type: self.class.name, loggable_id: self.id).order(created_at: :desc)
    elsif defined?(EventLog)
      # EventLogが定義されている場合
      EventLog.where(
        "details->>'loggable_type' = ? AND details->>'loggable_id' = ?",
        self.class.name,
        self.id.to_s
      ).order(created_at: :desc)
    else
      # ログが記録されていない場合は空の配列を返す
      []
    end
  end
end
