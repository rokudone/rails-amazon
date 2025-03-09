module StringUtils
  class << self
    # 文字列を指定された長さで切り詰め、必要に応じて末尾に省略記号を追加
    def truncate(text, length = 30, omission = '...')
      return '' if text.nil?

      text = text.to_s
      if text.length > length
        text[0...(length - omission.length)] + omission
      else
        text
      end
    end

    # 文字列からURLフレンドリーなスラグを生成
    def to_slug(text)
      return '' if text.nil?

      # 小文字に変換し、アルファベット、数字、ハイフン以外の文字を削除
      slug = text.to_s.downcase
                 .gsub(/[^\p{Alnum}\p{Han}\p{Hiragana}\p{Katakana}]+/, '-')
                 .gsub(/-+/, '-')      # 連続するハイフンを1つに
                 .gsub(/^-|-$/, '')    # 先頭と末尾のハイフンを削除

      slug.empty? ? 'slug' : slug
    end

    # HTMLタグをエスケープしてサニタイズ
    def sanitize(text)
      return '' if text.nil?

      text.to_s
          .gsub(/&/, '&amp;')
          .gsub(/</, '&lt;')
          .gsub(/>/, '&gt;')
          .gsub(/"/, '&quot;')
          .gsub(/'/, '&#39;')
    end

    # 機密情報（クレジットカード番号、メールアドレスなど）をマスク
    def mask_sensitive_data(text, visible_chars = 4, mask_char = '*')
      return '' if text.nil?

      text = text.to_s
      if text.length <= visible_chars
        text
      else
        mask_length = text.length - visible_chars
        mask_char * mask_length + text[-visible_chars..-1]
      end
    end

    # メールアドレスをマスク（username@domain.com → u******@d*****.com）
    def mask_email(email)
      return '' if email.nil?

      email = email.to_s
      if email.include?('@')
        username, domain = email.split('@')
        domain_parts = domain.split('.')
        domain_name = domain_parts[0]
        tld = domain_parts[1..-1].join('.')

        masked_username = username[0] + '*' * (username.length - 1)
        masked_domain = domain_name[0] + '*' * (domain_name.length - 1)

        "#{masked_username}@#{masked_domain}.#{tld}"
      else
        mask_sensitive_data(email)
      end
    end

    # キャメルケースをスネークケースに変換（camelCase → camel_case）
    def camel_to_snake(text)
      return '' if text.nil?

      text.to_s.gsub(/([A-Z])/, '_\1').downcase.gsub(/^_/, '')
    end

    # スネークケースをキャメルケースに変換（snake_case → snakeCase）
    def snake_to_camel(text, capitalize_first = false)
      return '' if text.nil?

      result = text.to_s.gsub(/_([a-z])/) { $1.upcase }
      capitalize_first ? result.gsub(/^([a-z])/) { $1.upcase } : result
    end
  end
end
