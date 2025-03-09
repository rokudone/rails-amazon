# 03. 商品関連モデル実装

このファイルは、Amazonクローン実装の第3ステップである「商品関連モデル実装」のチェックリストです。
詳細な実装内容については、`amazon_clone_implementation_plan.md`および関連ファイルを参照してください。

## 作業内容

### マイグレーション作成
- [ ] Product（基本情報）
- [ ] Category（カテゴリ階層）
- [ ] SubCategory（サブカテゴリ）
- [ ] Brand（ブランド情報）
- [ ] ProductVariant（サイズ、色などのバリエーション）
- [ ] ProductAttribute（商品属性）
- [ ] ProductImage（商品画像）
- [ ] ProductVideo（商品動画）
- [ ] ProductDocument（商品ドキュメント）
- [ ] ProductDescription（詳細説明）
- [ ] ProductSpecification（仕様情報）
- [ ] PriceHistory（価格履歴）
- [ ] ProductBundle（商品バンドル）
- [ ] ProductAccessory（アクセサリー関連）
- [ ] ProductTag（商品タグ）

### モデル定義
- [ ] Product
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] コールバック
  - [ ] スコープ
  - [ ] カスタムメソッド
- [ ] Category
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] 階層構造の実装
- [ ] SubCategory
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] Brand
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] ProductVariant
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] カスタムメソッド
- [ ] ProductAttribute
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] ProductImage
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] ProductVideo
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] ProductDocument
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] ProductDescription
  - [ ] 関連付け
  - [ ] バリデーション
- [ ] ProductSpecification
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] PriceHistory
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] ProductBundle
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
  - [ ] カスタムメソッド
- [ ] ProductAccessory
  - [ ] 関連付け
  - [ ] バリデーション
- [ ] ProductTag
  - [ ] 関連付け
  - [ ] バリデーション

### ファクトリ（テスト用）
- [ ] Product
- [ ] Category
- [ ] SubCategory
- [ ] Brand
- [ ] ProductVariant
- [ ] ProductAttribute
- [ ] ProductImage
- [ ] ProductVideo
- [ ] ProductDocument
- [ ] ProductDescription
- [ ] ProductSpecification
- [ ] PriceHistory
- [ ] ProductBundle
- [ ] ProductAccessory
- [ ] ProductTag

### シードデータ
- [ ] 開発用シードデータの作成
  - [ ] カテゴリ階層
  - [ ] ブランド
  - [ ] サンプル商品

## 完了条件
- [ ] すべてのマイグレーションが作成され、実行されている
- [ ] すべてのモデルが定義され、関連付けが設定されている
- [ ] バリデーションが適切に設定されている
- [ ] スコープとカスタムメソッドが実装されている
- [ ] ファクトリが作成されている
- [ ] シードデータが作成され、正常に読み込まれる

作業が完了したら、このファイルを削除し、次のステップ（04_inventory_order_models.md）に進んでください。
