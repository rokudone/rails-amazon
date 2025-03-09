class ReportGenerationJob < ApplicationJob
  queue_as :reports

  # レポート生成を行うジョブ
  def perform(report_type, options = {})
    # オプションを取得
    options = {
      format: :pdf,
      file_path: nil,
      parameters: {},
      template: nil,
      on_complete: nil,
      on_error: nil,
      user_id: nil
    }.merge(options.symbolize_keys)

    # レポートタイプを検証
    unless valid_report_type?(report_type)
      handle_error("Invalid report type: #{report_type}", options)
      return
    end

    # ファイルパスを生成
    file_path = options[:file_path] || generate_file_path(report_type, options[:format])

    # ディレクトリを作成
    FileUtils.mkdir_p(File.dirname(file_path))

    begin
      # レポートデータを取得
      report_data = collect_report_data(report_type, options[:parameters])

      # フォーマットに応じてレポートを生成
      case options[:format].to_sym
      when :pdf
        generate_pdf_report(report_type, report_data, file_path, options)
      when :excel
        generate_excel_report(report_type, report_data, file_path, options)
      when :csv
        generate_csv_report(report_type, report_data, file_path, options)
      when :html
        generate_html_report(report_type, report_data, file_path, options)
      when :json
        generate_json_report(report_type, report_data, file_path, options)
      else
        handle_error("Unsupported format: #{options[:format]}", options)
        return
      end

      # 完了時の処理
      handle_completion(file_path, report_type, options)
    rescue => e
      handle_error("Report generation error: #{e.message}", options, e)
    end
  end

  private

  # レポートタイプが有効かどうかをチェック
  def valid_report_type?(report_type)
    available_report_types.include?(report_type.to_sym)
  end

  # 利用可能なレポートタイプを取得
  def available_report_types
    [
      :sales_summary,
      :product_performance,
      :customer_activity,
      :inventory_status,
      :order_fulfillment,
      :revenue_analysis,
      :user_engagement,
      :marketing_campaign,
      :financial_statement,
      :custom
    ]
  end

  # レポートデータを収集
  def collect_report_data(report_type, parameters)
    case report_type.to_sym
    when :sales_summary
      collect_sales_summary_data(parameters)
    when :product_performance
      collect_product_performance_data(parameters)
    when :customer_activity
      collect_customer_activity_data(parameters)
    when :inventory_status
      collect_inventory_status_data(parameters)
    when :order_fulfillment
      collect_order_fulfillment_data(parameters)
    when :revenue_analysis
      collect_revenue_analysis_data(parameters)
    when :user_engagement
      collect_user_engagement_data(parameters)
    when :marketing_campaign
      collect_marketing_campaign_data(parameters)
    when :financial_statement
      collect_financial_statement_data(parameters)
    when :custom
      collect_custom_report_data(parameters)
    else
      {}
    end
  end

  # 売上概要レポートのデータを収集
  def collect_sales_summary_data(parameters)
    # パラメータを取得
    start_date = parameters[:start_date] || Date.today.beginning_of_month
    end_date = parameters[:end_date] || Date.today
    group_by = parameters[:group_by] || :day

    # データを収集
    data = {
      title: "Sales Summary Report",
      subtitle: "#{start_date.to_s} to #{end_date.to_s}",
      parameters: parameters,
      generated_at: Time.current,
      summary: {},
      details: []
    }

    # 注文データを取得
    if defined?(Order)
      # 期間内の注文を取得
      orders = Order.where(created_at: start_date.beginning_of_day..end_date.end_of_day)

      # 概要データを計算
      data[:summary] = {
        total_orders: orders.count,
        total_revenue: orders.sum(:total),
        average_order_value: orders.average(:total).to_f.round(2),
        total_customers: orders.select(:user_id).distinct.count
      }

      # グループ化
      grouped_orders = case group_by.to_sym
                       when :day
                         orders.group_by { |o| o.created_at.to_date }
                       when :week
                         orders.group_by { |o| o.created_at.beginning_of_week.to_date }
                       when :month
                         orders.group_by { |o| o.created_at.beginning_of_month.to_date }
                       else
                         orders.group_by { |o| o.created_at.to_date }
                       end

      # 詳細データを生成
      grouped_orders.each do |date, group|
        data[:details] << {
          date: date,
          orders: group.count,
          revenue: group.sum(&:total),
          average_order_value: group.sum(&:total) / group.count.to_f
        }
      end
    end

    data
  end

  # 商品パフォーマンスレポートのデータを収集
  def collect_product_performance_data(parameters)
    # パラメータを取得
    start_date = parameters[:start_date] || Date.today.beginning_of_month
    end_date = parameters[:end_date] || Date.today
    limit = parameters[:limit] || 20

    # データを収集
    data = {
      title: "Product Performance Report",
      subtitle: "#{start_date.to_s} to #{end_date.to_s}",
      parameters: parameters,
      generated_at: Time.current,
      summary: {},
      top_products: [],
      category_performance: []
    }

    # 商品データを取得
    if defined?(Product) && defined?(OrderItem)
      # 期間内の注文アイテムを取得
      order_items = OrderItem.joins(:order)
                            .where(orders: { created_at: start_date.beginning_of_day..end_date.end_of_day })

      # 概要データを計算
      data[:summary] = {
        total_products_sold: order_items.sum(:quantity),
        total_revenue: order_items.sum('quantity * price'),
        unique_products_sold: order_items.select(:product_id).distinct.count
      }

      # 商品別の売上を計算
      product_sales = order_items.group(:product_id)
                               .select('product_id, SUM(quantity) as total_quantity, SUM(quantity * price) as total_revenue')
                               .order('total_revenue DESC')
                               .limit(limit)

      # 商品情報を取得
      product_sales.each do |sale|
        product = Product.find_by(id: sale.product_id)
        next unless product

        data[:top_products] << {
          product_id: product.id,
          product_name: product.name,
          quantity_sold: sale.total_quantity,
          revenue: sale.total_revenue,
          average_price: sale.total_revenue / sale.total_quantity.to_f
        }
      end

      # カテゴリ別の売上を計算
      if Product.column_names.include?('category_id')
        category_sales = order_items.joins(:product)
                                  .group('products.category_id')
                                  .select('products.category_id, SUM(order_items.quantity) as total_quantity, SUM(order_items.quantity * order_items.price) as total_revenue')
                                  .order('total_revenue DESC')

        # カテゴリ情報を取得
        category_sales.each do |sale|
          category_name = if defined?(Category) && sale.category_id
                           category = Category.find_by(id: sale.category_id)
                           category ? category.name : "Unknown"
                         else
                           "Unknown"
                         end

          data[:category_performance] << {
            category_id: sale.category_id,
            category_name: category_name,
            quantity_sold: sale.total_quantity,
            revenue: sale.total_revenue
          }
        end
      end
    end

    data
  end

  # 顧客活動レポートのデータを収集
  def collect_customer_activity_data(parameters)
    # パラメータを取得
    start_date = parameters[:start_date] || Date.today.beginning_of_month
    end_date = parameters[:end_date] || Date.today
    limit = parameters[:limit] || 20

    # データを収集
    data = {
      title: "Customer Activity Report",
      subtitle: "#{start_date.to_s} to #{end_date.to_s}",
      parameters: parameters,
      generated_at: Time.current,
      summary: {},
      top_customers: [],
      new_customers: [],
      customer_retention: {}
    }

    # 顧客データを取得
    if defined?(User) && defined?(Order)
      # 期間内の注文を取得
      orders = Order.where(created_at: start_date.beginning_of_day..end_date.end_of_day)

      # 概要データを計算
      total_customers = orders.select(:user_id).distinct.count
      new_customers = User.where(created_at: start_date.beginning_of_day..end_date.end_of_day).count

      data[:summary] = {
        total_customers: total_customers,
        new_customers: new_customers,
        total_orders: orders.count,
        average_orders_per_customer: orders.count.to_f / total_customers
      }

      # 顧客別の注文を計算
      customer_orders = orders.group(:user_id)
                            .select('user_id, COUNT(*) as order_count, SUM(total) as total_spent')
                            .order('total_spent DESC')
                            .limit(limit)

      # 顧客情報を取得
      customer_orders.each do |customer_order|
        user = User.find_by(id: customer_order.user_id)
        next unless user

        data[:top_customers] << {
          user_id: user.id,
          name: user.respond_to?(:name) ? user.name : "User #{user.id}",
          email: user.respond_to?(:email) ? user.email : nil,
          order_count: customer_order.order_count,
          total_spent: customer_order.total_spent,
          average_order_value: customer_order.total_spent / customer_order.order_count.to_f
        }
      end

      # 新規顧客を取得
      new_users = User.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
                     .order(created_at: :desc)
                     .limit(limit)

      new_users.each do |user|
        user_orders = Order.where(user_id: user.id)

        data[:new_customers] << {
          user_id: user.id,
          name: user.respond_to?(:name) ? user.name : "User #{user.id}",
          email: user.respond_to?(:email) ? user.email : nil,
          registration_date: user.created_at,
          order_count: user_orders.count,
          total_spent: user_orders.sum(:total)
        }
      end

      # 顧客維持率を計算
      previous_period_start = start_date - (end_date - start_date)
      previous_period_end = start_date - 1.day

      previous_customers = Order.where(created_at: previous_period_start.beginning_of_day..previous_period_end.end_of_day)
                               .select(:user_id).distinct.pluck(:user_id)

      current_customers = orders.select(:user_id).distinct.pluck(:user_id)

      returning_customers = previous_customers & current_customers

      data[:customer_retention] = {
        previous_period: "#{previous_period_start} to #{previous_period_end}",
        previous_customers: previous_customers.size,
        current_customers: current_customers.size,
        returning_customers: returning_customers.size,
        retention_rate: previous_customers.size > 0 ? (returning_customers.size.to_f / previous_customers.size * 100).round(2) : 0
      }
    end

    data
  end

  # 在庫状況レポートのデータを収集
  def collect_inventory_status_data(parameters)
    # パラメータを取得
    limit = parameters[:limit] || 20
    low_stock_threshold = parameters[:low_stock_threshold] || 10

    # データを収集
    data = {
      title: "Inventory Status Report",
      subtitle: "As of #{Date.today.to_s}",
      parameters: parameters,
      generated_at: Time.current,
      summary: {},
      low_stock_items: [],
      out_of_stock_items: [],
      inventory_value: []
    }

    # 在庫データを取得
    if defined?(Inventory) && defined?(Product)
      # 在庫アイテムを取得
      inventories = Inventory.all

      # 概要データを計算
      total_items = inventories.count
      low_stock_count = inventories.where("quantity <= ?", low_stock_threshold).count
      out_of_stock_count = inventories.where("quantity <= 0").count

      data[:summary] = {
        total_items: total_items,
        low_stock_items: low_stock_count,
        out_of_stock_items: out_of_stock_count,
        total_inventory_value: inventories.joins(:product).sum('inventory.quantity * products.price')
      }

      # 在庫切れアイテムを取得
      out_of_stock = inventories.where("quantity <= 0")
                              .joins(:product)
                              .select('inventories.*, products.name as product_name, products.price as product_price')
                              .limit(limit)

      out_of_stock.each do |item|
        data[:out_of_stock_items] << {
          product_id: item.product_id,
          product_name: item.product_name,
          quantity: item.quantity,
          last_updated: item.updated_at
        }
      end

      # 在庫少アイテムを取得
      low_stock = inventories.where("quantity > 0 AND quantity <= ?", low_stock_threshold)
                           .joins(:product)
                           .select('inventories.*, products.name as product_name, products.price as product_price')
                           .limit(limit)

      low_stock.each do |item|
        data[:low_stock_items] << {
          product_id: item.product_id,
          product_name: item.product_name,
          quantity: item.quantity,
          value: item.quantity * item.product_price,
          last_updated: item.updated_at
        }
      end

      # 在庫価値を計算
      if defined?(Category) && Product.column_names.include?('category_id')
        inventory_value = inventories.joins(:product)
                                   .group('products.category_id')
                                   .select('products.category_id, SUM(inventories.quantity) as total_quantity, SUM(inventories.quantity * products.price) as total_value')
                                   .order('total_value DESC')

        inventory_value.each do |value|
          category_name = if value.category_id
                           category = Category.find_by(id: value.category_id)
                           category ? category.name : "Unknown"
                         else
                           "Unknown"
                         end

          data[:inventory_value] << {
            category_id: value.category_id,
            category_name: category_name,
            quantity: value.total_quantity,
            value: value.total_value
          }
        end
      end
    end

    data
  end

  # 注文履行レポートのデータを収集
  def collect_order_fulfillment_data(parameters)
    # パラメータを取得
    start_date = parameters[:start_date] || Date.today.beginning_of_month
    end_date = parameters[:end_date] || Date.today

    # データを収集
    data = {
      title: "Order Fulfillment Report",
      subtitle: "#{start_date.to_s} to #{end_date.to_s}",
      parameters: parameters,
      generated_at: Time.current,
      summary: {},
      fulfillment_by_status: [],
      fulfillment_time: {},
      shipping_performance: []
    }

    # 注文データを取得
    if defined?(Order) && defined?(Shipment)
      # 期間内の注文を取得
      orders = Order.where(created_at: start_date.beginning_of_day..end_date.end_of_day)

      # 概要データを計算
      total_orders = orders.count
      fulfilled_orders = orders.where(status: 'completed').count

      data[:summary] = {
        total_orders: total_orders,
        fulfilled_orders: fulfilled_orders,
        fulfillment_rate: total_orders > 0 ? (fulfilled_orders.to_f / total_orders * 100).round(2) : 0,
        average_fulfillment_time: calculate_average_fulfillment_time(orders)
      }

      # ステータス別の注文数を計算
      if Order.column_names.include?('status')
        status_counts = orders.group(:status).count

        status_counts.each do |status, count|
          data[:fulfillment_by_status] << {
            status: status,
            count: count,
            percentage: (count.to_f / total_orders * 100).round(2)
          }
        end
      end

      # 履行時間を計算
      fulfillment_times = []

      orders.where.not(completed_at: nil).each do |order|
        fulfillment_time = (order.completed_at - order.created_at) / 1.hour
        fulfillment_times << fulfillment_time
      end

      if fulfillment_times.any?
        data[:fulfillment_time] = {
          average: fulfillment_times.sum / fulfillment_times.size,
          median: median(fulfillment_times),
          min: fulfillment_times.min,
          max: fulfillment_times.max
        }
      end

      # 配送パフォーマンスを計算
      if defined?(Shipment)
        shipments = Shipment.joins(:order)
                          .where(orders: { created_at: start_date.beginning_of_day..end_date.end_of_day })

        if Shipment.column_names.include?('carrier')
          carrier_performance = shipments.group(:carrier)
                                      .select('carrier, COUNT(*) as shipment_count, AVG(EXTRACT(EPOCH FROM (delivered_at - shipped_at)) / 3600) as avg_delivery_time')

          carrier_performance.each do |performance|
            data[:shipping_performance] << {
              carrier: performance.carrier,
              shipment_count: performance.shipment_count,
              average_delivery_time: performance.avg_delivery_time.to_f.round(2)
            }
          end
        end
      end
    end

    data
  end

  # 収益分析レポートのデータを収集
  def collect_revenue_analysis_data(parameters)
    # パラメータを取得
    start_date = parameters[:start_date] || Date.today.beginning_of_month
    end_date = parameters[:end_date] || Date.today
    group_by = parameters[:group_by] || :day

    # データを収集
    data = {
      title: "Revenue Analysis Report",
      subtitle: "#{start_date.to_s} to #{end_date.to_s}",
      parameters: parameters,
      generated_at: Time.current,
      summary: {},
      revenue_trend: [],
      payment_methods: [],
      discounts: []
    }

    # 注文データを取得
    if defined?(Order)
      # 期間内の注文を取得
      orders = Order.where(created_at: start_date.beginning_of_day..end_date.end_of_day)

      # 概要データを計算
      total_revenue = orders.sum(:total)
      total_cost = orders.sum(:cost) if Order.column_names.include?('cost')

      data[:summary] = {
        total_revenue: total_revenue,
        total_orders: orders.count,
        average_order_value: orders.average(:total).to_f.round(2)
      }

      # コストが利用可能な場合は利益を計算
      if total_cost
        data[:summary][:total_cost] = total_cost
        data[:summary][:gross_profit] = total_revenue - total_cost
        data[:summary][:profit_margin] = total_revenue > 0 ? ((total_revenue - total_cost) / total_revenue * 100).round(2) : 0
      end

      # 収益トレンドを計算
      grouped_orders = case group_by.to_sym
                       when :day
                         orders.group_by { |o| o.created_at.to_date }
                       when :week
                         orders.group_by { |o| o.created_at.beginning_of_week.to_date }
                       when :month
                         orders.group_by { |o| o.created_at.beginning_of_month.to_date }
                       else
                         orders.group_by { |o| o.created_at.to_date }
                       end

      grouped_orders.each do |date, group|
        revenue = group.sum(&:total)
        cost = group.sum(&:cost) if Order.column_names.include?('cost')

        trend_data = {
          date: date,
          revenue: revenue,
          orders: group.count,
          average_order_value: revenue / group.count.to_f
        }

        # コストが利用可能な場合は利益を計算
        if cost
          trend_data[:cost] = cost
          trend_data[:profit] = revenue - cost
          trend_data[:profit_margin] = revenue > 0 ? ((revenue - cost) / revenue * 100).round(2) : 0
        end

        data[:revenue_trend] << trend_data
      end

      # 支払い方法別の収益を計算
      if defined?(Payment) && Payment.column_names.include?('payment_method')
        payment_methods = Payment.joins(:order)
                               .where(orders: { created_at: start_date.beginning_of_day..end_date.end_of_day })
                               .group(:payment_method)
                               .select('payment_method, COUNT(*) as payment_count, SUM(amount) as total_amount')

        payment_methods.each do |method|
          data[:payment_methods] << {
            method: method.payment_method,
            count: method.payment_count,
            amount: method.total_amount,
            percentage: total_revenue > 0 ? (method.total_amount / total_revenue * 100).round(2) : 0
          }
        end
      end

      # 割引の影響を計算
      if defined?(OrderDiscount)
        discounts = OrderDiscount.joins(:order)
                               .where(orders: { created_at: start_date.beginning_of_day..end_date.end_of_day })
                               .group(:discount_type)
                               .select('discount_type, COUNT(*) as discount_count, SUM(amount) as total_amount')

        discounts.each do |discount|
          data[:discounts] << {
            type: discount.discount_type,
            count: discount.discount_count,
            amount: discount.total_amount,
            percentage: total_revenue > 0 ? (discount.total_amount / total_revenue * 100).round(2) : 0
          }
        end
      end
    end

    data
  end

  # ユーザーエンゲージメントレポートのデータを収集
  def collect_user_engagement_data(parameters)
    # 他のレポートデータ収集メソッドと同様に実装
    # 実際のアプリケーションに合わせてカスタマイズ
    {
      title: "User Engagement Report",
      subtitle: "Data collection not implemented",
      parameters: parameters,
      generated_at: Time.current
    }
  end

  # マーケティングキャンペーンレポートのデータを収集
  def collect_marketing_campaign_data(parameters)
    # 他のレポートデータ収集メソッドと同様に実装
    # 実際のアプリケーションに合わせてカスタマイズ
    {
      title: "Marketing Campaign Report",
      subtitle: "Data collection not implemented",
      parameters: parameters,
      generated_at: Time.current
    }
  end

  # 財務諸表レポートのデータを収集
  def collect_financial_statement_data(parameters)
    # 他のレポートデータ収集メソッドと同様に実装
    # 実際のアプリケーションに合わせてカスタマイズ
    {
      title: "Financial Statement Report",
      subtitle: "Data collection not implemented",
      parameters: parameters,
      generated_at: Time.current
    }
  end

  # カスタムレポートのデータを収集
  def collect_custom_report_data(parameters)
    # カスタムクエリが指定されている場合
    if parameters[:query].present?
      begin
        # クエリを実行
        result = ActiveRecord::Base.connection.execute(parameters[:query])

        # 結果を変換
        data = {
          title: parameters[:title] || "Custom Report",
          subtitle: parameters[:subtitle] || "Custom Query",
          parameters: parameters,
          generated_at: Time.current,
          results: []
        }

        # 結果を配列に変換
        result.each do |row|
          data[:results] << row
        end

        data
      rescue => e
        {
          title: "Custom Report Error",
          error: e.message,
          parameters: parameters,
          generated_at: Time.current
        }
      end
    else
      {
        title: "Custom Report",
        subtitle: "No query provided",
        parameters: parameters,
        generated_at: Time.current
      }
    end
  end

  # 平均履行時間を計算
  def calculate_average_fulfillment_time(orders)
    # 完了時間が記録されている注文を取得
    completed_orders = orders.where.not(completed_at: nil)

    # 履行時間を計算
    if completed_orders.any?
      total_time = completed_orders.sum("EXTRACT(EPOCH FROM (completed_at - created_at))")
      (total_time / completed_orders.count / 3600).round(2) # 時間単位
    else
      0
    end
  end

  # 中央値を計算
  def median(array)
    return nil if array.empty?

    sorted = array.sort
    len = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end

  # PDFレポートを生成
  def generate_pdf_report(report_type, report_data, file_path, options)
    # PDFレポート生成ライブラリを使用
    # 実際のアプリケーションに合わせてカスタマイズ
    # 例: Prawn, WickedPDF, GrapesPDF など

    # テンプレートが指定されている場合
    if options[:template].present?
      # テンプレートを使用してレポートを生成
      # 実装例: WickedPdf.new.pdf_from_string(render_to_string(template: options[:template], locals: { data: report_data }))
    else
      # デフォルトのレポート生成
      # 実装例: generate_default_pdf(report_type, report_data)
    end

    # ファイルに保存
    # 実装例: File.open(file_path, 'wb') { |file| file.write(pdf_content) }

    # シミュレーション用
    File.open(file_path, 'w') do |file|
      file.write("PDF Report: #{report_type}\n")
      file.write("Generated at: #{Time.current}\n")
      file.write("Data: #{report_data.to_json}")
    end
  end

  # Excelレポートを生成
  def generate_excel_report(report_type, report_data, file_path, options)
    require 'axlsx'

    # Excelパッケージを作成
    package = Axlsx::Package.new
    workbook = package.workbook

    # シートを追加
    workbook.add_worksheet(name: report_data[:title]) do |sheet|
      # スタイルを設定
      styles = workbook.styles
      title_style = styles.add_style(b: true, sz: 16)
      header_style = styles.add_style(b: true, bg_color: "DDDDDD")

      # タイトルを追加
      sheet.add_row [report_data[:title]], style: title_style
      sheet.add_row [report_data[:subtitle]]
      sheet.add_row ["Generated at: #{report_data[:generated_at]}"]
      sheet.add_row []

      # レポートタイプに応じてデータを追加
      case report_type.to_sym
      when :sales_summary
        # 概要を追加
        sheet.add_row ["Summary"], style: header_style
        sheet.add_row ["Total Orders", report_data[:summary][:total_orders]]
        sheet.add_row ["Total Revenue", report_data[:summary][:total_revenue]]
        sheet.add_row ["Average Order Value", report_data[:summary][:average_order_value]]
        sheet.add_row ["Total Customers", report_data[:summary][:total_customers]]
        sheet.add_row []

        # 詳細を追加
        sheet.add_row ["Date", "Orders", "Revenue", "Average Order Value"], style: header_style
        report_data[:details].each do |detail|
          sheet.add_row [detail[:date], detail[:orders], detail[:revenue], detail[:average_order_value]]
        end
      when :product_performance
        # 概要を追加
        sheet.add_row ["Summary"], style: header_style
        sheet.add_row ["Total Products Sold", report_data[:summary][:total_products_sold]]
        sheet.add_row ["Total Revenue", report_data[:summary][:total_revenue]]
        sheet.add_row ["Unique Products Sold", report_data[:summary][:unique_products_sold]]
        sheet.add_row []

        # トップ商品を追加
        sheet.add_row ["Top Products"], style: header_style
        sheet.add_row ["Product ID", "Product Name", "Quantity Sold", "Revenue", "Average Price"], style: header_style
        report_data[:top_products].each do |product|
          sheet.add_row [product[:product_id], product[:product_name], product[:quantity_sold], product[:revenue], product[:average_price]]
        end
        sheet.add_row []

        # カテゴリパフォーマンスを追加
        sheet.add_row ["Category Performance"], style: header_style
        sheet.add_row ["Category ID", "Category Name", "Quantity Sold", "Revenue"], style: header_style
        report_data[:category_performance].each do |category|
          sheet.add_row [category[:category_id], category[:category_name], category[:quantity_sold], category[:revenue]]
        end
      # 他のレポートタイプも同様に実装
      else
        # 汎用的なデータ出力
        report_data.each do |key, value|
          next if value.is_a?(Hash) || value.is_a?(Array)
          sheet.add_row [key.to_s.humanize, value]
        end

        # ハッシュデータを出力
        report_data.each do |key, value|
          next unless value.is_a?(Hash)
          sheet.add_row []
          sheet.add_row [key.to_s.humanize], style: header_style
          value.each do |k, v|
            sheet.add_row [k.to_s.humanize, v]
          end
        end

        # 配列データを出力
        report_data.each do |key, value|
          next unless value.is_a?(Array)
          sheet.add_row []
          sheet.add_row [key.to_s.humanize], style: header_style

          if value.any? && value.first.is_a?(Hash)
            # ヘッダー行を追加
            headers = value.first.keys.map { |k| k.to_s.humanize }
            sheet.add_row headers, style: header_style

            # データ行を追加
            value.each do |item|
              sheet.add_row item.values
            end
          else
            # 単純な配列
            value.each do |item|
              sheet.add_row [item]
            end
          end
        end
      end
    end

    # Excelファイルを保存
    package.serialize(file_path)
  end

  # CSVレポートを生成
  def generate_csv_report(report_type, report_data, file_path, options)
    require 'csv'

    CSV.open(file_path, 'w') do |csv|
      # タイトルを追加
      csv << [report_data[:title]]
      csv << [report_data[:subtitle]]
      csv << ["Generated at", report_data[:generated_at]]
      csv << []

      # レポートタイプに応じてデータを追加
      case report_type.to_sym
      when :sales_summary
        # 概要を追加
        csv << ["Summary"]
        csv << ["Total Orders", report_data[:summary][:total_orders]]
        csv << ["Total Revenue", report_data[:summary][:total_revenue]]
        csv << ["Average Order Value", report_data[:summary][:average_order_value]]
        csv << ["Total Customers", report_data[:summary][:total_customers]]
        csv << []

        # 詳細を追加
        csv << ["Date", "Orders", "Revenue", "Average Order Value"]
        report_data[:details].each do |detail|
          csv << [detail[:date], detail[:orders], detail[:revenue], detail[:average_order_value]]
        end
      # 他のレポートタイプも同様に実装
      else
        # 汎用的なデータ出力
        report_data.each do |key, value|
          next if value.is_a?(Hash) || value.is_a?(Array)
          csv << [key.to_s.humanize, value]
        end

        # ハッシュデータを出力
        report_data.each do |key, value|
          next unless value.is_a?(Hash)
          csv << []
          csv << [key.to_s.humanize]
          value.each do |k, v|
            csv << [k.to_s.humanize, v]
          end
        end

        # 配列データを出力
        report_data.each do |key, value|
          next unless value.is_a?(Array)
          csv << []
          csv << [key.to_s.humanize]

          if value.any? && value.first.is_a?(Hash)
            # ヘッダー行を追加
            headers = value.first.keys.map { |k| k.to_s.humanize }
            csv << headers

            # データ行を追加
            value.each do |item|
              csv << item.values
            end
          else
            # 単純な配列
            value.each do |item|
              csv << [item]
            end
          end
        end
      end
    end
  end

  # HTMLレポートを生成
  def generate_html_report(report_type, report_data, file_path, options)
    # HTMLレポート生成
    # 実際のアプリケーションに合わせてカスタマイズ

    # テンプレートが指定されている場合
    if options[:template].present?
      # テンプレートを使用してレポートを生成
      # 実装例: html_content = render_to_string(template: options[:template], locals: { data: report_data })
    else
      # デフォルトのレポート生成
      # 実装例: html_content = generate_default_html(report_type, report_data)
    end

    # ファイルに保存
    # 実装例: File.open(file_path, 'w') { |file| file.write(html_content) }

    # シミュレーション用
    File.open(file_path, 'w') do |file|
      file.write("<html><head><title>#{report_data[:title]}</title></head><body>")
      file.write("<h1>#{report_data[:title]}</h1>")
      file.write("<h2>#{report_data[:subtitle]}</h2>")
      file.write("<p>Generated at: #{report_data[:generated_at]}</p>")
      file.write("<pre>#{report_data.to_json}</pre>")
      file.write("</body></html>")
    end
  end

  # JSONレポートを生成
  def generate_json_report(report_type, report_data, file_path, options)
    require 'json'

    # JSONファイルを作成
    File.open(file_path, 'w') do |file|
      file.write(JSON.pretty_generate(report_data))
    end
  end

  # ファイルパスを生成
  def generate_file_path(report_type, format)
    timestamp = Time.current.strftime('%Y%m%d%H%M%S')
    filename = "#{report_type}_report_#{timestamp}.#{format}"
    File.join(Rails.root, 'tmp', 'reports', filename)
  end

  # エラー処理
  def handle_error(message, options, exception = nil)
    # エラーをログに記録
    Rails.logger.error("ReportGenerationJob Error: #{message}")
    Rails.logger.error(exception.backtrace.join("\n")) if exception

    # エラーコールバックが指定されている場合
    if options[:on_error].present?
      if options[:on_error].is_a?(Proc)
        options[:on_error].call(message, exception)
      elsif options[:on_error].is_a?(String) || options[:on_error].is_a?(Symbol)
        method_name = options[:on_error].to_s
        if respond_to?(method_name)
          send(method_name, message, exception)
        end
      end
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'report_generation_error',
        message: message,
        details: {
          report_type: report_type,
          format: options[:format],
          user_id: options[:user_id],
          error: exception&.message,
          backtrace: exception&.backtrace&.first(10)
        }
      )
    end

    # 通知を送信
    if defined?(NotificationService) && options[:user_id].present?
      NotificationService.notify(
        recipient_type: 'user',
        recipient_id: options[:user_id],
        notification_type: 'report_generation_error',
        title: 'Report Generation Error',
        message: message,
        reference_type: 'Report',
        reference_id: nil
      )
    end
  end

  # 完了時の処理
  def handle_completion(file_path, report_type, options)
    # 結果を初期化
    result = {
      file_path: file_path,
      report_type: report_type,
      format: options[:format],
      timestamp: Time.current
    }

    # 結果をログに記録
    Rails.logger.info("ReportGenerationJob Completed: #{result.to_json}")

    # 完了コールバックが指定されている場合
    if options[:on_complete].present?
      if options[:on_complete].is_a?(Proc)
        options[:on_complete].call(result)
      elsif options[:on_complete].is_a?(String) || options[:on_complete].is_a?(Symbol)
        method_name = options[:on_complete].to_s
        if respond_to?(method_name)
          send(method_name, result)
        end
      end
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'report_generation_completed',
        message: "Report generation completed: #{File.basename(file_path)}",
        details: {
          file_path: file_path,
          report_type: report_type,
          format: options[:format],
          user_id: options[:user_id]
        }
      )
    end

    # 通知を送信
    if defined?(NotificationService) && options[:user_id].present?
      NotificationService.notify(
        recipient_type: 'user',
        recipient_id: options[:user_id],
        notification_type: 'report_generation_completed',
        title: 'Report Generation Completed',
        message: "Report generation completed: #{File.basename(file_path)}",
        reference_type: 'Report',
        reference_id: nil
      )
    end

    result
  end
end
