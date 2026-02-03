# MVP実装TODO（Android共有ブックマークアプリ）

## 0. 事前準備

- [ ] リポジトリ構成の決定（Flutter / Cloud Run API / Worker を同居させるか分離するか）
- [ ] GCPプロジェクト準備（Cloud Run / Firestore / Cloud Tasks / サービスアカウント）
- [ ] 環境変数・シークレット方針の決定（Geminiキー、Firestore接続等）

## 1. データモデル設計（Firestore）

- [ ] URL正規化ルールの仮決定（UTM、末尾スラッシュ、クエリなど）
- [ ] urlId 生成方法の確定（正規化URLのsha256）
- [ ] `urls` コレクション設計（タイトル/OGP/要約ステータス）
- [ ] `users/{uid}/bookmarks` 設計（タイトル上書き、作成・更新日時）
- [ ] 要約ステータスの enum 整理（queued/running/done/failed/skipped_non_html）

## 2. Cloud Run API（同期処理）

### 2.1 /preview

- [ ] URLからメタデータ取得（タイトル/OGP画像）
- [ ] 取得エラー時の扱い定義（空値返却 or エラー）
- [ ] レスポンス形式の確定

### 2.2 /bookmarks/upsert

- [ ] URL共通情報の upsert（urls/{urlId}）
- [ ] ユーザー固有情報の upsert（users/{uid}/bookmarks/{urlId}）
- [ ] HTML判定（Content-Type）→ Cloud Tasks投入 or skip
- [ ] レスポンス形式の確定（urlId / updatedAt / summaryStatus）

### 2.3 /bookmarks/{urlId}/summarize

- [ ] 失敗/未実行のURLに対する再投入API

## 3. Cloud Tasks & Worker（非同期要約）

- [ ] Cloud Tasks キュー設計（リトライポリシー等）
- [ ] Worker のHTTPエンドポイント実装（Tasks から起動）
- [ ] HTML取得 → 本文抽出処理（最低限のクリーニング）
- [ ] LangChain 経由で Gemini 要約（日本語Markdown）
- [ ] Firestore 更新（summaryStatus/summaryMdJa/summaryUpdatedAt）
- [ ] 非HTMLのスキップ処理（skipped_non_html）

## 4. Flutter（Android）

### 4.1 共有受信

- [ ] Android intent-filter 設定
- [ ] 共有テキストから最初のURL抽出（正規表現）

### 4.2 確認画面

- [ ] URL固定表示
- [ ] タイトル編集フィールド（初期値は /preview）
- [ ] 保存ボタン
- [ ] OGP画像プレビュー表示（必要なら）

### 4.3 保存フロー

- [ ] 保存押下 → /bookmarks/upsert 呼び出し
- [ ] 成功時：軽い通知 → 元アプリへ戻る
- [ ] 失敗時：エラー表示 → 手動リトライ

## 5. 認証（将来の拡張を見据えた準備）

- [ ] MVPは単一ユーザー前提だが、API設計は `users/{uid}` を前提に作成
- [ ] 将来のGoogle認証導入ポイントの整理（トークン検証の位置）

## 6. 未決定事項の保留リスト（必要になったら決める）

- [ ] /preview失敗時の保存方針（メタ無し保存可否）
- [ ] 要約更新ポリシー（再要約タイミング）
- [ ] 要約Markdownのフォーマット指針
