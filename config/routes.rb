Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # ヘルスチェック
      get 'health_check', to: 'base#health_check'

      # 認証
      resources :authentication, only: [] do
        collection do
          post :login
          delete :logout
          post :refresh_token
          post :forgot_password
          post :reset_password
        end
      end

      # ユーザー
      resources :users do
        collection do
          get :me
          put :update_profile
          put :update_password
        end
        member do
          put :activate
          put :deactivate
        end
        resources :addresses
        resources :payment_methods
        resources :preferences, only: [:index, :update]
      end

      # 商品
      resources :products do
        collection do
          get :search
          get :featured
          get :bestsellers
          get :new_arrivals
        end
        member do
          get :related
        end
        resources :reviews
        resources :questions
      end

      # カテゴリ
      resources :categories do
        collection do
          get :tree
        end
        member do
          get :products
        end
      end

      # ブランド
      resources :brands do
        member do
          get :products
        end
      end

      # 商品バリアント
      resources :product_variants

      # 商品画像
      resources :product_images do
        collection do
          post :upload
        end
      end

      # 在庫
      resources :inventories do
        collection do
          get :check
          put :update_stock
        end
      end

      # 倉庫
      resources :warehouses

      # 注文
      resources :orders do
        collection do
          get :history
        end
        member do
          get :details
          put :update_status
        end
      end

      # 支払い
      resources :payments do
        collection do
          post :process_payment
          put :update_status
        end
      end

      # 配送
      resources :shipments do
        member do
          get :track
        end
      end

      # 返品
      resources :returns do
        collection do
          post :process_return
          post :process_refund
        end
      end

      # レビュー
      resources :reviews do
        member do
          put :approve
          post :vote
        end
      end

      # 質問
      resources :questions do
        member do
          put :approve
        end
        resources :answers
      end

      # 回答
      resources :answers do
        member do
          put :approve
        end
      end

      # プロモーション
      resources :promotions do
        member do
          post :apply
        end
      end

      # クーポン
      resources :coupons do
        collection do
          post :validate
          post :apply
        end
      end

      # セラー
      resources :sellers do
        collection do
          post :authenticate
        end
        member do
          post :rate
          get :products
        end
      end

      # セラー商品
      resources :seller_products do
        collection do
          put :update_inventory
          put :update_price
        end
      end

      # セラー取引
      resources :seller_transactions do
        collection do
          get :history
        end
      end

      # 通知
      resources :notifications do
        collection do
          put :mark_all_read
        end
        member do
          put :mark_read
        end
      end

      # カート
      resources :carts do
        collection do
          post :add_item
          put :update_item
          delete :remove_item
          get :calculate
          post :sync
        end
      end

      # ウィッシュリスト
      resources :wishlists

      # タグ
      resources :tags do
        collection do
          post :tag_item
          delete :untag_item
        end
      end

      # 検索
      resources :search, only: [:index] do
        collection do
          get :advanced
          get :filter
          get :sort
          get :facets
        end
      end

      # レコメンデーション
      resources :recommendations, only: [:index] do
        collection do
          get :personalized
        end
      end

      # チェックアウト
      resources :checkout, only: [] do
        collection do
          post :process
          post :confirm
          post :payment
        end
      end

      # 分析
      resources :analytics, only: [] do
        collection do
          get :sales
          get :users
          get :inventory
        end
      end

      # レポート
      resources :reports, only: [:index, :show] do
        collection do
          post :generate
          get :export
        end
      end

      # 一括操作
      resources :bulk_operations, only: [] do
        collection do
          post :products
          post :orders
          post :inventory
        end
      end

      # インポート/エクスポート
      resources :import_export, only: [] do
        collection do
          post :import
          get :export
        end
      end

      # Webhook
      resources :webhooks, only: [:create] do
        collection do
          post :event
        end
      end

      # ヘルスチェック
      resources :health_check, only: [:index] do
        collection do
          get :dependencies
        end
      end

      # メトリクス
      resources :metrics, only: [:index] do
        collection do
          get :performance
          get :business
        end
      end

      # サブスクリプション
      resources :subscriptions do
        collection do
          post :manage
          post :payment
        end
      end

      # フィードバック
      resources :feedback, only: [:create, :index] do
        collection do
          get :analyze
        end
      end

      # サイトマップ
      resources :sitemap, only: [:index]
    end
  end
end
