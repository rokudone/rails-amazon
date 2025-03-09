module Archivable
  extend ActiveSupport::Concern

  included do
    # アーカイブ関連の設定を定義するクラス変数
    class_attribute :archive_options, default: {}

    # スコープを定義
    scope :archived, -> { where.not(archived_at: nil) }
    scope :not_archived, -> { where(archived_at: nil) }

    # バリデーションを設定
    validate :validate_archive_status, if: -> { archive_options[:validate_status] }
  end

  class_methods do
    # アーカイブ設定を構成
    def archivable(options = {})
      self.archive_options = {
        column: :archived_at,
        validate_status: false,
        with_deleted: false
      }.merge(options)

      # アーカイブカラムが存在するかチェック
      unless column_names.include?(archive_options[:column].to_s)
        raise "Column #{archive_options[:column]} does not exist in #{table_name} table. Please add it with `add_column :#{table_name}, :#{archive_options[:column]}, :datetime, null: true`"
      end
    end

    # デフォルトスコープを設定
    def default_scope_with_archive
      return unless archive_options[:with_deleted]

      default_scope { where(archived_at: nil) }
    end
  end

  # インスタンスメソッド

  # アーカイブ状態をチェック
  def archived?
    send(archive_options[:column]).present?
  end

  # アーカイブする
  def archive
    return false if archived?

    # アーカイブ日時を設定
    self.send("#{archive_options[:column]}=", Time.current)

    # 保存
    save
  end

  # アーカイブ解除する
  def unarchive
    return false unless archived?

    # アーカイブ日時をクリア
    self.send("#{archive_options[:column]}=", nil)

    # 保存
    save
  end

  # アーカイブ日時を取得
  def archived_at
    send(archive_options[:column])
  end

  # アーカイブ状態を切り替える
  def toggle_archive
    archived? ? unarchive : archive
  end

  # アーカイブ状態をバリデーション
  def validate_archive_status
    # アーカイブ状態のレコードは更新できない
    if archived? && changed? && !changes.key?(archive_options[:column].to_s)
      errors.add(:base, "Archived record cannot be modified")
    end
  end

  # アーカイブ状態を無視して更新
  def update_ignoring_archive_status(attributes)
    # 一時的にバリデーションを無効化
    self.class.skip_callback(:validate, :if, :validate_archive_status)

    # 更新
    result = update(attributes)

    # バリデーションを再有効化
    self.class.set_callback(:validate, :if, :validate_archive_status)

    result
  end

  # アーカイブ状態を無視して保存
  def save_ignoring_archive_status
    # 一時的にバリデーションを無効化
    self.class.skip_callback(:validate, :if, :validate_archive_status)

    # 保存
    result = save

    # バリデーションを再有効化
    self.class.set_callback(:validate, :if, :validate_archive_status)

    result
  end

  # 完全に削除
  def really_destroy!
    # アーカイブ状態を無視して削除
    destroy
  end

  # オーバーライド：削除
  def destroy
    # アーカイブモードが有効な場合はアーカイブする
    if archive_options[:with_deleted]
      archive
    else
      super
    end
  end

  # オーバーライド：削除！
  def destroy!
    # アーカイブモードが有効な場合はアーカイブする
    if archive_options[:with_deleted]
      archive || raise(ActiveRecord::RecordNotDestroyed.new("Failed to archive the record", self))
    else
      super
    end
  end
end
