module Api
  module V1
    class ProductImagesController < BaseController
      skip_before_action :authenticate_user, only: [:index, :show]
      before_action :set_product_image, only: [:show, :update, :destroy]

      # GET /api/v1/product_images
      def index
        @product_images = ProductImage.all

        # 商品IDでフィルタリング
        @product_images = @product_images.where(product_id: params[:product_id]) if params[:product_id].present?

        render_success(@product_images)
      end

      # GET /api/v1/product_images/:id
      def show
        render_success(@product_image)
      end

      # POST /api/v1/product_images
      def create
        @product_image = ProductImage.new(product_image_params)

        if @product_image.save
          render_success(@product_image, :created)
        else
          render_error(@product_image.errors.full_messages.join(', '))
        end
      end

      # POST /api/v1/product_images/upload
      def upload
        # 複数画像のアップロード処理
        if params[:images].present?
          uploaded_images = []
          failed_images = []

          params[:images].each do |image|
            product_image = ProductImage.new(
              product_id: params[:product_id],
              image: image,
              alt_text: params[:alt_text],
              display_order: params[:display_order]
            )

            if product_image.save
              uploaded_images << product_image
            else
              failed_images << {
                filename: image.original_filename,
                errors: product_image.errors.full_messages
              }
            end
          end

          render_success({
            uploaded_images: uploaded_images,
            failed_images: failed_images,
            message: "#{uploaded_images.count} images uploaded successfully, #{failed_images.count} failed"
          })
        else
          render_error('No images provided')
        end
      end

      # PUT /api/v1/product_images/:id
      def update
        if @product_image.update(product_image_params)
          render_success(@product_image)
        else
          render_error(@product_image.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/product_images/:id
      def destroy
        @product_image.destroy
        render_success({ message: 'Product image deleted successfully' })
      end

      private

      def set_product_image
        @product_image = ProductImage.find(params[:id])
      end

      def product_image_params
        params.require(:product_image).permit(
          :product_id, :image, :alt_text, :display_order, :is_primary
        )
      end
    end
  end
end
