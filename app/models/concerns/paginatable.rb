module Paginatable
  extend ActiveSupport::Concern

  included do
    # ページネーションのデフォルト設定
    class_attribute :default_per_page, default: 20
    class_attribute :max_per_page, default: 100
  end

  class_methods do
    # ページネーションを適用
    def paginate(page: 1, per_page: nil)
      # ページ番号を正規化（1未満の場合は1に設定）
      page = [1, page.to_i].max

      # 1ページあたりの件数を正規化
      per_page = per_page.present? ? per_page.to_i : default_per_page
      per_page = [[1, per_page].max, max_per_page].min

      # オフセットを計算
      offset_value = (page - 1) * per_page

      # ページネーションを適用
      limit(per_page).offset(offset_value)
    end

    # ページ情報を生成
    def page_info(page: 1, per_page: nil, total_count: nil)
      # ページ番号を正規化
      page = [1, page.to_i].max

      # 1ページあたりの件数を正規化
      per_page = per_page.present? ? per_page.to_i : default_per_page
      per_page = [[1, per_page].max, max_per_page].min

      # 総件数を取得（指定されていない場合は計算）
      total_count ||= count

      # 総ページ数を計算
      total_pages = (total_count.to_f / per_page).ceil

      # 現在のページが総ページ数を超えないように調整
      page = [page, total_pages].min if total_pages > 0

      # オフセットを計算
      offset_value = (page - 1) * per_page

      # 前のページと次のページを計算
      prev_page = page > 1 ? page - 1 : nil
      next_page = page < total_pages ? page + 1 : nil

      # ページ情報を返す
      {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages,
        prev_page: prev_page,
        next_page: next_page,
        offset: offset_value,
        limit: per_page,
        first_page: page == 1,
        last_page: page == total_pages || total_pages == 0
      }
    end

    # ページネーションとページ情報を同時に取得
    def paginate_with_info(page: 1, per_page: nil)
      # ページネーションを適用
      paginated = paginate(page: page, per_page: per_page)

      # 総件数を取得
      total_count = count

      # ページ情報を生成
      page_info = page_info(page: page, per_page: per_page, total_count: total_count)

      # 結果とページ情報を返す
      [paginated, page_info]
    end

    # ページネーションヘッダー用の情報を生成
    def pagination_headers(page_info, base_url)
      headers = {}

      # Linkヘッダーを生成
      links = []

      # 最初のページへのリンク
      links << "<#{base_url}?page=1&per_page=#{page_info[:per_page]}>; rel=\"first\""

      # 前のページへのリンク
      if page_info[:prev_page]
        links << "<#{base_url}?page=#{page_info[:prev_page]}&per_page=#{page_info[:per_page]}>; rel=\"prev\""
      end

      # 次のページへのリンク
      if page_info[:next_page]
        links << "<#{base_url}?page=#{page_info[:next_page]}&per_page=#{page_info[:per_page]}>; rel=\"next\""
      end

      # 最後のページへのリンク
      if page_info[:total_pages] > 0
        links << "<#{base_url}?page=#{page_info[:total_pages]}&per_page=#{page_info[:per_page]}>; rel=\"last\""
      end

      # Linkヘッダーを設定
      headers['Link'] = links.join(', ') if links.any?

      # その他のページネーション情報をヘッダーに設定
      headers['X-Page'] = page_info[:current_page].to_s
      headers['X-Per-Page'] = page_info[:per_page].to_s
      headers['X-Total'] = page_info[:total_count].to_s
      headers['X-Total-Pages'] = page_info[:total_pages].to_s
      headers['X-Offset'] = page_info[:offset].to_s

      headers
    end

    # ページネーションメタデータを生成（API用）
    def pagination_meta(page_info)
      {
        pagination: {
          current_page: page_info[:current_page],
          prev_page: page_info[:prev_page],
          next_page: page_info[:next_page],
          total_pages: page_info[:total_pages],
          total_count: page_info[:total_count],
          per_page: page_info[:per_page]
        }
      }
    end
  end
end
