module Versionable
  extend ActiveSupport::Concern

  included do
    # バージョン関連の設定を定義するクラス変数
    class_attribute :version_options, default: {}

    # バージョン関連の関連付けを定義
    has_many :versions, -> { order(version_number: :desc) },
             class_name: version_class_name,
             foreign_key: :versionable_id,
             dependent: :destroy,
             as: :versionable

    # コールバックを設定
    after_create :create_initial_version
    before_update :create_version_on_update, if: :should_create_version?
  end

  class_methods do
    # バージョン設定を構成
    def versionable(options = {})
      self.version_options = {
        included_fields: nil,
        excluded_fields: %w[id created_at updated_at],
        max_versions: nil,
        version_class: nil
      }.merge(options)
    end

    # バージョンクラス名を取得
    def version_class_name
      version_options[:version_class] || "#{name}Version"
    end

    # バージョンクラスを取得
    def version_class
      version_class_name.constantize
    rescue NameError
      raise "Version class #{version_class_name} not found. Please create it or specify a custom class with version_class option."
    end
  end

  # インスタンスメソッド

  # 初期バージョンを作成
  def create_initial_version
    return unless should_create_version?

    # バージョンを作成
    create_version(1)
  end

  # 更新時にバージョンを作成
  def create_version_on_update
    # 最新のバージョン番号を取得
    last_version = versions.first
    next_version_number = last_version ? last_version.version_number + 1 : 1

    # バージョンを作成
    create_version(next_version_number)

    # 最大バージョン数を超えた場合は古いバージョンを削除
    prune_old_versions
  end

  # バージョンを作成
  def create_version(version_number)
    # バージョンデータを準備
    version_data = {
      versionable_type: self.class.name,
      versionable_id: id,
      version_number: version_number,
      data: version_attributes,
      created_at: Time.current
    }

    # ユーザーIDが設定されている場合は追加
    version_data[:user_id] = Current.user.id if defined?(Current) && Current.respond_to?(:user) && Current.user

    # バージョンを作成
    self.class.version_class.create(version_data)
  end

  # バージョン属性を取得
  def version_attributes
    # 属性を取得
    attrs = attributes.dup

    # 除外フィールドを削除
    if version_options[:excluded_fields].present?
      version_options[:excluded_fields].each do |field|
        attrs.delete(field)
      end
    end

    # 含めるフィールドのみを保持
    if version_options[:included_fields].present?
      attrs.slice!(*version_options[:included_fields])
    end

    attrs
  end

  # 古いバージョンを削除
  def prune_old_versions
    return unless version_options[:max_versions]

    # 最大バージョン数を超えた場合は古いバージョンを削除
    excess_versions = versions.offset(version_options[:max_versions])
    excess_versions.destroy_all if excess_versions.any?
  end

  # バージョンを作成すべきかどうかをチェック
  def should_create_version?
    # バージョンクラスが存在するかどうかをチェック
    begin
      self.class.version_class
    rescue
      return false
    end

    # 含めるフィールドが指定されている場合
    if version_options[:included_fields].present?
      # 含めるフィールドに変更があるかどうかをチェック
      return version_options[:included_fields].any? do |field|
        respond_to?("#{field}_changed?") && send("#{field}_changed?")
      end
    end

    # 除外フィールド以外に変更があるかどうかをチェック
    excluded_fields = version_options[:excluded_fields] || []
    changed_fields = changed.map(&:to_s)

    (changed_fields - excluded_fields).any?
  end

  # 特定のバージョンを取得
  def get_version(version_number)
    versions.find_by(version_number: version_number)
  end

  # 最新のバージョンを取得
  def latest_version
    versions.first
  end

  # 特定のバージョンに復元
  def revert_to(version_number)
    # バージョンを取得
    version = get_version(version_number)
    return false unless version

    # バージョンデータを取得
    version_data = version.data

    # 属性を更新
    assign_attributes(version_data)

    # 保存
    save
  end

  # バージョン間の差分を取得
  def version_diff(from_version, to_version)
    # バージョンを取得
    from = get_version(from_version)
    to = get_version(to_version)

    return {} unless from && to

    # 差分を計算
    diff = {}

    # 両方のバージョンに存在するキーを取得
    keys = (from.data.keys | to.data.keys)

    # 各キーの差分を計算
    keys.each do |key|
      from_value = from.data[key]
      to_value = to.data[key]

      # 値が異なる場合は差分に追加
      if from_value != to_value
        diff[key] = {
          from: from_value,
          to: to_value
        }
      end
    end

    diff
  end

  # 現在の状態と特定のバージョンとの差分を取得
  def diff_with_version(version_number)
    # バージョンを取得
    version = get_version(version_number)
    return {} unless version

    # 差分を計算
    diff = {}

    # バージョンデータを取得
    version_data = version.data

    # 各キーの差分を計算
    version_data.each do |key, value|
      current_value = send(key) if respond_to?(key)

      # 値が異なる場合は差分に追加
      if current_value != value
        diff[key] = {
          from: value,
          to: current_value
        }
      end
    end

    diff
  end
end
