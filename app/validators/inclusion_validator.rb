class InclusionValidator < ActiveModel::EachValidator
  # バリデーションを実行
  def validate_each(record, attribute, value)
    # 値が空の場合は他のバリデーターに任せる
    return if value.blank? && options[:allow_blank]
    return if value.nil? && options[:allow_nil]

    # オプションを取得
    options = {
      in: nil,
      within: nil,
      allow_blank: false,
      allow_nil: false,
      message: :inclusion
    }.merge(self.options)

    # 許容値リストを取得
    allowed_values = options[:in] || options[:within]

    # 許容値リストが存在しない場合
    unless allowed_values
      raise ArgumentError, "Include either :in or :within option in inclusion validator"
    end

    # 許容値リストが列挙可能でない場合
    unless allowed_values.respond_to?(:include?)
      raise ArgumentError, "The :in or :within option must respond to include?"
    end

    # 値が許容値リストに含まれているかチェック
    unless allowed_values.include?(value)
      # エラーメッセージを構築
      error_options = { value: value }

      # 許容値リストが表示可能な場合
      if allowed_values.respond_to?(:to_s)
        error_options[:list] = allowed_values.to_s
      end

      # エラーを追加
      record.errors.add(attribute, options[:message], **error_options)
    end
  end

  # ヘルパーメソッド：値が許容値リストに含まれているかどうかをチェック
  def self.valid?(value, allowed_values, options = {})
    # 値が空の場合
    return true if value.blank? && options[:allow_blank]
    return true if value.nil? && options[:allow_nil]

    # 許容値リストが存在しない場合
    return false unless allowed_values

    # 許容値リストが列挙可能でない場合
    return false unless allowed_values.respond_to?(:include?)

    # 値が許容値リストに含まれているかチェック
    allowed_values.include?(value)
  end

  # ヘルパーメソッド：値が許容値リストに含まれていない場合はデフォルト値を返す
  def self.ensure_included(value, allowed_values, default = nil)
    # 許容値リストが存在しない場合
    return default unless allowed_values

    # 許容値リストが列挙可能でない場合
    return default unless allowed_values.respond_to?(:include?)

    # 値が許容値リストに含まれているかチェック
    allowed_values.include?(value) ? value : default
  end

  # ヘルパーメソッド：値が許容値リストに含まれていない場合は最も近い値を返す
  def self.closest_match(value, allowed_values)
    # 許容値リストが存在しない場合
    return nil unless allowed_values

    # 許容値リストが列挙可能でない場合
    return nil unless allowed_values.respond_to?(:to_a)

    # 値が許容値リストに含まれている場合
    return value if allowed_values.include?(value)

    # 文字列の場合
    if value.is_a?(String)
      # 最も類似度の高い値を検索
      allowed_values.to_a.min_by { |allowed_value| levenshtein_distance(value, allowed_value.to_s) }
    # 数値の場合
    elsif value.is_a?(Numeric)
      # 最も近い値を検索
      allowed_values.to_a.min_by { |allowed_value| (value - allowed_value.to_f).abs }
    else
      nil
    end
  end

  # ヘルパーメソッド：Levenshtein距離を計算
  def self.levenshtein_distance(str1, str2)
    # 文字列が同じ場合
    return 0 if str1 == str2

    # 文字列の長さを取得
    len1 = str1.length
    len2 = str2.length

    # 一方の文字列が空の場合
    return len2 if len1 == 0
    return len1 if len2 == 0

    # 距離行列を初期化
    matrix = Array.new(len1 + 1) { Array.new(len2 + 1) }

    # 行列の最初の行と列を初期化
    (0..len1).each { |i| matrix[i][0] = i }
    (0..len2).each { |j| matrix[0][j] = j }

    # 距離を計算
    (1..len1).each do |i|
      (1..len2).each do |j|
        cost = str1[i-1] == str2[j-1] ? 0 : 1
        matrix[i][j] = [
          matrix[i-1][j] + 1,      # 削除
          matrix[i][j-1] + 1,      # 挿入
          matrix[i-1][j-1] + cost  # 置換
        ].min
      end
    end

    # 距離を返す
    matrix[len1][len2]
  end
end
