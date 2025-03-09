module Api
  module V1
    class QuestionsController < BaseController
      skip_before_action :authenticate_user, only: [:index, :show]
      before_action :set_question, only: [:show, :update, :destroy, :approve]
      before_action :set_product, only: [:index, :create]

      # GET /api/v1/products/:product_id/questions
      # GET /api/v1/questions
      def index
        if @product
          @questions = @product.questions
        else
          @questions = Question.all
        end

        # 承認済みの質問のみ表示（管理者以外）
        @questions = @questions.where(approved: true) unless current_user&.admin?

        # ソート
        case params[:sort]
        when 'newest'
          @questions = @questions.order(created_at: :desc)
        when 'oldest'
          @questions = @questions.order(created_at: :asc)
        when 'most_answers'
          @questions = @questions.left_joins(:answers)
                              .group('questions.id')
                              .order('COUNT(answers.id) DESC')
        else
          @questions = @questions.order(created_at: :desc)
        end

        # ページネーション
        @questions = @questions.page(params[:page] || 1).per(params[:per_page] || 20)

        render_success({
          questions: @questions,
          total: @questions.total_count,
          total_pages: @questions.total_pages,
          current_page: @questions.current_page
        })
      end

      # GET /api/v1/questions/:id
      def show
        # 承認済みの質問のみ表示（管理者以外）
        unless @question.approved || current_user&.admin?
          render_forbidden
          return
        end

        # 回答も取得
        @answers = @question.answers.where(approved: true).order(created_at: :asc)

        render_success({
          question: @question,
          answers: @answers
        })
      end

      # POST /api/v1/products/:product_id/questions
      def create
        @question = @product.questions.new(question_params)
        @question.user_id = current_user.id
        @question.approved = current_user.admin? # 管理者の場合は自動承認

        if @question.save
          render_success(@question, :created)
        else
          render_error(@question.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/questions/:id
      def update
        # 質問作成者または管理者のみ更新可能
        unless @question.user_id == current_user.id || current_user.admin?
          render_forbidden
          return
        end

        if @question.update(question_params)
          # 管理者以外が更新した場合は承認ステータスをリセット
          @question.update(approved: false) unless current_user.admin?

          render_success(@question)
        else
          render_error(@question.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/questions/:id
      def destroy
        # 質問作成者または管理者のみ削除可能
        unless @question.user_id == current_user.id || current_user.admin?
          render_forbidden
          return
        end

        @question.destroy
        render_success({ message: 'Question deleted successfully' })
      end

      # PUT /api/v1/questions/:id/approve
      def approve
        # 管理者のみ承認可能
        unless current_user.admin?
          render_forbidden
          return
        end

        if @question.update(approved: params[:approved])
          render_success({
            question: @question,
            message: params[:approved] ? 'Question approved successfully' : 'Question disapproved successfully'
          })
        else
          render_error(@question.errors.full_messages.join(', '))
        end
      end

      private

      def set_question
        @question = Question.find(params[:id])
      end

      def set_product
        @product = Product.find(params[:product_id]) if params[:product_id].present?
      end

      def question_params
        params.require(:question).permit(:content)
      end
    end
  end
end
