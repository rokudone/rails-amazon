module Api
  module V1
    class SellerTransactionsController < BaseController
      before_action :set_seller_transaction, only: [:show]
      before_action :ensure_seller, except: [:show]
      before_action :ensure_admin, only: [:show]

      # GET /api/v1/seller_transactions
      def index
        @seller_transactions = SellerTransaction.where(seller_id: current_seller.id)

        # ステータスでフィルタリング
        @seller_transactions = @seller_transactions.where(status: params[:status]) if params[:status].present?

        # 日付範囲でフィルタリング
        @seller_transactions = @seller_transactions.where('created_at >= ?', params[:start_date]) if params[:start_date].present?
        @seller_transactions = @seller_transactions.where('created_at <= ?', params[:end_date]) if params[:end_date].present?

        # 金額範囲でフィルタリング
        @seller_transactions = @seller_transactions.where('amount >= ?', params[:min_amount]) if params[:min_amount].present?
        @seller_transactions = @seller_transactions.where('amount <= ?', params[:max_amount]) if params[:max_amount].present?

        # ソート
        case params[:sort]
        when 'amount_asc'
          @seller_transactions = @seller_transactions.order(amount: :asc)
        when 'amount_desc'
          @seller_transactions = @seller_transactions.order(amount: :desc)
        when 'newest'
          @seller_transactions = @seller_transactions.order(created_at: :desc)
        when 'oldest'
          @seller_transactions = @seller_transactions.order(created_at: :asc)
        else
          @seller_transactions = @seller_transactions.order(created_at: :desc)
        end

        # ページネーション
        @seller_transactions = @seller_transactions.page(params[:page] || 1).per(params[:per_page] || 20)

        render_success({
          transactions: @seller_transactions,
          total: @seller_transactions.total_count,
          total_pages: @seller_transactions.total_pages,
          current_page: @seller_transactions.current_page
        })
      end

      # GET /api/v1/seller_transactions/:id
      def show
        render_success(@seller_transaction)
      end

      # GET /api/v1/seller_transactions/history
      def history
        # 月別の取引履歴を取得
        @monthly_transactions = SellerTransaction.where(seller_id: current_seller.id)
                                              .where('created_at >= ?', 1.year.ago)
                                              .group("DATE_FORMAT(created_at, '%Y-%m')")
                                              .select("DATE_FORMAT(created_at, '%Y-%m') as month, SUM(amount) as total_amount, COUNT(*) as transaction_count")
                                              .order('month DESC')

        # 取引タイプ別の合計
        @transaction_types = SellerTransaction.where(seller_id: current_seller.id)
                                           .where('created_at >= ?', 1.year.ago)
                                           .group(:transaction_type)
                                           .select('transaction_type, SUM(amount) as total_amount, COUNT(*) as transaction_count')
                                           .order('total_amount DESC')

        # 未払いの取引
        @pending_transactions = SellerTransaction.where(seller_id: current_seller.id, status: 'pending')
                                              .sum(:amount)

        # 完了した取引
        @completed_transactions = SellerTransaction.where(seller_id: current_seller.id, status: 'completed')
                                                .sum(:amount)

        # 今月の取引
        @current_month_transactions = SellerTransaction.where(seller_id: current_seller.id)
                                                    .where('created_at >= ?', Time.current.beginning_of_month)
                                                    .sum(:amount)

        # 先月の取引
        @last_month_transactions = SellerTransaction.where(seller_id: current_seller.id)
                                                 .where('created_at >= ? AND created_at < ?', 1.month.ago.beginning_of_month, Time.current.beginning_of_month)
                                                 .sum(:amount)

        render_success({
          monthly_transactions: @monthly_transactions,
          transaction_types: @transaction_types,
          pending_transactions: @pending_transactions,
          completed_transactions: @completed_transactions,
          current_month_transactions: @current_month_transactions,
          last_month_transactions: @last_month_transactions
        })
      end

      private

      def set_seller_transaction
        @seller_transaction = SellerTransaction.find(params[:id])

        # 自分の取引またはアドミンのみアクセス可能
        unless @seller_transaction.seller_id == current_seller&.id || current_user.admin?
          render_forbidden
          return
        end
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

      def ensure_admin
        unless current_user.admin?
          render_forbidden
          return
        end
      end

      def current_seller
        @current_seller ||= Seller.find_by(user_id: current_user.id)
      end
    end
  end
end
