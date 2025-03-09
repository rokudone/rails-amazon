module Api
  module V1
    class AuthenticationController < BaseController
      skip_before_action :authenticate_user, except: [:logout]

      # POST /api/v1/authentication/login
      def login
        @user = User.find_by(email: params[:email])

        if @user&.authenticate(params[:password])
          if @user.active?
            token = generate_token(@user)
            @user.update(last_login_at: Time.current)

            # ユーザーセッションの作成
            @user.user_sessions.create(
              token: token,
              ip_address: request.remote_ip,
              user_agent: request.user_agent,
              device_type: detect_device_type,
              expired_at: 24.hours.from_now
            )

            render_success({
              user: @user,
              token: token,
              expires_at: 24.hours.from_now
            })
          else
            render_error('Account is inactive or locked', :forbidden)
          end
        else
          # 失敗したログイン試行を記録
          @user&.increment_failed_attempts!
          render_error('Invalid email or password', :unauthorized)
        end
      end

      # DELETE /api/v1/authentication/logout
      def logout
        # 現在のセッションを無効化
        current_session = current_user.user_sessions.find_by(token: request_token)
        if current_session
          current_session.update(expired_at: Time.current)
          render_success({ message: 'Logged out successfully' })
        else
          render_error('Session not found', :not_found)
        end
      end

      # POST /api/v1/authentication/refresh_token
      def refresh_token
        old_token = request_token
        session = UserSession.find_by(token: old_token)

        if session && session.user && (session.expired_at.nil? || session.expired_at > Time.current)
          # 古いセッションを無効化
          session.update(expired_at: Time.current)

          # 新しいトークンを生成
          new_token = generate_token(session.user)

          # 新しいセッションを作成
          session.user.user_sessions.create(
            token: new_token,
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
            device_type: detect_device_type,
            expired_at: 24.hours.from_now
          )

          render_success({
            token: new_token,
            expires_at: 24.hours.from_now
          })
        else
          render_error('Invalid or expired token', :unauthorized)
        end
      end

      # POST /api/v1/authentication/forgot_password
      def forgot_password
        @user = User.find_by(email: params[:email])

        if @user
          token = @user.reset_password!

          # TODO: パスワードリセットメールの送信
          # UserMailer.reset_password_email(@user, token).deliver_later

          render_success({ message: 'Password reset instructions sent to your email' })
        else
          render_error('Email not found', :not_found)
        end
      end

      # POST /api/v1/authentication/reset_password
      def reset_password
        @user = User.find_by(reset_password_token: params[:token])

        if @user && @user.reset_password_sent_at > 24.hours.ago
          if @user.update(
            password: params[:password],
            password_confirmation: params[:password_confirmation],
            reset_password_token: nil,
            reset_password_sent_at: nil
          )
            render_success({ message: 'Password has been reset successfully' })
          else
            render_error(@user.errors.full_messages.join(', '))
          end
        else
          render_error('Invalid or expired token', :unauthorized)
        end
      end

      private

      def generate_token(user)
        payload = {
          user_id: user.id,
          email: user.email,
          exp: 24.hours.from_now.to_i
        }
        JWT.encode(payload, Rails.application.credentials.secret_key_base)
      end

      def request_token
        request.headers['Authorization']&.split(' ')&.last
      end

      def detect_device_type
        user_agent = request.user_agent.downcase
        if user_agent.match?(/mobile|android|iphone|ipad|ipod/)
          'mobile'
        elsif user_agent.match?(/tablet/)
          'tablet'
        else
          'desktop'
        end
      end
    end
  end
end
