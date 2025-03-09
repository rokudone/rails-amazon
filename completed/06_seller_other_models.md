# 06. セラー・その他モデル実装

このファイルは、Amazonクローン実装の第6ステップである「セラー・その他モデル実装」のチェックリストです。
詳細な実装内容については、`amazon_clone_implementation_plan.md`および関連ファイルを参照してください。

## 作業内容

### セラー関連マイグレーション作成
- [ ] Seller（販売者情報）
- [ ] SellerRating（販売者評価）
- [ ] SellerProduct（販売者商品関連）
- [ ] SellerDocument（販売者ドキュメント）
- [ ] SellerTransaction（販売者取引）
- [ ] SellerPolicy（販売者ポリシー）
- [ ] SellerPerformance（販売者パフォーマンス）

### その他マイグレーション作成
- [ ] Notification（通知）
- [ ] SearchHistory（検索履歴）
- [ ] RecentlyViewed（最近閲覧した商品）
- [ ] Wishlist（ウィッシュリスト）
- [ ] Cart（カート）
- [ ] CartItem（カートアイテム）
- [ ] Tag（タグ）
- [ ] Tagging（タグ付け）
- [ ] Event（イベント）
- [ ] EventLog（イベントログ）
- [ ] SystemConfig（システム設定）
- [ ] Currency（通貨）
- [ ] Country（国）
- [ ] Region（地域）

### セラー関連モデル定義
- [ ] Seller
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] カスタムメソッド
  - [ ] 認証ワークフロー
- [ ] SellerRating
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] 集計メソッド
- [ ] SellerProduct
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] SellerDocument
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] 認証ワークフロー
- [ ] SellerTransaction
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] 集計メソッド
- [ ] SellerPolicy
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] SellerPerformance
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] 計算メソッド

### その他モデル定義
- [ ] Notification
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] 既読管理
- [ ] SearchHistory
  - [ ] 関連付け
  - [ ] スコープ
  - [ ] 分析メソッド
- [ ] RecentlyViewed
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] Wishlist
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] Cart
  - [ ] 関連付け
  - [ ] スコープ
  - [ ] カスタムメソッド
  - [ ] 合計計算
- [ ] CartItem
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] 小計計算
- [ ] Tag
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] Tagging
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] Event
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] 有効期限管理
- [ ] EventLog
  - [ ] 関連付け
  - [ ] スコープ
- [ ] SystemConfig
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] 設定管理メソッド
- [ ] Currency
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] 為替計算
- [ ] Country
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] Region
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ

### ファクトリ（テスト用）
- [ ] セラー関連ファクトリ
  - [ ] Seller
  - [ ] SellerRating
  - [ ] SellerProduct
  - [ ] SellerDocument
  - [ ] SellerTransaction
  - [ ] SellerPolicy
  - [ ] SellerPerformance
- [ ] その他ファクトリ
  - [ ] Notification
  - [ ] SearchHistory
  - [ ] RecentlyViewed
  - [ ] Wishlist
  - [ ] Cart
  - [ ] CartItem
  - [ ] Tag
  - [ ] Tagging
  - [ ] Event
  - [ ] EventLog
  - [ ] SystemConfig
  - [ ] Currency
  - [ ] Country
  - [ ] Region

### シードデータ
- [ ] 開発用シードデータの作成
  - [ ] サンプルセラー
  - [ ] 国と地域
  - [ ] 通貨
  - [ ] システム設定
  - [ ] タグ

## 完了条件
- [ ] すべてのマイグレーションが作成され、実行されている
- [ ] すべてのモデルが定義され、関連付けが設定されている
- [ ] バリデーションが適切に設定されている
- [ ] スコープとカスタムメソッドが実装されている
- [ ] ファクトリが作成されている
- [ ] シードデータが作成され、正常に読み込まれる

作業が完了したら、このファイルを削除し、次のステップ（07_controllers.md）に進んでください。
