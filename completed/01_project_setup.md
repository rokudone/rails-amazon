# 01. プロジェクト初期設定

このファイルは、Amazonクローン実装の第1ステップである「プロジェクト初期設定」のチェックリストです。
詳細な実装内容については、`amazon_clone_implementation_plan.md`および関連ファイルを参照してください。

## 作業内容

### Railsアプリケーション作成
- [x] 最新版Railsのインストール確認
- [x] アプリケーション作成コマンドの実行
  ```bash
  rails new rails-amazon --api --skip-test --skip-system-test
  cd rails-amazon
  ```

### データベース設定
- [x] config/database.ymlの設定
  ```ruby
  # config/database.yml
  default: &default
    adapter: sqlite3
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
    timeout: 5000

  development:
    <<: *default
    database: db/development.sqlite3

  test:
    <<: *default
    database: db/test.sqlite3

  production:
    <<: *default
    database: db/production.sqlite3
  ```
- [x] データベースの作成
  ```bash
  rails db:create
  ```

### ディレクトリ構造の拡張
- [x] 追加ディレクトリの作成
  ```bash
  mkdir -p app/services
  mkdir -p app/serializers
  mkdir -p app/utils
  mkdir -p app/validators
  mkdir -p app/queries
  ```

### 基本設定ファイルの作成
- [x] アプリケーション設定の調整（config/application.rb）
- [x] APIモード設定の確認
- [x] タイムゾーン設定（日本時間）
- [x] ロケール設定（日本語対応）

### 初期gemのインストール
- [x] Gemfileの編集
- [x] 必要なgemのインストール
  ```bash
  bundle install
  ```

## 完了条件
- [x] Railsアプリケーションが正常に作成されている
- [x] データベースが正常に作成されている
- [x] 追加ディレクトリが正常に作成されている
- [x] 基本設定が完了している
- [x] 必要なgemがインストールされている

作業が完了したら、このファイルを削除し、次のステップ（02_user_models.md）に進んでください。
