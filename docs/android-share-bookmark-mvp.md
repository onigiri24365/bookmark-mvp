# Android共有ブックマークアプリ（Flutter）要件・設計ドキュメント（MVP版）

## 1. 目的

Androidの標準共有（Sharesheet）からURLを受け取り、確認画面を経てバックエンドに保存する「ブックマーク保存アプリ」をFlutterで実装する。保存後は元のアプリに戻れる体験を重視し、重い処理（本文抽出・要約）は非同期で行う。

## 2. 前提・スコープ

### 対象プラットフォーム

- Android
- Flutter開発は初めて（＝MVPはシンプルに）

### 入力（共有で受けるもの）

- http/https のURLのみ
- 共有テキスト内にURLが複数ある場合：最初の1つのみ採用
- HTML以外（PDF/画像など）のURLも受け取れるが、要約はスキップ

### 保存後の体験

- 確認画面を出す
- 保存完了後は元のアプリへ戻る（＝アプリ側は完了通知後に終了/戻る）

### オフライン・失敗時

- オフライン時：保存できなくてOK
- 失敗時リトライ：手動

### 配布

- ひとまず公開は考えない（ローカル運用想定）

## 3. 要件（決定事項）

### 3.1 UI/UX要件

- 共有で受け取ったURLを表示する確認画面を必ず挟む
- 確認画面の編集可否
  - URL：編集不可
  - タイトル：編集可（初期値は自動取得）
- 保存後
  - 成功→「保存しました」等の軽い通知→元アプリへ戻る
  - 失敗→エラー表示→「再試行」できる（手動リトライ）

### 3.2 メタデータ自動取得

- タイトル：自動取得（確認画面に初期表示）
- OGP画像URL：自動取得（参照URLを保存するだけ）
- 取得はクライアントではなくサーバ側で実施（安定・再利用しやすい）

### 3.3 重複時の扱い

- 同一ユーザーが同一URLを保存した場合：既存を更新（新規追加しない）

### 3.4 要約（非同期）

- HTMLの本文から全文テキスト抽出 → LLMで日本語要約（Markdown）を生成して保存
- LLMはLangChainを介して、将来モデルを差し替え可能にする
- 初期LLMはGeminiを検討
- HTML以外（PDF/画像など）は要約スキップ

## 4. 全体アーキテクチャ（GCP）

### 構成

- Flutter（Android）：共有受信・確認画面・保存呼び出し
- Cloud Run（API）：メタ取得 / upsert / 手動リトライ受付
- Firestore：永続化（URLとブックマークを分離）
- Cloud Tasks：要約ジョブのキューイング
- Cloud Run（Worker）：HTML取得→全文抽出→LangChain→Gemini要約→Firestore更新

### 処理フロー（シーケンス）

1. 共有 → Flutter起動
2. Flutterが共有テキストから https?://... を抽出（最初の1つ）
3. Flutter確認画面表示 → POST /preview で title/OGP取得 → 表示（タイトルは編集可能）
4. 保存押下 → POST /bookmarks/upsert
5. APIがFirestoreに保存（upsert）し、Cloud Tasksに要約タスク投入
6. 保存成功 → Flutterは完了表示 → 元アプリへ戻る
7. Workerが非同期でHTML取得→全文テキスト抽出→Geminiで日本語Markdown要約→FirestoreのURL側を更新

> ここまで決まっていると、MVPはかなりブレずに作れます。体験の中核（共有→確認→保存→戻る）と、重い処理を非同期に分ける方針が綺麗です。

## 5. データモデル（Firestore）

将来の複数ユーザーに備え、URL（共通）とブックマーク（ユーザー固有）を分離する。

### 5.1 urls（URL共通資産）

- コレクション：urls
- ドキュメントID：urlId
- 推奨：正規化したURLをハッシュ化（sha256など）

例フィールド:

- url: string（正規化済み）
- canonicalTitle: string | null（自動取得）
- ogpImageUrl: string | null（自動取得）
- createdAt: timestamp
- updatedAt: timestamp

要約（日本語）:

- summaryStatusJa: "queued" | "running" | "done" | "failed" | "skipped_non_html"
- summaryMdJa: string | null（日本語Markdown要約）
- summaryErrorJa: string | null
- summaryModel: string（例：geminiのモデル名）
- summaryUpdatedAt: timestamp | null

### 5.2 users/{uid}/bookmarks（ユーザー固有の保存状態）

- コレクション：users/{uid}/bookmarks
- ドキュメントID：urlId（URLと同じキー）

例フィールド:

- urlId: string
- titleOverride: string | null（確認画面で編集したタイトル）
- createdAt: timestamp
- updatedAt: timestamp

> 将来のタグ付けはここに拡張（例：tags: string[]）するか、規模が大きくなるなら tags / bookmark_tags のように分離。

## 6. バックエンドAPI（Cloud Run）

### 6.1 POST /preview（確認画面用）

目的：URLからタイトル/OGP画像URLを取得して返す（クライアントは表示に専念）

Request:

- url: string

Response（例）:

- canonicalTitle: string | null
- ogpImageUrl: string | null

### 6.2 POST /bookmarks/upsert（保存用）

目的:

- URL共通情報を urls/{urlId} に作成/更新
- ユーザー固有情報を users/{uid}/bookmarks/{urlId} にupsert
- 要約ジョブをキューに積む（HTML以外はスキップ）

Request:

- url: string
- titleOverride?: string

Response（例）:

- urlId: string
- bookmarkUpdatedAt: timestamp
- summaryStatusJa: string

### 6.3 POST /bookmarks/{urlId}/summarize（手動リトライ）

目的：要約が失敗した/未実行のURLに対して、再度ジョブ投入。

## 7. 非同期要約（Worker）

### 7.1 対象

- Content-Type が HTML の場合のみ実行
- それ以外（PDF/画像など）は skipped_non_html として終了

### 7.2 手順

1. urls/{urlId} を取得
2. URLへアクセスしてHTML取得
3. HTMLから全文テキスト抽出
   - 最低限：script/style除外、タグ除去、連続空白の正規化など
4. LangChain経由でGeminiに要約を依頼（日本語Markdown）
5. urls/{urlId} を更新
   - summaryStatusJa=done
   - summaryMdJa 保存
   - summaryUpdatedAt 更新
   - 失敗時は failed とエラー保存

### 7.3 LangChainの差し替え設計

- provider / model / temperature / maxTokens 等は環境変数化
- まずはGeminiを実装し、将来OpenAI等への差し替えも可能な構成にする

## 8. Flutter側の実装方針（MVP）

### 8.1 共有受信

- Android共有を受け取るための設定（intent-filter）＋Flutter側で受け取り
- 共有テキストから最初のURLを抽出（正規表現）

### 8.2 画面

確認画面:

- URL（固定表示）
- タイトル（編集可能、初期値は /preview 結果）
- OGP画像URL（必要ならプレビュー表示）
- 保存ボタン

保存後: 完了通知 → 元アプリへ戻る

### 8.3 エラー

- /preview失敗：最低限URLだけで保存できる設計にするか（要検討）
- /upsert失敗：エラー表示＋手動リトライ

## 9. 認証（将来の複数ユーザー対応）

将来的にGoogle認証を導入し、Cloud Run側でトークン検証して uid を確定。MVPでは単一ユーザーでも、データモデルは users/{uid} 前提で作っておくと移行が楽。

## 10. MVPの範囲 / 将来拡張

### MVPに含める

- 共有→URL抽出→確認画面→保存→元アプリに戻る
- タイトル/OGPの自動取得
- Firestore保存（URL/ブックマーク分離、重複更新）
- HTMLのみ非同期要約（日本語Markdown、手動リトライ）

### 今回はやらない（明確にスコープ外）

- 一覧画面・検索（将来）
- タグ付け（将来）
- オフラインキューイング
- HTML以外（PDF/画像）の要約

## 11. 未決定（必要になったら決める）

- URL正規化ルール（例：UTMの扱い、末尾スラッシュ、クエリの扱い）
- /previewが落ちたときに保存をどうするか（メタ無しでも保存するか）
- 要約の更新ポリシー（何日ごとに再要約するか、上書きするか）
- 要約Markdownのフォーマット（見出し構造、箇条書き粒度、最大長）

---

必要なら、このドキュメントをベースに次を一気に作れます：

- APIの具体的なI/F（JSON例）
- Firestoreのセキュリティ設計（Cloud Runのみ書き込み/将来のRLS的考え方）
- Cloud Tasks/Workerの実装チェックリスト
- Flutterの画面WBS（最短の実装順）

どれから固めるのが進めやすいですか？（私は「urlId生成＋upsertトランザクション→/preview→Flutter確認画面」の順が一番詰まりにくいと思います）
