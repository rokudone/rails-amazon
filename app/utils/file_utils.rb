module FileUtils
  class << self
    # ファイルの拡張子を取得
    def get_extension(filename)
      return nil if filename.nil? || filename.empty?

      File.extname(filename.to_s).downcase.delete('.')
    end

    # ファイルのMIMEタイプを取得
    def get_mime_type(filename)
      return nil if filename.nil? || filename.empty?

      ext = get_extension(filename)
      return nil if ext.nil?

      mime_types = {
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'bmp' => 'image/bmp',
        'svg' => 'image/svg+xml',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        'doc' => 'application/msword',
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xls' => 'application/vnd.ms-excel',
        'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'ppt' => 'application/vnd.ms-powerpoint',
        'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'txt' => 'text/plain',
        'html' => 'text/html',
        'htm' => 'text/html',
        'css' => 'text/css',
        'js' => 'application/javascript',
        'json' => 'application/json',
        'xml' => 'application/xml',
        'zip' => 'application/zip',
        'rar' => 'application/x-rar-compressed',
        'tar' => 'application/x-tar',
        'gz' => 'application/gzip',
        'mp3' => 'audio/mpeg',
        'mp4' => 'video/mp4',
        'avi' => 'video/x-msvideo',
        'mov' => 'video/quicktime',
        'csv' => 'text/csv'
      }

      mime_types[ext] || 'application/octet-stream'
    end

    # ファイルサイズを人間が読みやすい形式に変換
    def format_file_size(size_in_bytes)
      return '0 B' if size_in_bytes.nil? || size_in_bytes == 0

      size = size_in_bytes.to_f
      units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB']

      i = 0
      while size >= 1024 && i < units.length - 1
        size /= 1024
        i += 1
      end

      "#{size.round(2)} #{units[i]}"
    end

    # ファイルが画像かどうかを確認
    def is_image?(filename)
      return false if filename.nil? || filename.empty?

      image_extensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'svg', 'webp']
      image_extensions.include?(get_extension(filename))
    end

    # ファイルがドキュメントかどうかを確認
    def is_document?(filename)
      return false if filename.nil? || filename.empty?

      document_extensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf']
      document_extensions.include?(get_extension(filename))
    end

    # ファイルが圧縮ファイルかどうかを確認
    def is_archive?(filename)
      return false if filename.nil? || filename.empty?

      archive_extensions = ['zip', 'rar', 'tar', 'gz', '7z']
      archive_extensions.include?(get_extension(filename))
    end

    # ファイルが音声ファイルかどうかを確認
    def is_audio?(filename)
      return false if filename.nil? || filename.empty?

      audio_extensions = ['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a']
      audio_extensions.include?(get_extension(filename))
    end

    # ファイルが動画ファイルかどうかを確認
    def is_video?(filename)
      return false if filename.nil? || filename.empty?

      video_extensions = ['mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm']
      video_extensions.include?(get_extension(filename))
    end

    # ファイル名から安全なファイル名を生成
    def sanitize_filename(filename)
      return nil if filename.nil? || filename.empty?

      # 拡張子を取得
      extension = File.extname(filename)
      basename = File.basename(filename, extension)

      # 安全でない文字を削除または置換
      safe_basename = basename.gsub(/[^0-9A-Za-z\-_]/, '_')

      # 空のファイル名の場合はデフォルト値を設定
      safe_basename = 'file' if safe_basename.empty?

      "#{safe_basename}#{extension}"
    end

    # ファイル名が一意になるように連番を付加
    def unique_filename(filename, existing_files)
      return filename if existing_files.nil? || existing_files.empty? || !existing_files.include?(filename)

      extension = File.extname(filename)
      basename = File.basename(filename, extension)

      counter = 1
      new_filename = "#{basename}_#{counter}#{extension}"

      while existing_files.include?(new_filename)
        counter += 1
        new_filename = "#{basename}_#{counter}#{extension}"
      end

      new_filename
    end

    # ファイルのチェックサムを計算
    def calculate_checksum(file_path, algorithm = 'md5')
      return nil unless File.exist?(file_path)

      case algorithm.downcase
      when 'md5'
        Digest::MD5.file(file_path).hexdigest
      when 'sha1'
        Digest::SHA1.file(file_path).hexdigest
      when 'sha256'
        Digest::SHA256.file(file_path).hexdigest
      else
        Digest::MD5.file(file_path).hexdigest
      end
    end

    # ファイルの内容からMIMEタイプを検出
    def detect_mime_type(file_path)
      return nil unless File.exist?(file_path)

      # ファイルの先頭バイトを読み込む
      magic_bytes = File.open(file_path, 'rb') { |f| f.read(8) }

      # マジックナンバーに基づいてMIMEタイプを判定
      if magic_bytes.start_with?("\xFF\xD8\xFF")
        'image/jpeg'
      elsif magic_bytes.start_with?("\x89PNG\r\n\x1A\n")
        'image/png'
      elsif magic_bytes.start_with?("GIF87a") || magic_bytes.start_with?("GIF89a")
        'image/gif'
      elsif magic_bytes.start_with?("%PDF")
        'application/pdf'
      elsif magic_bytes.start_with?("PK\x03\x04")
        'application/zip'
      else
        # 拡張子からMIMEタイプを推測
        get_mime_type(file_path)
      end
    end

    # ファイルの作成日時を取得
    def get_creation_time(file_path)
      return nil unless File.exist?(file_path)

      File.birthtime(file_path)
    rescue
      File.ctime(file_path)
    end

    # ファイルの更新日時を取得
    def get_modification_time(file_path)
      return nil unless File.exist?(file_path)

      File.mtime(file_path)
    end

    # ファイルのアクセス日時を取得
    def get_access_time(file_path)
      return nil unless File.exist?(file_path)

      File.atime(file_path)
    end

    # ファイルの所有者を取得
    def get_owner(file_path)
      return nil unless File.exist?(file_path)

      Etc.getpwuid(File.stat(file_path).uid).name
    rescue
      nil
    end

    # ファイルのグループを取得
    def get_group(file_path)
      return nil unless File.exist?(file_path)

      Etc.getgrgid(File.stat(file_path).gid).name
    rescue
      nil
    end

    # ファイルのパーミッションを取得
    def get_permissions(file_path)
      return nil unless File.exist?(file_path)

      sprintf("%o", File.stat(file_path).mode)[-3..-1]
    end

    # ファイルの行数を取得
    def count_lines(file_path)
      return 0 unless File.exist?(file_path)

      File.foreach(file_path).count
    rescue
      0
    end

    # テキストファイルの文字エンコーディングを検出
    def detect_encoding(file_path)
      return nil unless File.exist?(file_path)

      # 簡易的なエンコーディング検出
      # 実際のアプリケーションでは、charlock_holmes や rchardet などのgemを使用することを推奨
      begin
        File.open(file_path, 'rb') do |f|
          bytes = f.read(4)
          if bytes.start_with?("\xEF\xBB\xBF")
            'UTF-8 with BOM'
          elsif bytes.start_with?("\xFF\xFE")
            'UTF-16LE'
          elsif bytes.start_with?("\xFE\xFF")
            'UTF-16BE'
          else
            'UTF-8 or other'
          end
        end
      rescue
        'Unknown'
      end
    end
  end
end
