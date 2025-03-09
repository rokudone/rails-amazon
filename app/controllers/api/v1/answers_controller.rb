module Api
  module V1
    class AnswersController < BaseController
      skip_before_action :authenticate_user, only: [:index, :show]
      before_action :set_question
      before_action :set_answer, only: [:show, :update, :destroy, :approve]

      # GET /api/v1/questions/:question_id/answers
      def index
        @answers = @question.answers

        # 承認済みの回答のみ表示（管理者以外）
        @answers = @answers.where(approved: true) unless current_user&.admin?

        # ソート
        case params[:sort]
        when 'newest'
          @answers = @answers.order(created_at: :desc)
        when 'oldest'
          @answers = @answers.order(created_at: :asc)
        else
          @answers = @answers.order(created_at: :asc)
        end

        render_success(@answers)
      end

      # GET /api/v1/questions/:question_id/answers/:id
      def show
        # 承認済みの回答のみ表示（管理者以外）
        unless @answer.approved || current_user&.admin?
          render_forbidden
          return
        end

        render_success(@answer)
      end

      # POST /api/v1/questions/:question_id/answers
      def create
        @answer = @question.answers.new(answer_params)
        @answer.user_id = current_user.id
        @answer.approved = current_user.admin? # 管理者の場合は自動承認

        if @answer.save
          render_success(@answer, :created)
        else
          render_error(@answer.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/questions/:question_id/answers/:id
      def update
        # 回答作成者または管理者のみ更新可能
        unless @answer.user_id == current_user.id || current_user.admin?
          render_forbidden
          return
        end

        if @answer.update(answer_params)
          # 管理者以外が更新した場合は承認ステータスをリセット
          @answer.update(approved: false) unless current_user.admin?

          render_success(@answer)
        else
          render_error(@answer.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/questions/:question_id/answers/:id
      def destroy
        # 回答作成者または管理者のみ削除可能
        unless @answer.user_id == current_user.id || current_user.admin?
          render_forbidden
          return
        end

        @answer.destroy
        render_success({ message: 'Answer deleted successfully' })
      end

      # PUT /api/v1/questions/:question_id/answers/:id/approve
      def approve
        # 管理者のみ承認可能
        unless current_user.admin?
          render_forbidden
          return
        end

        if @answer.update(approved: params[:approved])
          render_success({
            answer: @answer,
            message: params[:approved] ? 'Answer approved successfully' : 'Answer disapproved successfully'
          })
        else
          render_error(@answer.errors.full_messages.join(', '))
        end
      end

      private

      def set_question
        @question = Question.find(params[:question_id])
      end

      def set_answer
        @answer = @question.answers.find(params[:id])
      end

      def answer_params
        params.require(:answer).permit(:content)
      end
    end
  end
end
