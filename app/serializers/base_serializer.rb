class BaseSerializer
  attr_reader :object, :options

  def initialize(object, options = {})
    @object = object
    @options = options || {}
  end

  # オブジェクトをシリアライズ
  def serialize
    return nil if @object.nil?

    if @object.is_a?(Enumerable)
      serialize_collection
    else
      serialize_object
    end
  end

  # コレクションをシリアライズ
  def serialize_collection
    @object.map { |item| serialize_object(item) }
  end

  # 単一オブジェクトをシリアライズ
  def serialize_object(obj = nil)
    obj ||= @object

    # 属性をシリアライズ
    serialized = serialize_attributes(obj)

    # 関連データを含める
    if include_associations?
      serialized.merge!(serialize_associations(obj))
    end

    # メタデータを含める
    if include_meta?
      serialized[:meta] = meta_data(obj)
    end

    serialized
  end

  # 属性をシリアライズ
  def serialize_attributes(obj)
    attributes = {}

    # 属性リストが定義されていない場合は空のハッシュを返す
    return attributes unless self.class.respond_to?(:attributes_to_serialize)

    # 属性リストを取得
    attrs = self.class.attributes_to_serialize

    # 各属性をシリアライズ
    attrs.each do |attr_name, options|
      # 属性が除外されているかチェック
      next if excluded_attribute?(attr_name)

      # 属性値を取得
      value = get_attribute_value(obj, attr_name, options)

      # 属性名を変換
      key = transform_key(attr_name)

      # 属性値を設定
      attributes[key] = value
    end

    attributes
  end

  # 関連データをシリアライズ
  def serialize_associations(obj)
    associations = {}

    # 関連データリストが定義されていない場合は空のハッシュを返す
    return associations unless self.class.respond_to?(:associations_to_serialize)

    # 関連データリストを取得
    assocs = self.class.associations_to_serialize

    # 各関連データをシリアライズ
    assocs.each do |assoc_name, options|
      # 関連データが含まれているかチェック
      next unless include_association?(assoc_name)

      # 関連データを取得
      assoc_obj = get_association_value(obj, assoc_name, options)

      # 関連データが存在する場合のみシリアライズ
      next if assoc_obj.nil?

      # シリアライザーを取得
      serializer = options[:serializer]

      # シリアライザーが指定されている場合は使用
      if serializer
        # 関連データをシリアライズ
        serialized_assoc = if assoc_obj.is_a?(Enumerable)
                            serializer.new(assoc_obj, association_options(options)).serialize
                          else
                            serializer.new(assoc_obj, association_options(options)).serialize_object
                          end

        # 関連データ名を変換
        key = transform_key(assoc_name)

        # 関連データを設定
        associations[key] = serialized_assoc
      else
        # シリアライザーが指定されていない場合は素のオブジェクトを返す
        key = transform_key(assoc_name)
        associations[key] = assoc_obj
      end
    end

    associations
  end

  # メタデータを取得
  def meta_data(obj)
    return {} unless self.class.respond_to?(:meta_to_serialize)

    meta = {}

    # メタデータリストを取得
    meta_attrs = self.class.meta_to_serialize

    # 各メタデータを取得
    meta_attrs.each do |meta_name, options|
      # メタデータ値を取得
      value = get_meta_value(obj, meta_name, options)

      # メタデータ名を変換
      key = transform_key(meta_name)

      # メタデータ値を設定
      meta[key] = value
    end

    meta
  end

  # 属性値を取得
  def get_attribute_value(obj, attr_name, options)
    # メソッドが指定されている場合は使用
    if options[:method]
      method_name = options[:method]

      # オブジェクトがメソッドに応答するかチェック
      if obj.respond_to?(method_name)
        value = obj.send(method_name)
      else
        # シリアライザーがメソッドに応答するかチェック
        if respond_to?(method_name)
          value = send(method_name, obj)
        else
          value = nil
        end
      end
    else
      # 属性名をメソッドとして使用
      if obj.respond_to?(attr_name)
        value = obj.send(attr_name)
      else
        value = nil
      end
    end

    # 条件付き属性
    if options[:if] && options[:if].is_a?(Proc)
      return nil unless options[:if].call(obj, @options)
    end

    if options[:unless] && options[:unless].is_a?(Proc)
      return nil if options[:unless].call(obj, @options)
    end

    # 変換処理
    if options[:transform] && options[:transform].is_a?(Proc)
      value = options[:transform].call(value, obj, @options)
    end

    value
  end

  # 関連データ値を取得
  def get_association_value(obj, assoc_name, options)
    # メソッドが指定されている場合は使用
    if options[:method]
      method_name = options[:method]

      # オブジェクトがメソッドに応答するかチェック
      if obj.respond_to?(method_name)
        value = obj.send(method_name)
      else
        # シリアライザーがメソッドに応答するかチェック
        if respond_to?(method_name)
          value = send(method_name, obj)
        else
          value = nil
        end
      end
    else
      # 関連データ名をメソッドとして使用
      if obj.respond_to?(assoc_name)
        value = obj.send(assoc_name)
      else
        value = nil
      end
    end

    # 条件付き関連データ
    if options[:if] && options[:if].is_a?(Proc)
      return nil unless options[:if].call(obj, @options)
    end

    if options[:unless] && options[:unless].is_a?(Proc)
      return nil if options[:unless].call(obj, @options)
    end

    value
  end

  # メタデータ値を取得
  def get_meta_value(obj, meta_name, options)
    # メソッドが指定されている場合は使用
    if options[:method]
      method_name = options[:method]

      # シリアライザーがメソッドに応答するかチェック
      if respond_to?(method_name)
        value = send(method_name, obj)
      else
        value = nil
      end
    else
      # メタデータ名をメソッドとして使用
      if respond_to?(meta_name)
        value = send(meta_name, obj)
      else
        value = nil
      end
    end

    value
  end

  # 属性が除外されているかチェック
  def excluded_attribute?(attr_name)
    return false unless @options[:except] || @options[:only]

    if @options[:except] && @options[:except].include?(attr_name)
      return true
    end

    if @options[:only] && !@options[:only].include?(attr_name)
      return true
    end

    false
  end

  # 関連データが含まれているかチェック
  def include_association?(assoc_name)
    return true unless @options[:include] || @options[:exclude]

    if @options[:exclude] && @options[:exclude].include?(assoc_name)
      return false
    end

    if @options[:include] && @options[:include].include?(assoc_name)
      return true
    end

    # デフォルトでは含めない
    @options[:include].present?
  end

  # 関連データを含めるかチェック
  def include_associations?
    @options[:include_associations] != false
  end

  # メタデータを含めるかチェック
  def include_meta?
    @options[:include_meta] != false
  end

  # 関連データのオプションを取得
  def association_options(options)
    assoc_options = {}

    # 関連データのオプションをコピー
    if options[:options]
      assoc_options.merge!(options[:options])
    end

    # 親オプションから関連データに関連するオプションをコピー
    [:include, :exclude, :except, :only].each do |key|
      if @options[key]
        assoc_options[key] = @options[key]
      end
    end

    assoc_options
  end

  # キーを変換
  def transform_key(key)
    key_transform = @options[:key_transform] || self.class.key_transform

    case key_transform
    when :camel
      key.to_s.camelize(:lower).to_sym
    when :camel_upper
      key.to_s.camelize.to_sym
    when :dash
      key.to_s.dasherize.to_sym
    when :underscore
      key.to_s.underscore.to_sym
    else
      key.to_sym
    end
  end

  # JSONに変換
  def to_json(options = nil)
    serialize.to_json(options)
  end

  # クラスメソッド
  class << self
    # 属性を定義
    def attributes(*attrs, **options)
      self.attributes_to_serialize ||= {}

      attrs.each do |attr|
        self.attributes_to_serialize[attr] = options.dup
      end
    end

    # 属性を定義（オプション付き）
    def attribute(attr, options = {})
      self.attributes_to_serialize ||= {}
      self.attributes_to_serialize[attr] = options
    end

    # 関連データを定義
    def has_one(assoc, options = {})
      self.associations_to_serialize ||= {}
      self.associations_to_serialize[assoc] = options.merge(type: :has_one)
    end

    # 関連データを定義（複数）
    def has_many(assoc, options = {})
      self.associations_to_serialize ||= {}
      self.associations_to_serialize[assoc] = options.merge(type: :has_many)
    end

    # メタデータを定義
    def meta(name, options = {})
      self.meta_to_serialize ||= {}
      self.meta_to_serialize[name] = options
    end

    # キー変換方法を設定
    def set_key_transform(transform)
      self.key_transform = transform
    end

    # 属性リスト
    def attributes_to_serialize
      @attributes_to_serialize ||= {}
    end

    # 属性リストを設定
    def attributes_to_serialize=(value)
      @attributes_to_serialize = value
    end

    # 関連データリスト
    def associations_to_serialize
      @associations_to_serialize ||= {}
    end

    # 関連データリストを設定
    def associations_to_serialize=(value)
      @associations_to_serialize = value
    end

    # メタデータリスト
    def meta_to_serialize
      @meta_to_serialize ||= {}
    end

    # メタデータリストを設定
    def meta_to_serialize=(value)
      @meta_to_serialize = value
    end

    # キー変換方法
    def key_transform
      @key_transform ||= :underscore
    end

    # キー変換方法を設定
    def key_transform=(value)
      @key_transform = value
    end
  end
end
