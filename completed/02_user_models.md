# 02. ユーザー関連モデル実装

このファイルは、Amazonクローン実装の第2ステップである「ユーザー関連モデル実装」のチェックリストです。
詳細な実装内容については、`amazon_clone_implementation_plan.md`および関連ファイルを参照してください。

## 作業内容

### マイグレーション作成
- [ ] User（認証情報、基本情報）
- [ ] Profile（詳細プロフィール情報）
- [ ] Address（住所情報、複数保持可能）
- [ ] PaymentMethod（支払い方法、複数保持可能）
- [ ] UserPreference（設定、通知設定など）
- [ ] UserLog（ユーザーアクション履歴）
- [ ] UserDevice（デバイス情報）
- [ ] UserSession（セッション情報）
- [ ] UserSubscription（サブスクリプション情報）
- [ ] UserReward（報酬情報）
- [ ] UserPermission（権限情報）
- [ ] UserActivity（アクティビティ履歴）

### モデル定義
- [ ] User
  - [ ] has_secure_password
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] コールバック
  - [ ] スコープ
  - [ ] カスタムメソッド
- [ ] Profile
  - [ ] 関連付け
  - [ ] バリデーション
- [ ] Address
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] PaymentMethod
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] UserPreference
  - [ ] 関連付け
  - [ ] バリデーション
- [ ] UserLog
  - [ ] 関連付け
  - [ ] スコープ
- [ ] UserDevice
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] UserSession
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] UserSubscription
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] UserReward
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] UserPermission
  - [ ] 関連付け
  - [ ] バリデーション
  - [ ] スコープ
- [ ] UserActivity
  - [ ] 関連付け
  - [ ] スコープ

### ファクトリ（テスト用）
- [ ] User
- [ ] Profile
- [ ] Address
- [ ] PaymentMethod
- [ ] UserPreference
- [ ] UserLog
- [ ] UserDevice
- [ ] UserSession
- [ ] UserSubscription
- [ ] UserReward
- [ ] UserPermission
- [ ] UserActivity

### シードデータ
- [ ] 開発用シードデータの作成

## 完了条件
- [ ] すべてのマイグレーションが作成され、実行されている
- [ ] すべてのモデルが定義され、関連付けが設定されている
- [ ] バリデーションが適切に設定されている
- [ ] スコープとカスタムメソッドが実装されている
- [ ] ファクトリが作成されている
- [ ] シードデータが作成され、正常に読み込まれる

作業が完了したら、このファイルを削除し、次のステップ（03_product_models.md）に進んでください。
