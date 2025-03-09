# 04. 在庫・注文関連モデル実装

このファイルは、Amazonクローン実装の第4ステップである「在庫・注文関連モデル実装」のチェックリストです。
詳細な実装内容については、`amazon_clone_implementation_plan.md`および関連ファイルを参照してください。

## 作業内容

### 在庫関連マイグレーション作成
- [ ] Inventory（在庫情報）
- [ ] Warehouse（倉庫情報）
- [ ] StockMovement（在庫移動履歴）
- [ ] InventoryAlert（在庫アラート設定）
- [ ] InventoryForecast（在庫予測）
- [ ] SupplierOrder（仕入れ注文）

### 注文関連マイグレーション作成
- [ ] Order（注文情報）
- [ ] OrderItem（注文アイテム）
- [ ] Payment（支払い情報）
- [ ] PaymentTransaction（決済トランザクション）
- [ ] Shipment（配送情報）
- [ ] ShipmentTracking（配送追跡）
- [ ] Return（返品情報）
- [ ] Invoice（請求書）
- [ ] OrderLog（注文ログ）
- [ ] OrderStatus（注文ステータス）
- [ ] OrderDiscount（注文割引）
- [ ] GiftWrap（ギフトラッピング）

### 在庫関連モデル定義
- [ ] Inventory
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] カスタムメソッド
- [ ] Warehouse
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] StockMovement
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] カスタムメソッド
- [ ] InventoryAlert
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] InventoryForecast
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] SupplierOrder
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] ステータス管理

### 注文関連モデル定義
- [ ] Order
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] コールバック
  - [ ] スコープ
  - [ ] カスタムメソッド
  - [ ] ステータス管理
- [ ] OrderItem
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] カスタムメソッド
- [ ] Payment
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] ステータス管理
- [ ] PaymentTransaction
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] Shipment
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] ステータス管理
- [ ] ShipmentTracking
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] Return
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] ステータス管理
- [ ] Invoice
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] ステータス管理
- [ ] OrderLog
  - [ ] 関連付け
  - [ ] スコープ
- [ ] OrderStatus
  - [ ] バリデーション
  - [ ] スコープ
- [ ] OrderDiscount
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] GiftWrap
  - [ ] 関連付け
  - [ ] バリデーション

### ファクトリ（テスト用）
- [ ] 在庫関連ファクトリ
  - [ ] Inventory
  - [ ] Warehouse
  - [ ] StockMovement
  - [ ] InventoryAlert
  - [ ] InventoryForecast
  - [ ] SupplierOrder
- [ ] 注文関連ファクトリ
  - [ ] Order
  - [ ] OrderItem
  - [ ] Payment
  - [ ] PaymentTransaction
  - [ ] Shipment
  - [ ] ShipmentTracking
  - [ ] Return
  - [ ] Invoice
  - [ ] OrderLog
  - [ ] OrderStatus
  - [ ] OrderDiscount
  - [ ] GiftWrap

### シードデータ
- [ ] 開発用シードデータの作成
  - [ ] 倉庫データ
  - [ ] 在庫データ
  - [ ] 注文ステータスデータ

## 完了条件
- [ ] すべてのマイグレーションが作成され、実行されている
- [ ] すべてのモデルが定義され、関連付けが設定されている
- [ ] バリデーションが適切に設定されている
- [ ] スコープとカスタムメソッドが実装されている
- [ ] ファクトリが作成されている
- [ ] シードデータが作成され、正常に読み込まれる

作業が完了したら、このファイルを削除し、次のステップ（05_review_marketing_models.md）に進んでください。
