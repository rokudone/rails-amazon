module Pagination
  extend ActiveSupport::Concern

  included do
    # ページネーション関連の設定を定義するクラス変数
    class_attribute :pagination_options, default: {}

    # ヘルパーメソッドを定義
    helper_method :paginate, :page_info, :pagination_links, :pagination_meta
  end

  class_methods do
    # ページネーション設定を構成
    def configure_pagination(options = {})
      self.pagination_options = {
        default_per_page: 20,
        max_per_page: 100,
        param_name: :page,
        per_page_param_name: :per_page,
        include_pagination_headers: true,
        include_pagination_meta: true
      }.merge(options)
    end
  end

  # コレクションをページネーション
  def paginate(collection, options = {})
    # オプションをマージ
    options = pagination_options.merge(options)

    # ページ番号を取得
    page = params[options[:param_name]].to_i
    page = 1 if page < 1

    # 1ページあたりの件数を取得
    per_page = params[options[:per_page_param_name]].to_i
    per_page = options[:default_per_page] if per_page < 1
    per_page = [per_page, options[:max_per_page]].min

    # コレクションがPaginatableコンサーンを含んでいる場合
    if collection.respond_to?(:paginate_with_info)
      # ページネーションとページ情報を取得
      paginated_collection, page_info = collection.paginate_with_info(page: page, per_page: per_page)

      # ページ情報を保存
      @pagination_info = page_info

      # ページネーションヘッダーを設定
      set_pagination_headers(page_info) if options[:include_pagination_headers]

      # ページネーションされたコレクションを返す
      paginated_collection
    else
      # 標準のページネーション
      total_count = collection.count
      total_pages = (total_count.to_f / per_page).ceil

      # オフセットを計算
      offset = (page - 1) * per_page

      # ページネーションを適用
      paginated_collection = collection.offset(offset).limit(per_page)

      # ページ情報を構築
      @pagination_info = {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages,
        offset: offset
      }

      # ページネーションヘッダーを設定
      set_pagination_headers(@pagination_info) if options[:include_pagination_headers]

      # ページネーションされたコレクションを返す
      paginated_collection
    end
  end

  # ページ情報を取得
  def page_info
    @pagination_info
  end

  # ページネーションヘッダーを設定
  def set_pagination_headers(page_info)
    return unless page_info

    # リクエストURLを取得
    base_url = request.url.split('?').first

    # クエリパラメータを取得
    query_params = request.query_parameters.except(
      pagination_options[:param_name].to_s,
      pagination_options[:per_page_param_name].to_s
    )

    # ページネーションヘッダーを構築
    links = []

    # 最初のページへのリンク
    links << "<#{build_pagination_url(base_url, query_params, 1, page_info[:per_page])}>; rel=\"first\""

    # 前のページへのリンク
    if page_info[:current_page] > 1
      prev_page = page_info[:current_page] - 1
      links << "<#{build_pagination_url(base_url, query_params, prev_page, page_info[:per_page])}>; rel=\"prev\""
    end

    # 次のページへのリンク
    if page_info[:current_page] < page_info[:total_pages]
      next_page = page_info[:current_page] + 1
      links << "<#{build_pagination_url(base_url, query_params, next_page, page_info[:per_page])}>; rel=\"next\""
    end

    # 最後のページへのリンク
    links << "<#{build_pagination_url(base_url, query_params, page_info[:total_pages], page_info[:per_page])}>; rel=\"last\""

    # Linkヘッダーを設定
    response.headers['Link'] = links.join(', ')

    # その他のページネーション情報をヘッダーに設定
    response.headers['X-Page'] = page_info[:current_page].to_s
    response.headers['X-Per-Page'] = page_info[:per_page].to_s
    response.headers['X-Total'] = page_info[:total_count].to_s
    response.headers['X-Total-Pages'] = page_info[:total_pages].to_s
    response.headers['X-Offset'] = page_info[:offset].to_s
  end

  # ページネーションURLを構築
  def build_pagination_url(base_url, query_params, page, per_page)
    # クエリパラメータをコピー
    params = query_params.dup

    # ページネーションパラメータを設定
    params[pagination_options[:param_name]] = page
    params[pagination_options[:per_page_param_name]] = per_page

    # URLを構築
    if params.empty?
      "#{base_url}"
    else
      "#{base_url}?#{params.to_query}"
    end
  end

  # ページネーションリンクを生成
  def pagination_links
    return {} unless @pagination_info

    # リクエストURLを取得
    base_url = request.url.split('?').first

    # クエリパラメータを取得
    query_params = request.query_parameters.except(
      pagination_options[:param_name].to_s,
      pagination_options[:per_page_param_name].to_s
    )

    # ページネーションリンクを構築
    links = {}

    # 最初のページへのリンク
    links[:first] = build_pagination_url(base_url, query_params, 1, @pagination_info[:per_page])

    # 前のページへのリンク
    if @pagination_info[:current_page] > 1
      prev_page = @pagination_info[:current_page] - 1
      links[:prev] = build_pagination_url(base_url, query_params, prev_page, @pagination_info[:per_page])
    end

    # 次のページへのリンク
    if @pagination_info[:current_page] < @pagination_info[:total_pages]
      next_page = @pagination_info[:current_page] + 1
      links[:next] = build_pagination_url(base_url, query_params, next_page, @pagination_info[:per_page])
    end

    # 最後のページへのリンク
    links[:last] = build_pagination_url(base_url, query_params, @pagination_info[:total_pages], @pagination_info[:per_page])

    links
  end

  # ページネーションメタデータを生成
  def pagination_meta
    return {} unless @pagination_info

    {
      pagination: {
        current_page: @pagination_info[:current_page],
        per_page: @pagination_info[:per_page],
        total_count: @pagination_info[:total_count],
        total_pages: @pagination_info[:total_pages],
        links: pagination_links
      }
    }
  end

  # レスポンスにページネーションメタデータを含める
  def with_pagination_meta(data)
    return data unless pagination_options[:include_pagination_meta] && @pagination_info

    # メタデータを含める
    if data.is_a?(Hash)
      data.merge(pagination_meta)
    else
      { data: data }.merge(pagination_meta)
    end
  end
end
