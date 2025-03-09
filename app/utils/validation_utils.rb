module ValidationUtils
  class << self
    # メールアドレスの形式を検証
    def valid_email?(email)
      return false if email.nil? || email.empty?

      email_regex = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
      email =~ email_regex ? true : false
    end

    # パスワードの強度を検証
    def valid_password?(password, min_length = 8, require_uppercase = true, require_number = true, require_special = true)
      return false if password.nil? || password.empty?

      # 最小長チェック
      return false if password.length < min_length

      # 大文字を含むかチェック
      return false if require_uppercase && !password.match(/[A-Z]/)

      # 数字を含むかチェック
      return false if require_number && !password.match(/\d/)

      # 特殊文字を含むかチェック
      return false if require_special && !password.match(/[!@#$%^&*(),.?":{}|<>]/)

      true
    end

    # URLの形式を検証
    def valid_url?(url)
      return false if url.nil? || url.empty?

      url_regex = /\A(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$\z/ix
      url =~ url_regex ? true : false
    end

    # 電話番号の形式を検証
    def valid_phone?(phone, country_code = 'JP')
      return false if phone.nil? || phone.empty?

      # 国別の電話番号フォーマット
      case country_code
      when 'JP' # 日本
        phone_regex = /\A(0\d{1,4}-\d{1,4}-\d{4}|\d{10,11})\z/
      when 'US' # アメリカ
        phone_regex = /\A(\+?1[-\s.]?)?\(?([0-9]{3})\)?[-\s.]?([0-9]{3})[-\s.]?([0-9]{4})\z/
      when 'GB' # イギリス
        phone_regex = /\A(\+?44[-\s.]?)?\(?([0-9]{2,5})\)?[-\s.]?([0-9]{3,4})[-\s.]?([0-9]{3,4})\z/
      else
        # 汎用的な電話番号フォーマット
        phone_regex = /\A\+?[0-9]{7,15}\z/
      end

      phone =~ phone_regex ? true : false
    end

    # 郵便番号の形式を検証
    def valid_postal_code?(postal_code, country_code = 'JP')
      return false if postal_code.nil? || postal_code.empty?

      # 国別の郵便番号フォーマット
      case country_code
      when 'JP' # 日本
        postal_regex = /\A\d{3}-?\d{4}\z/
      when 'US' # アメリカ
        postal_regex = /\A\d{5}(-\d{4})?\z/
      when 'GB' # イギリス
        postal_regex = /\A[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}\z/i
      else
        # 汎用的な郵便番号フォーマット
        postal_regex = /\A[0-9A-Z]{3,10}\z/i
      end

      postal_code =~ postal_regex ? true : false
    end

    # クレジットカード番号の形式を検証
    def valid_credit_card?(card_number)
      return false if card_number.nil? || card_number.empty?

      # 空白とハイフンを削除
      card_number = card_number.gsub(/[\s-]/, '')

      # 数字のみかチェック
      return false unless card_number =~ /\A\d+\z/

      # Luhnアルゴリズムによる検証
      sum = 0
      card_number.reverse.chars.each_with_index do |digit, i|
        n = digit.to_i
        sum += if i.odd?
                 n = n * 2
                 n > 9 ? n - 9 : n
               else
                 n
               end
      end

      (sum % 10).zero?
    end

    # 日付の形式を検証
    def valid_date?(date_string, format = '%Y-%m-%d')
      return false if date_string.nil? || date_string.empty?

      begin
        Date.strptime(date_string, format)
        true
      rescue ArgumentError
        false
      end
    end

    # 数値の範囲を検証
    def valid_number_range?(number, min = nil, max = nil)
      return false if number.nil?

      begin
        num = number.to_f
        return false if min && num < min
        return false if max && num > max
        true
      rescue
        false
      end
    end

    # 文字列の長さを検証
    def valid_length?(string, min = nil, max = nil)
      return false if string.nil?

      length = string.to_s.length
      return false if min && length < min
      return false if max && length > max
      true
    end

    # 文字列が許容値リストに含まれているかを検証
    def valid_inclusion?(value, allowed_values)
      return false if value.nil? || allowed_values.nil? || allowed_values.empty?

      allowed_values.include?(value)
    end

    # 文字列が禁止値リストに含まれていないかを検証
    def valid_exclusion?(value, forbidden_values)
      return true if value.nil? || forbidden_values.nil? || forbidden_values.empty?

      !forbidden_values.include?(value)
    end

    # 正規表現パターンに一致するかを検証
    def valid_format?(string, pattern)
      return false if string.nil? || pattern.nil?

      string.to_s =~ pattern ? true : false
    end

    # 数値かどうかを検証
    def valid_number?(value)
      return false if value.nil?

      begin
        Float(value)
        true
      rescue
        false
      end
    end

    # 整数かどうかを検証
    def valid_integer?(value)
      return false if value.nil?

      begin
        Integer(value)
        true
      rescue
        false
      end
    end

    # ブール値かどうかを検証
    def valid_boolean?(value)
      return false if value.nil?

      [true, false, 'true', 'false', 1, 0, '1', '0'].include?(value)
    end
  end
end
