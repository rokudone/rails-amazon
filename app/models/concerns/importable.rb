module Importable
  extend ActiveSupport::Concern

  included do
    # インポート設定を定義するクラス変数
    class_attribute :import_options, default: {}
    class_attribute :import_mappings, default: {}
    class_attribute :required_import_fields, default: []
    class_attribute :unique_import_fields, default: []
  end

  class_methods do
    # インポート設定を構成
    def configure_import(options = {})
      self.import_options = {
        batch_size: 100,
        validate: true,
        skip_duplicates: true
      }.merge(options)
    end

    # インポートマッピングを設定
    def map_import_fields(mappings = {})
      self.import_mappings = mappings
    end

    # 必須インポートフィールドを設定
    def require_import_fields(*fields)
      self.required_import_fields = fields
    end

    # 一意性チェック用のフィールドを設定
    def unique_by_import_fields(*fields)
      self.unique_import_fields = fields
    end

    # CSVからインポート
    def import_from_csv(file_path, options = {})
      require 'csv'

      # オプションをマージ
      import_options_with_overrides = import_options.merge(options)

      # CSVファイルを読み込み
      csv_data = CSV.read(file_path, headers: true)

      # データをインポート
      import_data(csv_data, import_options_with_overrides)
    end

    # 配列またはハッシュの配列からインポート
    def import_data(data, options = {})
      # オプションをマージ
      import_options_with_overrides = import_options.merge(options)

      # 結果を初期化
      result = {
        total: 0,
        imported: 0,
        skipped: 0,
        failed: 0,
        errors: []
      }

      # データが空の場合は終了
      if data.blank?
        result[:errors] << "No data to import"
        return result
      end

      # データを配列に変換
      records = data.is_a?(Array) ? data : [data]
      result[:total] = records.size

      # バッチサイズを取得
      batch_size = import_options_with_overrides[:batch_size] || 100

      # バッチ処理
      records.each_slice(batch_size) do |batch|
        # バッチをインポート
        batch_result = import_batch(batch, import_options_with_overrides)

        # 結果を集計
        result[:imported] += batch_result[:imported]
        result[:skipped] += batch_result[:skipped]
        result[:failed] += batch_result[:failed]
        result[:errors].concat(batch_result[:errors])
      end

      result
    end

    # バッチをインポート
    def import_batch(batch, options)
      # 結果を初期化
      result = {
        imported: 0,
        skipped: 0,
        failed: 0,
        errors: []
      }

      # レコードを準備
      records_to_import = []

      # バッチ内の各レコードを処理
      batch.each do |record_data|
        # レコードデータを正規化
        normalized_data = normalize_import_data(record_data)

        # 必須フィールドをチェック
        unless has_required_fields?(normalized_data)
          result[:failed] += 1
          result[:errors] << "Missing required fields for record: #{normalized_data.inspect}"
          next
        end

        # 重複をチェック
        if options[:skip_duplicates] && is_duplicate?(normalized_data)
          result[:skipped] += 1
          next
        end

        # レコードを構築
        record = build_record_from_import(normalized_data)

        # バリデーションを実行
        if options[:validate] && !record.valid?
          result[:failed] += 1
          result[:errors] << "Validation failed for record: #{record.errors.full_messages.join(', ')}"
          next
        end

        # インポート用のレコードに追加
        records_to_import << record
      end

      # レコードをインポート
      if records_to_import.any?
        begin
          # トランザクションを開始
          transaction do
            # レコードを保存
            records_to_import.each do |record|
              record.save(validate: false)
              result[:imported] += 1
            end
          end
        rescue => e
          # エラーが発生した場合
          result[:failed] += records_to_import.size
          result[:imported] = 0
          result[:errors] << "Error importing batch: #{e.message}"
        end
      end

      result
    end

    # インポートデータを正規化
    def normalize_import_data(data)
      # ハッシュに変換
      data_hash = data.is_a?(Hash) ? data.stringify_keys : data.to_h.stringify_keys

      # マッピングを適用
      normalized_data = {}

      if import_mappings.present?
        # マッピングが定義されている場合
        import_mappings.each do |target_field, source_field|
          # ソースフィールドが配列の場合（複数のソースフィールドを結合）
          if source_field.is_a?(Array)
            values = source_field.map { |sf| data_hash[sf.to_s] }.compact
            normalized_data[target_field.to_s] = values.join(' ')
          # ソースフィールドがProcの場合（カスタム変換）
          elsif source_field.is_a?(Proc)
            normalized_data[target_field.to_s] = source_field.call(data_hash)
          # ソースフィールドがシンボルまたは文字列の場合
          else
            normalized_data[target_field.to_s] = data_hash[source_field.to_s]
          end
        end
      else
        # マッピングが定義されていない場合はそのまま使用
        normalized_data = data_hash
      end

      normalized_data
    end

    # 必須フィールドをチェック
    def has_required_fields?(data)
      return true if required_import_fields.blank?

      required_import_fields.all? do |field|
        data[field.to_s].present?
      end
    end

    # 重複をチェック
    def is_duplicate?(data)
      return false if unique_import_fields.blank?

      # 一意性チェック用のクエリを構築
      query = where(nil)

      unique_import_fields.each do |field|
        query = query.where(field => data[field.to_s]) if data[field.to_s].present?
      end

      query.exists?
    end

    # インポートデータからレコードを構築
    def build_record_from_import(data)
      # 既存のレコードを検索
      record = find_existing_record(data)

      # 既存のレコードが見つからない場合は新規作成
      record ||= new

      # 属性を設定
      data.each do |key, value|
        # 属性が存在する場合のみ設定
        if record.respond_to?("#{key}=")
          record.send("#{key}=", value)
        end
      end

      record
    end

    # 既存のレコードを検索
    def find_existing_record(data)
      return nil if unique_import_fields.blank?

      # 一意性チェック用のクエリを構築
      query = where(nil)

      unique_import_fields.each do |field|
        query = query.where(field => data[field.to_s]) if data[field.to_s].present?
      end

      query.first
    end
  end
end
