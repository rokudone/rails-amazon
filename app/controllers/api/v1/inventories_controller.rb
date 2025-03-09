module Api
  module V1
    class InventoriesController < BaseController
      before_action :set_inventory, only: [:show, :update, :destroy]

      # GET /api/v1/inventories
      def index
        @inventories = Inventory.all

        # 商品IDでフィルタリング
        @inventories = @inventories.where(product_id: params[:product_id]) if params[:product_id].present?

        # 倉庫IDでフィルタリング
        @inventories = @inventories.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id].present?

        # 在庫レベルでフィルタリング
        @inventories = @inventories.where('quantity <= ?', params[:low_stock_threshold]) if params[:low_stock_threshold].present?

        render_success(@inventories)
      end

      # GET /api/v1/inventories/:id
      def show
        render_success(@inventory)
      end

      # POST /api/v1/inventories
      def create
        @inventory = Inventory.new(inventory_params)

        if @inventory.save
          render_success(@inventory, :created)
        else
          render_error(@inventory.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/inventories/:id
      def update
        if @inventory.update(inventory_params)
          render_success(@inventory)
        else
          render_error(@inventory.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/inventories/:id
      def destroy
        @inventory.destroy
        render_success({ message: 'Inventory deleted successfully' })
      end

      # GET /api/v1/inventories/check
      def check
        if params[:product_id].present?
          @inventory = Inventory.where(product_id: params[:product_id])
          total_quantity = @inventory.sum(:quantity)

          render_success({
            product_id: params[:product_id],
            total_quantity: total_quantity,
            available: total_quantity > 0,
            inventories: @inventory
          })
        elsif params[:sku].present?
          product = Product.find_by(sku: params[:sku])
          if product
            @inventory = Inventory.where(product_id: product.id)
            total_quantity = @inventory.sum(:quantity)

            render_success({
              product_id: product.id,
              sku: params[:sku],
              total_quantity: total_quantity,
              available: total_quantity > 0,
              inventories: @inventory
            })
          else
            render_error('Product not found with the given SKU')
          end
        else
          render_error('Product ID or SKU is required')
        end
      end

      # PUT /api/v1/inventories/update_stock
      def update_stock
        if params[:product_id].present? && params[:quantity].present?
          @inventory = Inventory.find_or_initialize_by(
            product_id: params[:product_id],
            warehouse_id: params[:warehouse_id] || Warehouse.first.id
          )

          old_quantity = @inventory.quantity || 0
          new_quantity = old_quantity + params[:quantity].to_i

          if @inventory.update(quantity: new_quantity)
            # 在庫移動の記録
            StockMovement.create(
              product_id: params[:product_id],
              warehouse_id: @inventory.warehouse_id,
              quantity: params[:quantity].to_i,
              movement_type: params[:quantity].to_i > 0 ? 'in' : 'out',
              reference: params[:reference],
              notes: params[:notes]
            )

            # 在庫アラートの確認
            check_inventory_alerts(@inventory)

            render_success({
              inventory: @inventory,
              old_quantity: old_quantity,
              new_quantity: new_quantity,
              difference: params[:quantity].to_i
            })
          else
            render_error(@inventory.errors.full_messages.join(', '))
          end
        else
          render_error('Product ID and quantity are required')
        end
      end

      private

      def set_inventory
        @inventory = Inventory.find(params[:id])
      end

      def inventory_params
        params.require(:inventory).permit(
          :product_id, :warehouse_id, :quantity, :reserved_quantity,
          :reorder_level, :reorder_quantity, :last_counted_at, :notes
        )
      end

      def check_inventory_alerts(inventory)
        # 在庫が再注文レベル以下になった場合にアラートを作成
        if inventory.quantity <= inventory.reorder_level
          InventoryAlert.create(
            product_id: inventory.product_id,
            warehouse_id: inventory.warehouse_id,
            alert_type: 'low_stock',
            message: "Product #{inventory.product.name} (ID: #{inventory.product_id}) is below reorder level. Current quantity: #{inventory.quantity}, Reorder level: #{inventory.reorder_level}",
            resolved: false
          )
        end
      end
    end
  end
end
