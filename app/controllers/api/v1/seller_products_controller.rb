module Api
  module V1
    class SellerProductsController < BaseController
      before_action :set_seller_product, only: [:show, :update, :destroy]
      before_action :ensure_seller, except: [:index, :show]

      # GET /api/v1/seller_products
      def index
        @seller_products = SellerProduct.all

        # セラーIDでフィルタリング
        @seller_products = @seller_products.where(seller_id: params[:seller_id]) if params[:seller_id].present?

        # 商品IDでフィルタリング
        @seller_products = @seller_products.where(product_id: params[:product_id]) if params[:product_id].present?

        # アクティブな商品のみ表示（管理者以外）
        @seller_products = @seller_products.where(active: true) unless current_user&.admin?

        render_success(@seller_products)
      end

      # GET /api/v1/seller_products/:id
      def show
        # アクティブな商品のみ表示（管理者または商品のセラー以外）
        unless @seller_product.active || current_user&.admin? || @seller_product.seller.user_id == current_user&.id
          render_forbidden
          return
        end

        render_success(@seller_product)
      end

      # POST /api/v1/seller_products
      def create
        @seller_product = SellerProduct.new(seller_product_params)
        @seller_product.seller_id = current_seller.id

        if @seller_product.save
          render_success(@seller_product, :created)
        else
          render_error(@seller_product.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/seller_products/:id
      def update
        # 商品のセラーまたは管理者のみ更新可能
        unless @seller_product.seller_id == current_seller&.id || current_user.admin?
          render_forbidden
          return
        end

        if @seller_product.update(seller_product_params)
          render_success(@seller_product)
        else
          render_error(@seller_product.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/seller_products/:id
      def destroy
        # 商品のセラーまたは管理者のみ削除可能
        unless @seller_product.seller_id == current_seller&.id || current_user.admin?
          render_forbidden
          return
        end

        @seller_product.destroy
        render_success({ message: 'Seller product deleted successfully' })
      end

      # PUT /api/v1/seller_products/update_inventory
      def update_inventory
        @seller_product = SellerProduct.find(params[:id])

        # 商品のセラーまたは管理者のみ更新可能
        unless @seller_product.seller_id == current_seller&.id || current_user.admin?
          render_forbidden
          return
        end

        old_quantity = @seller_product.quantity

        if @seller_product.update(quantity: params[:quantity])
          # 在庫の更新
          inventory = Inventory.find_or_initialize_by(
            product_id: @seller_product.product_id,
            warehouse_id: params[:warehouse_id] || Warehouse.first.id
          )

          quantity_diff = @seller_product.quantity - old_quantity
          new_inventory_quantity = inventory.quantity + quantity_diff

          inventory.update(quantity: new_inventory_quantity)

          # 在庫移動の記録
          if quantity_diff != 0
            StockMovement.create(
              product_id: @seller_product.product_id,
              warehouse_id: inventory.warehouse_id,
              quantity: quantity_diff,
              movement_type: quantity_diff > 0 ? 'in' : 'out',
              reference: "Seller inventory update",
              notes: "Updated by seller #{current_seller.business_name}"
            )
          end

          render_success({
            seller_product: @seller_product,
            old_quantity: old_quantity,
            new_quantity: @seller_product.quantity,
            inventory_quantity: new_inventory_quantity
          })
        else
          render_error(@seller_product.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/seller_products/update_price
      def update_price
        @seller_product = SellerProduct.find(params[:id])

        # 商品のセラーまたは管理者のみ更新可能
        unless @seller_product.seller_id == current_seller&.id || current_user.admin?
          render_forbidden
          return
        end

        old_price = @seller_product.price

        if @seller_product.update(
          price: params[:price],
          sale_price: params[:sale_price],
          sale_start_date: params[:sale_start_date],
          sale_end_date: params[:sale_end_date]
        )
          # 価格履歴の記録
          PriceHistory.create(
            product_id: @seller_product.product_id,
            old_price: old_price,
            new_price: @seller_product.price,
            changed_by: "Seller #{current_seller.business_name}"
          )

          render_success({
            seller_product: @seller_product,
            old_price: old_price,
            new_price: @seller_product.price
          })
        else
          render_error(@seller_product.errors.full_messages.join(', '))
        end
      end

      private

      def set_seller_product
        @seller_product = SellerProduct.find(params[:id])
      end

      def seller_product_params
        params.require(:seller_product).permit(
          :product_id, :price, :sale_price, :quantity, :active,
          :sale_start_date, :sale_end_date, :condition, :handling_time,
          :shipping_price, :shipping_method, :notes
        )
      end

      def ensure_seller
        unless current_seller
          render_error('You must be registered as a seller to perform this action', :forbidden)
          return
        end

        unless current_seller.active && current_seller.verified
          render_error('Your seller account is not active or verified', :forbidden)
          return
        end
      end

      def current_seller
        @current_seller ||= Seller.find_by(user_id: current_user.id)
      end
    end
  end
end
