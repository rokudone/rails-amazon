class InventoryService
  attr_reader :product, :warehouse

  def initialize(product = nil, warehouse = nil)
    @product = product
    @warehouse = warehouse
  end

  # 在庫管理
  def manage_inventory(product_id, warehouse_id, quantity, movement_type, reference = nil, notes = nil)
    @product = Product.find_by(id: product_id)
    @warehouse = Warehouse.find_by(id: warehouse_id)

    return false unless @product && @warehouse

    # 在庫の取得または作成
    inventory = Inventory.find_or_initialize_by(
      product_id: @product.id,
      warehouse_id: @warehouse.id
    )

    old_quantity = inventory.quantity || 0

    # 在庫の更新
    case movement_type
    when 'in'
      # 入庫
      inventory.quantity = old_quantity + quantity
    when 'out'
      # 出庫
      if old_quantity >= quantity
        inventory.quantity = old_quantity - quantity
      else
        @error = 'Not enough inventory'
        return false
      end
    when 'set'
      # 在庫数設定
      inventory.quantity = quantity
    else
      @error = 'Invalid movement type'
      return false
    end

    if inventory.save
      # 在庫移動の記録
      StockMovement.create(
        product_id: @product.id,
        warehouse_id: @warehouse.id,
        quantity: movement_type == 'set' ? (quantity - old_quantity) : (movement_type == 'in' ? quantity : -quantity),
        movement_type: movement_type == 'set' ? (quantity > old_quantity ? 'in' : 'out') : movement_type,
        reference: reference,
        notes: notes
      )

      # 在庫アラートのチェック
      check_inventory_alerts(inventory)

      true
    else
      @error = inventory.errors.full_messages.join(', ')
      false
    end
  end

  # 在庫更新
  def update_stock(quantity, options = {})
    return false unless @product

    warehouse_id = options[:warehouse_id] || @warehouse&.id || Warehouse.first&.id
    return false unless warehouse_id

    manage_inventory(
      @product.id,
      warehouse_id,
      quantity,
      'set',
      options[:reference] || 'Stock update',
      options[:notes]
    )
  end

  # 在庫確認
  def check_stock(product_id = nil)
    product_id ||= @product&.id
    return { available: false, quantity: 0 } unless product_id

    # 全倉庫の在庫を合計
    total_quantity = Inventory.where(product_id: product_id).sum(:quantity)

    # 倉庫ごとの在庫
    inventory_by_warehouse = Inventory.where(product_id: product_id)
                                    .joins(:warehouse)
                                    .select('inventories.*, warehouses.name as warehouse_name')

    {
      available: total_quantity > 0,
      quantity: total_quantity,
      inventory_by_warehouse: inventory_by_warehouse
    }
  end

  # 在庫アラート
  def inventory_alerts(options = {})
    alerts = InventoryAlert.all

    # 製品IDでフィルタリング
    alerts = alerts.where(product_id: options[:product_id]) if options[:product_id].present?

    # 倉庫IDでフィルタリング
    alerts = alerts.where(warehouse_id: options[:warehouse_id]) if options[:warehouse_id].present?

    # アラートタイプでフィルタリング
    alerts = alerts.where(alert_type: options[:alert_type]) if options[:alert_type].present?

    # 解決済みステータスでフィルタリング
    alerts = alerts.where(resolved: options[:resolved]) if options[:resolved].present?

    # 日付範囲でフィルタリング
    alerts = alerts.where('created_at >= ?', options[:start_date]) if options[:start_date].present?
    alerts = alerts.where('created_at <= ?', options[:end_date]) if options[:end_date].present?

    # ソート
    case options[:sort]
    when 'newest'
      alerts = alerts.order(created_at: :desc)
    when 'oldest'
      alerts = alerts.order(created_at: :asc)
    else
      alerts = alerts.order(created_at: :desc)
    end

    # ページネーション
    page = options[:page] || 1
    per_page = options[:per_page] || 20

    alerts.page(page).per(per_page)
  end

  # 在庫移動
  def move_stock(source_warehouse_id, destination_warehouse_id, quantity, options = {})
    return false unless @product

    # 出庫元の在庫確認
    source_inventory = Inventory.find_by(
      product_id: @product.id,
      warehouse_id: source_warehouse_id
    )

    unless source_inventory && source_inventory.quantity >= quantity
      @error = 'Not enough inventory in source warehouse'
      return false
    end

    # 出庫処理
    manage_inventory(
      @product.id,
      source_warehouse_id,
      quantity,
      'out',
      options[:reference] || 'Stock movement',
      options[:notes] || "Moving to warehouse ID: #{destination_warehouse_id}"
    )

    # 入庫処理
    manage_inventory(
      @product.id,
      destination_warehouse_id,
      quantity,
      'in',
      options[:reference] || 'Stock movement',
      options[:notes] || "Moving from warehouse ID: #{source_warehouse_id}"
    )
  end

  # 在庫調整
  def adjust_stock(adjustment_quantity, reason, options = {})
    return false unless @product && @warehouse

    # 現在の在庫を取得
    inventory = Inventory.find_by(
      product_id: @product.id,
      warehouse_id: @warehouse.id
    )

    old_quantity = inventory&.quantity || 0
    new_quantity = old_quantity + adjustment_quantity

    # 在庫がマイナスにならないようにチェック
    if new_quantity < 0
      @error = 'Adjustment would result in negative inventory'
      return false
    end

    # 在庫の更新
    manage_inventory(
      @product.id,
      @warehouse.id,
      new_quantity,
      'set',
      options[:reference] || 'Stock adjustment',
      options[:notes] || "Reason: #{reason}"
    )
  end

  # 在庫履歴
  def stock_history(options = {})
    movements = StockMovement.all

    # 製品IDでフィルタリング
    movements = movements.where(product_id: options[:product_id] || @product&.id) if options[:product_id].present? || @product

    # 倉庫IDでフィルタリング
    movements = movements.where(warehouse_id: options[:warehouse_id] || @warehouse&.id) if options[:warehouse_id].present? || @warehouse

    # 移動タイプでフィルタリング
    movements = movements.where(movement_type: options[:movement_type]) if options[:movement_type].present?

    # 日付範囲でフィルタリング
    movements = movements.where('created_at >= ?', options[:start_date]) if options[:start_date].present?
    movements = movements.where('created_at <= ?', options[:end_date]) if options[:end_date].present?

    # ソート
    case options[:sort]
    when 'newest'
      movements = movements.order(created_at: :desc)
    when 'oldest'
      movements = movements.order(created_at: :asc)
    else
      movements = movements.order(created_at: :desc)
    end

    # ページネーション
    page = options[:page] || 1
    per_page = options[:per_page] || 20

    movements.page(page).per(per_page)
  end

  # 在庫レベル確認
  def check_inventory_level
    return {} unless @product

    # 全倉庫の在庫を合計
    total_quantity = Inventory.where(product_id: @product.id).sum(:quantity)

    # 再注文レベルを取得
    reorder_level = @product.inventories.average(:reorder_level).to_i

    # 在庫状態の判定
    if total_quantity <= 0
      status = 'out_of_stock'
    elsif total_quantity <= reorder_level
      status = 'low_stock'
    else
      status = 'in_stock'
    end

    {
      product_id: @product.id,
      product_name: @product.name,
      total_quantity: total_quantity,
      reorder_level: reorder_level,
      status: status
    }
  end

  # 在庫予測
  def forecast_inventory(days = 30)
    return {} unless @product

    # 現在の在庫
    current_stock = Inventory.where(product_id: @product.id).sum(:quantity)

    # 過去30日間の販売数
    end_date = Date.current
    start_date = end_date - 30.days

    sold_items = OrderItem.joins(:order)
                        .where(product_id: @product.id)
                        .where(orders: { status: ['paid', 'shipped', 'delivered', 'completed'] })
                        .where('orders.created_at BETWEEN ? AND ?', start_date, end_date)
                        .sum(:quantity)

    # 1日あたりの平均販売数
    daily_sales = sold_items / 30.0

    # 在庫切れまでの日数
    days_until_stockout = daily_sales > 0 ? (current_stock / daily_sales).floor : nil

    # 予測在庫
    forecast = []

    days.times do |i|
      day = Date.current + i.days
      projected_stock = [current_stock - (daily_sales * i), 0].max

      forecast << {
        date: day,
        projected_stock: projected_stock.round
      }
    end

    {
      product_id: @product.id,
      product_name: @product.name,
      current_stock: current_stock,
      daily_sales_average: daily_sales.round(2),
      days_until_stockout: days_until_stockout,
      forecast: forecast
    }
  end

  # エラーメッセージの取得
  def error_message
    @error
  end

  private

  # 在庫アラートのチェック
  def check_inventory_alerts(inventory)
    # 在庫が再注文レベル以下になった場合にアラートを作成
    if inventory.reorder_level && inventory.quantity <= inventory.reorder_level
      InventoryAlert.create(
        product_id: inventory.product_id,
        warehouse_id: inventory.warehouse_id,
        alert_type: 'low_stock',
        message: "Product #{Product.find(inventory.product_id).name} (ID: #{inventory.product_id}) is below reorder level. Current quantity: #{inventory.quantity}, Reorder level: #{inventory.reorder_level}",
        resolved: false
      )
    end

    # 在庫切れの場合にアラートを作成
    if inventory.quantity <= 0
      InventoryAlert.create(
        product_id: inventory.product_id,
        warehouse_id: inventory.warehouse_id,
        alert_type: 'out_of_stock',
        message: "Product #{Product.find(inventory.product_id).name} (ID: #{inventory.product_id}) is out of stock.",
        resolved: false
      )
    end
  end
end
