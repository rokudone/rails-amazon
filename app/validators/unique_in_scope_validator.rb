class UniqueInScopeValidator < ActiveModel::EachValidator
  # バリデーションを実行
  def validate_each(record, attribute, value)
    # 値が空の場合は他のバリデーターに任せる
    return if value.blank? && options[:allow_blank]

    # オプションを取得
    options = {
      scope: nil,
      case_sensitive: true,
      message: :taken,
      conditions: nil,
      allow_blank: false,
      allow_nil: false,
      ignore_case: false
    }.merge(self.options)

    # 値がnilの場合
    return if value.nil? && options[:allow_nil]

    # モデルクラスを取得
    klass = record.class

    # 関連付けられたクラスを取得
    if options[:class]
      klass = options[:class].is_a?(String) ? options[:class].constantize : options[:class]
    end

    # スコープを取得
    scope_attributes = Array(options[:scope])

    # クエリを構築
    relation = klass.where(attribute => value)

    # スコープを適用
    scope_attributes.each do |scope_attribute|
      scope_value = record.send(scope_attribute)
      relation = relation.where(scope_attribute => scope_value)
    end

    # 大文字小文字を区別しない場合
    if !options[:case_sensitive] || options[:ignore_case]
      # 文字列の場合のみ適用
      if value.is_a?(String)
        column_name = klass.connection.quote_column_name(attribute)
        value_for_db = klass.connection.quote(value)
        relation = relation.where("LOWER(#{column_name}) = LOWER(#{value_for_db})")
      end
    end

    # 条件を適用
    if options[:conditions]
      conditions = options[:conditions]

      # 条件がProcの場合
      if conditions.is_a?(Proc)
        relation = conditions.call(relation)
      # 条件がハッシュの場合
      elsif conditions.is_a?(Hash)
        relation = relation.where(conditions)
      # 条件が文字列の場合
      elsif conditions.is_a?(String)
        relation = relation.where(conditions)
      end
    end

    # 自分自身を除外
    if record.persisted?
      relation = relation.where.not(id: record.id)
    end

    # 重複をチェック
    if relation.exists?
      # エラーメッセージを構築
      error_options = {}

      # スコープ属性がある場合
      if scope_attributes.any?
        scope_values = scope_attributes.map { |scope_attribute| record.send(scope_attribute) }
        error_options[:scope] = scope_attributes.zip(scope_values).to_h
      end

      # エラーを追加
      record.errors.add(attribute, options[:message], **error_options)
    end
  end

  # ヘルパーメソッド：値が一意かどうかをチェック
  def self.unique?(record, attribute, value, options = {})
    validator = new(options.merge(attributes: [attribute]))
    record_copy = record.dup
    record_copy.send("#{attribute}=", value)
    validator.validate_each(record_copy, attribute, value)
    record_copy.errors[attribute].empty?
  end

  # ヘルパーメソッド：一意な値を生成
  def self.generate_unique(record, attribute, base_value, options = {})
    # ベース値を設定
    value = base_value.to_s

    # 一意になるまで試行
    counter = 1
    while !unique?(record, attribute, value, options)
      # カウンターを追加
      value = "#{base_value}#{options[:separator] || '_'}#{counter}"
      counter += 1

      # 無限ループを防止
      break if counter > 1000
    end

    value
  end

  # ヘルパーメソッド：一意なスラグを生成
  def self.generate_unique_slug(record, attribute, base_value, options = {})
    # ベース値をスラグ化
    slug = base_value.to_s.parameterize

    # 一意になるまで試行
    counter = 1
    while !unique?(record, attribute, slug, options)
      # カウンターを追加
      slug = "#{base_value.to_s.parameterize}#{options[:separator] || '-'}#{counter}"
      counter += 1

      # 無限ループを防止
      break if counter > 1000
    end

    slug
  end

  # ヘルパーメソッド：一意なコードを生成
  def self.generate_unique_code(record, attribute, length = 6, options = {})
    # 文字セットを定義
    chars = options[:chars] || ('A'..'Z').to_a + ('0'..'9').to_a
    chars -= options[:exclude_chars] if options[:exclude_chars]

    # 一意になるまで試行
    max_attempts = options[:max_attempts] || 10
    attempts = 0

    loop do
      # ランダムコードを生成
      code = Array.new(length) { chars.sample }.join

      # 一意性をチェック
      if unique?(record, attribute, code, options)
        return code
      end

      # 試行回数をカウント
      attempts += 1

      # 最大試行回数を超えた場合
      if attempts >= max_attempts
        # 長さを増やして再試行
        length += 1
        attempts = 0
      end

      # 無限ループを防止
      break if length > 20
    end

    # 最終手段として、タイムスタンプを含むコードを生成
    "#{Array.new(length - 8) { chars.sample }.join}#{Time.now.to_i.to_s(36)[-8..-1]}"
  end
end
