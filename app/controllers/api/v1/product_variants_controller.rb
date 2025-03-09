module Api
  module V1
    class ProductVariantsController < BaseController
      skip_before_action :authenticate_user, only: [:index, :show]
      before_action :set_product_variant, only: [:show, :update, :destroy]

      # GET /api/v1/product_variants
      def index
        @product_variants = ProductVariant.all

        # 商品IDでフィルタリング
        @product_variants = @product_variants.where(product_id: params[:product_id]) if params[:product_id].present?

        render_success(@product_variants)
      end

      # GET /api/v1/product_variants/:id
      def show
        render_success(@product_variant)
      end

      # POST /api/v1/product_variants
      def create
        @product_variant = ProductVariant.new(product_variant_params)

        if @product_variant.save
          render_success(@product_variant, :created)
        else
          render_error(@product_variant.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/product_variants/:id
      def update
        if @product_variant.update(product_variant_params)
          render_success(@product_variant)
        else
          render_error(@product_variant.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/product_variants/:id
      def destroy
        @product_variant.destroy
        render_success({ message: 'Product variant deleted successfully' })
      end

      private

      def set_product_variant
        @product_variant = ProductVariant.find(params[:id])
      end

      def product_variant_params
        params.require(:product_variant).permit(
          :product_id, :sku, :barcode, :price, :sale_price, :cost_price,
          :quantity, :weight, :width, :height, :depth, :active,
          :attribute_value_1, :attribute_value_2, :attribute_value_3,
          :attribute_value_4, :attribute_value_5
        )
      end
    end
  end
end
