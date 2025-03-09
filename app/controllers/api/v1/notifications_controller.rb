module Api
  module V1
    class NotificationsController < BaseController
      before_action :set_notification, only: [:show, :update, :destroy, :mark_read]

      # GET /api/v1/notifications
      def index
        @notifications = current_user.notifications

        # 既読/未読でフィルタリング
        @notifications = @notifications.where(read: params[:read]) if params[:read].present?

        # タイプでフィルタリング
        @notifications = @notifications.where(notification_type: params[:type]) if params[:type].present?

        # ソート
        case params[:sort]
        when 'newest'
          @notifications = @notifications.order(created_at: :desc)
        when 'oldest'
          @notifications = @notifications.order(created_at: :asc)
        else
          @notifications = @notifications.order(created_at: :desc)
        end

        # ページネーション
        @notifications = @notifications.page(params[:page] || 1).per(params[:per_page] || 20)

        render_success({
          notifications: @notifications,
          total: @notifications.total_count,
          total_pages: @notifications.total_pages,
          current_page: @notifications.current_page,
          unread_count: current_user.notifications.where(read: false).count
        })
      end

      # GET /api/v1/notifications/:id
      def show
        render_success(@notification)
      end

      # POST /api/v1/notifications
      def create
        # 管理者のみ作成可能
        unless current_user.admin?
          render_forbidden
          return
        end

        @notification = Notification.new(notification_params)

        if @notification.save
          render_success(@notification, :created)
        else
          render_error(@notification.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/notifications/:id
      def update
        # 管理者のみ更新可能
        unless current_user.admin?
          render_forbidden
          return
        end

        if @notification.update(notification_params)
          render_success(@notification)
        else
          render_error(@notification.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/notifications/:id
      def destroy
        @notification.destroy
        render_success({ message: 'Notification deleted successfully' })
      end

      # PUT /api/v1/notifications/:id/mark_read
      def mark_read
        if @notification.update(read: true, read_at: Time.current)
          render_success({
            notification: @notification,
            message: 'Notification marked as read'
          })
        else
          render_error(@notification.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/notifications/mark_all_read
      def mark_all_read
        current_user.notifications.update_all(read: true, read_at: Time.current)

        render_success({
          message: 'All notifications marked as read',
          unread_count: 0
        })
      end

      private

      def set_notification
        @notification = current_user.notifications.find(params[:id])
      end

      def notification_params
        params.require(:notification).permit(
          :user_id, :title, :content, :notification_type, :read, :read_at,
          :link, :image, :priority
        )
      end
    end
  end
end
