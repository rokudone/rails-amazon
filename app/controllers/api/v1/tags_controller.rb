module Api
  module V1
    class TagsController < BaseController
      skip_before_action :authenticate_user, only: [:index, :show]
      before_action :set_tag, only: [:show, :update, :destroy]

      # GET /api/v1/tags
      def index
        @tags = Tag.all

        # 名前でフィルタリング
        @tags = @tags.where('name LIKE ?', "%#{params[:name]}%") if params[:name].present?

        # タイプでフィルタリング
        @tags = @tags.where(tag_type: params[:type]) if params[:type].present?

        # ソート
        case params[:sort]
        when 'name_asc'
          @tags = @tags.order(name: :asc)
        when 'name_desc'
          @tags = @tags.order(name: :desc)
        when 'popularity'
          @tags = @tags.left_joins(:product_tags)
                     .group('tags.id')
                     .order('COUNT(product_tags.id) DESC')
        else
          @tags = @tags.order(name: :asc)
        end

        render_success(@tags)
      end

      # GET /api/v1/tags/:id
      def show
        render_success(@tag)
      end

      # POST /api/v1/tags
      def create
        # 管理者のみ作成可能
        unless current_user.admin?
          render_forbidden
          return
        end

        @tag = Tag.new(tag_params)

        if @tag.save
          render_success(@tag, :created)
        else
          render_error(@tag.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/tags/:id
      def update
        # 管理者のみ更新可能
        unless current_user.admin?
          render_forbidden
          return
        end

        if @tag.update(tag_params)
          render_success(@tag)
        else
          render_error(@tag.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/tags/:id
      def destroy
        # 管理者のみ削除可能
        unless current_user.admin?
          render_forbidden
          return
        end

        @tag.destroy
        render_success({ message: 'Tag deleted successfully' })
      end

      # POST /api/v1/tags/tag_item
      def tag_item
        # 管理者のみタグ付け可能
        unless current_user.admin?
          render_forbidden
          return
        end

        tag = Tag.find(params[:tag_id])

        case params[:item_type]
        when 'product'
          item = Product.find(params[:item_id])

          # 既にタグ付けされていないかチェック
          if ProductTag.exists?(product_id: item.id, tag_id: tag.id)
            render_error('Product already tagged')
            return
          end

          product_tag = ProductTag.new(product_id: item.id, tag_id: tag.id)

          if product_tag.save
            render_success({
              product_tag: product_tag,
              message: 'Product tagged successfully'
            })
          else
            render_error(product_tag.errors.full_messages.join(', '))
          end
        else
          render_error('Unsupported item type')
        end
      end

      # DELETE /api/v1/tags/untag_item
      def untag_item
        # 管理者のみタグ解除可能
        unless current_user.admin?
          render_forbidden
          return
        end

        tag = Tag.find(params[:tag_id])

        case params[:item_type]
        when 'product'
          item = Product.find(params[:item_id])
          product_tag = ProductTag.find_by(product_id: item.id, tag_id: tag.id)

          unless product_tag
            render_error('Product not tagged with this tag')
            return
          end

          product_tag.destroy
          render_success({ message: 'Product untagged successfully' })
        else
          render_error('Unsupported item type')
        end
      end

      private

      def set_tag
        @tag = Tag.find(params[:id])
      end

      def tag_params
        params.require(:tag).permit(:name, :tag_type, :description)
      end
    end
  end
end
