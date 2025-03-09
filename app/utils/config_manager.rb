module ConfigManager
  class << self
    # 設定を取得
    def get(key, default = nil)
      # キーを正規化
      normalized_key = normalize_key(key)

      # 設定値を取得
      value = fetch_config_value(normalized_key)

      # 値が見つからない場合はデフォルト値を返す
      value.nil? ? default : value
    end

    # 設定を設定
    def set(key, value)
      # キーを正規化
      normalized_key = normalize_key(key)

      # 設定値を設定
      set_config_value(normalized_key, value)

      # 設定値を返す
      value
    end

    # 設定が存在するかチェック
    def exists?(key)
      # キーを正規化
      normalized_key = normalize_key(key)

      # 設定値が存在するかチェック
      !fetch_config_value(normalized_key).nil?
    end

    # 設定を削除
    def delete(key)
      # キーを正規化
      normalized_key = normalize_key(key)

      # 設定値を削除
      delete_config_value(normalized_key)
    end

    # 全ての設定を取得
    def all
      # 全ての設定値を取得
      all_config_values
    end

    # 設定をリロード
    def reload
      # 設定をリロード
      reload_config
    end

    # 設定を検証
    def validate
      # 設定を検証
      validate_config
    end

    # 環境別の設定を取得
    def for_environment(environment = nil)
      # 環境を決定
      env = environment || Rails.env

      # 環境別の設定を取得
      environment_config(env)
    end

    # 設定ファイルからロード
    def load_from_file(file_path)
      # ファイルが存在するかチェック
      unless File.exist?(file_path)
        raise "Config file not found: #{file_path}"
      end

      # ファイルの拡張子を取得
      extension = File.extname(file_path).delete('.')

      # ファイル形式に応じて読み込み
      config = case extension.downcase
               when 'yml', 'yaml'
                 YAML.load_file(file_path)
               when 'json'
                 JSON.parse(File.read(file_path))
               else
                 raise "Unsupported config file format: #{extension}"
               end

      # 設定をマージ
      merge_config(config)
    end

    # 設定をファイルに保存
    def save_to_file(file_path, format = :yaml)
      # 全ての設定値を取得
      config = all_config_values

      # ファイル形式に応じて保存
      case format.to_sym
      when :yaml
        File.write(file_path, config.to_yaml)
      when :json
        File.write(file_path, JSON.pretty_generate(config))
      else
        raise "Unsupported config file format: #{format}"
      end
    end

    # 設定をマージ
    def merge(config)
      # 設定をマージ
      merge_config(config)
    end

    # 設定をリセット
    def reset
      # 設定をリセット
      reset_config
    end

    # 設定を暗号化
    def encrypt(key, value)
      # 暗号化キーを取得
      encryption_key = Rails.application.credentials.secret_key_base

      # 値を暗号化
      encryptor = ActiveSupport::MessageEncryptor.new(encryption_key[0, 32])
      encrypted_value = encryptor.encrypt_and_sign(value.to_s)

      # 暗号化された値を設定
      set("encrypted.#{key}", encrypted_value)

      encrypted_value
    end

    # 設定を復号化
    def decrypt(key)
      # 暗号化された値を取得
      encrypted_value = get("encrypted.#{key}")
      return nil if encrypted_value.nil?

      # 暗号化キーを取得
      encryption_key = Rails.application.credentials.secret_key_base

      # 値を復号化
      encryptor = ActiveSupport::MessageEncryptor.new(encryption_key[0, 32])
      encryptor.decrypt_and_verify(encrypted_value)
    rescue
      nil
    end

    private

    # キーを正規化
    def normalize_key(key)
      key.to_s
    end

    # 設定値を取得
    def fetch_config_value(key)
      # システム設定からの取得を試みる
      if defined?(SystemConfig)
        config = SystemConfig.find_by(key: key)
        return config.value if config
      end

      # 環境変数からの取得を試みる
      env_key = key.upcase.gsub('.', '_')
      return ENV[env_key] if ENV.key?(env_key)

      # Rails設定からの取得を試みる
      begin
        parts = key.split('.')
        value = Rails.application.config
        parts.each do |part|
          value = value.send(part)
        end
        return value
      rescue
        nil
      end
    end

    # 設定値を設定
    def set_config_value(key, value)
      # システム設定に保存
      if defined?(SystemConfig)
        config = SystemConfig.find_or_initialize_by(key: key)
        config.value = value
        config.save
      end

      # 環境変数に設定
      env_key = key.upcase.gsub('.', '_')
      ENV[env_key] = value.to_s

      # Rails設定に設定
      begin
        parts = key.split('.')
        config = Rails.application.config
        parts[0...-1].each do |part|
          config = config.send(part)
        end
        config.send("#{parts.last}=", value)
      rescue
        nil
      end
    end

    # 設定値を削除
    def delete_config_value(key)
      # システム設定から削除
      if defined?(SystemConfig)
        SystemConfig.where(key: key).destroy_all
      end

      # 環境変数から削除
      env_key = key.upcase.gsub('.', '_')
      ENV.delete(env_key)
    end

    # 全ての設定値を取得
    def all_config_values
      config = {}

      # システム設定から取得
      if defined?(SystemConfig)
        SystemConfig.all.each do |system_config|
          config[system_config.key] = system_config.value
        end
      end

      # 環境変数から取得
      ENV.each do |key, value|
        normalized_key = key.downcase.gsub('_', '.')
        config[normalized_key] = value
      end

      config
    end

    # 設定をリロード
    def reload_config
      # システム設定をリロード
      if defined?(SystemConfig)
        # キャッシュをクリア
        SystemConfig.uncached do
          SystemConfig.all.reload
        end
      end

      # Rails設定をリロード
      Rails.application.config.reload_configuration
    end

    # 設定を検証
    def validate_config
      # 必須設定のリスト
      required_configs = [
        'database.host',
        'database.username',
        'database.password',
        'database.name'
      ]

      # 必須設定が存在するかチェック
      missing_configs = required_configs.select { |key| !exists?(key) }

      # 不足している設定がある場合はエラー
      if missing_configs.any?
        raise "Missing required configurations: #{missing_configs.join(', ')}"
      end

      true
    end

    # 環境別の設定を取得
    def environment_config(environment)
      config = {}

      # システム設定から環境別の設定を取得
      if defined?(SystemConfig)
        SystemConfig.where("key LIKE ?", "#{environment}.%").each do |system_config|
          key = system_config.key.sub("#{environment}.", '')
          config[key] = system_config.value
        end
      end

      # 環境変数から環境別の設定を取得
      ENV.each do |key, value|
        if key.start_with?("#{environment.upcase}_")
          normalized_key = key.sub("#{environment.upcase}_", '').downcase.gsub('_', '.')
          config[normalized_key] = value
        end
      end

      config
    end

    # 設定をマージ
    def merge_config(config)
      # 設定をマージ
      config.each do |key, value|
        set(key, value)
      end

      config
    end

    # 設定をリセット
    def reset_config
      # システム設定をリセット
      if defined?(SystemConfig)
        SystemConfig.destroy_all
      end
    end
  end
end
