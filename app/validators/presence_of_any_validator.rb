class PresenceOfAnyValidator < ActiveModel::EachValidator
  # バリデーションを実行
  def validate_each(record, attribute, value)
    # オプションを取得
    options = {
      attributes: [],
      message: :presence_of_any_required,
      at_least: 1,
      at_most: nil
    }.merge(self.options)

    # 属性リストを取得
    attributes = Array(options[:attributes])
    attributes << attribute unless attributes.include?(attribute)

    # 存在する属性の数をカウント
    present_count = 0

    # 各属性をチェック
    attributes.each do |attr|
      # 属性値を取得
      attr_value = record.send(attr)

      # 値が存在するかチェック
      if attr_value.present?
        present_count += 1
      end
    end

    # 最小数をチェック
    if present_count < options[:at_least]
      # エラーメッセージを構築
      error_options = {
        count: options[:at_least],
        attributes: attributes.map { |attr| record.class.human_attribute_name(attr) }.join(', ')
      }

      # エラーを追加
      record.errors.add(attribute, options[:message], **error_options)
    end

    # 最大数をチェック
    if options[:at_most] && present_count > options[:at_most]
      # エラーメッセージを構築
      error_options = {
        count: options[:at_most],
        attributes: attributes.map { |attr| record.class.human_attribute_name(attr) }.join(', ')
      }

      # エラーを追加
      record.errors.add(attribute, options[:too_many_message] || :presence_of_too_many, **error_options)
    end
  end

  # ヘルパーメソッド：属性のいずれかが存在するかどうかをチェック
  def self.valid?(record, attributes, options = {})
    # 属性リストを取得
    attributes = Array(attributes)
    return false if attributes.empty?

    # 存在する属性の数をカウント
    present_count = 0

    # 各属性をチェック
    attributes.each do |attr|
      # 属性値を取得
      attr_value = record.send(attr)

      # 値が存在するかチェック
      if attr_value.present?
        present_count += 1
      end
    end

    # 最小数をチェック
    at_least = options[:at_least] || 1
    return false if present_count < at_least

    # 最大数をチェック
    at_most = options[:at_most]
    return false if at_most && present_count > at_most

    true
  end

  # ヘルパーメソッド：存在する属性を取得
  def self.present_attributes(record, attributes)
    # 属性リストを取得
    attributes = Array(attributes)
    return [] if attributes.empty?

    # 存在する属性を収集
    present_attrs = []

    # 各属性をチェック
    attributes.each do |attr|
      # 属性値を取得
      attr_value = record.send(attr)

      # 値が存在するかチェック
      if attr_value.present?
        present_attrs << attr
      end
    end

    present_attrs
  end

  # ヘルパーメソッド：存在する属性の数を取得
  def self.present_count(record, attributes)
    present_attributes(record, attributes).size
  end
end
