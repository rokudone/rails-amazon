class PaginationBuilder
  attr_reader :query_builder, :page, :per_page, :total_count, :total_pages, :errors

  def initialize(query_builder)
    @query_builder = query_builder
    @page = 1
    @per_page = 20
    @total_count = 0
    @total_pages = 0
    @errors = []
  end

  # ページネーションを設定
  def paginate(page = nil, per_page = nil)
    @page = [1, page.to_i].max if page.present?
    @per_page = [1, per_page.to_i].max if per_page.present?

    # 総件数を取得
    @total_count = @query_builder.count

    # 総ページ数を計算
    @total_pages = (@total_count.to_f / @per_page).ceil

    # ページが総ページ数を超えている場合は最後のページに設定
    @page = @total_pages if @total_pages > 0 && @page > @total_pages

    # オフセットを計算
    offset = (@page - 1) * @per_page

    # クエリにLIMITとOFFSETを適用
    @query_builder.limit(@per_page).offset(offset)

    self
  end

  # パラメータからページネーションを設定
  def paginate_from_params(params, page_param = :page, per_page_param = :per_page, default_per_page = 20)
    page = params[page_param]
    per_page = params[per_page_param] || default_per_page

    paginate(page, per_page)
  end

  # 指定したページのレコードを取得
  def page_records(page = nil)
    paginate(page, @per_page) if page.present?
    @query_builder.execute
  end

  # 現在のページのレコードを取得
  def current_page_records
    @query_builder.execute
  end

  # 次のページのレコードを取得
  def next_page_records
    return [] if @page >= @total_pages

    paginate(@page + 1, @per_page)
    @query_builder.execute
  end

  # 前のページのレコードを取得
  def prev_page_records
    return [] if @page <= 1

    paginate(@page - 1, @per_page)
    @query_builder.execute
  end

  # 最初のページのレコードを取得
  def first_page_records
    paginate(1, @per_page)
    @query_builder.execute
  end

  # 最後のページのレコードを取得
  def last_page_records
    paginate(@total_pages, @per_page)
    @query_builder.execute
  end

  # ページ情報を取得
  def page_info
    {
      current_page: @page,
      per_page: @per_page,
      total_count: @total_count,
      total_pages: @total_pages,
      first_page: @page == 1,
      last_page: @page == @total_pages,
      prev_page: @page > 1 ? @page - 1 : nil,
      next_page: @page < @total_pages ? @page + 1 : nil,
      offset: (@page - 1) * @per_page,
      limit: @per_page
    }
  end

  # ページネーションリンク情報を取得
  def pagination_links(url_base, query_params = {})
    links = {}

    # 現在のページのリンク
    links[:self] = build_page_url(url_base, @page, query_params)

    # 最初のページのリンク
    links[:first] = build_page_url(url_base, 1, query_params)

    # 最後のページのリンク
    links[:last] = build_page_url(url_base, @total_pages, query_params) if @total_pages > 0

    # 前のページのリンク
    links[:prev] = build_page_url(url_base, @page - 1, query_params) if @page > 1

    # 次のページのリンク
    links[:next] = build_page_url(url_base, @page + 1, query_params) if @page < @total_pages

    links
  end

  # ページ番号の配列を取得（ページネーションUIに使用）
  def page_numbers(max_visible = 5)
    return [] if @total_pages <= 1

    # 表示するページ番号の範囲を計算
    half_visible = max_visible / 2
    start_page = [@page - half_visible, 1].max
    end_page = [start_page + max_visible - 1, @total_pages].min

    # 表示するページ数が最大数に満たない場合、開始ページを調整
    if end_page - start_page + 1 < max_visible
      start_page = [end_page - max_visible + 1, 1].max
    end

    (start_page..end_page).to_a
  end

  # ページネーションメタデータを取得（APIレスポンス用）
  def pagination_meta
    {
      pagination: page_info
    }
  end

  # ページネーションヘッダーを生成（APIレスポンス用）
  def pagination_headers(url_base, query_params = {})
    links = pagination_links(url_base, query_params)

    # Link ヘッダーを生成
    link_header = links.map do |rel, url|
      "<#{url}>; rel=\"#{rel}\""
    end.join(', ')

    {
      'X-Total-Count' => @total_count.to_s,
      'X-Total-Pages' => @total_pages.to_s,
      'X-Current-Page' => @page.to_s,
      'X-Per-Page' => @per_page.to_s,
      'Link' => link_header
    }
  end

  # カーソルベースのページネーションを設定
  def paginate_by_cursor(cursor, limit = 20, cursor_field = 'id', direction = :after)
    @per_page = [1, limit.to_i].max

    # カーソルが指定されている場合
    if cursor.present?
      if direction == :after
        @query_builder.where("#{cursor_field} > ?", cursor)
      else
        @query_builder.where("#{cursor_field} < ?", cursor)
        @query_builder.order_by(cursor_field, :desc)
      end
    end

    # 件数制限を適用
    @query_builder.limit(@per_page)

    self
  end

  # オフセットベースのページネーションを設定
  def paginate_by_offset(offset, limit = 20)
    @per_page = [1, limit.to_i].max
    offset = [0, offset.to_i].max

    # 総件数を取得
    @total_count = @query_builder.count

    # クエリにLIMITとOFFSETを適用
    @query_builder.limit(@per_page).offset(offset)

    self
  end

  # クエリビルダーを取得
  def get_query_builder
    @query_builder
  end

  # クエリを実行
  def execute
    @query_builder.execute
  end

  # ページネーションをリセット
  def reset
    @page = 1
    @per_page = 20
    @total_count = 0
    @total_pages = 0
    @query_builder.reset
    self
  end

  private

  # ページURLを構築
  def build_page_url(url_base, page, query_params = {})
    uri = URI.parse(url_base)

    # 既存のクエリパラメータを取得
    existing_params = URI.decode_www_form(uri.query || '').to_h

    # 新しいパラメータをマージ
    params = existing_params.merge(query_params).merge('page' => page.to_s)

    # URIを更新
    uri.query = URI.encode_www_form(params)

    uri.to_s
  end
end
