# データストア設計（Firestore）

本ドキュメントは、Android共有ブックマークMVPの永続化ストア（Firestore）に関する設計をまとめたもの。

## 1. 設計方針

- **URL（共通資産）とユーザー固有の保存状態を分離**し、将来的なマルチユーザー対応と重複排除を実現する。
- **URL正規化 + ハッシュ化**により、同一URLの再登録を確実に検出する。
- 要約生成は**非同期**で実行し、URLドキュメント側に状態と結果を集約する。

## 2. コレクション構成

```
/urls/{urlId}
/users/{uid}
/users/{uid}/bookmarks/{urlId}
```

### 2.1 urls（URL共通資産）

- **コレクション**: `urls`
- **ドキュメントID**: `urlId`（正規化URLのハッシュ）

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `url` | string | 必須 | 正規化済みURL（canonical） |
| `urlId` | string | 必須 | URLのハッシュID（ドキュメントIDと同一） |
| `canonicalTitle` | string | null | 任意 | 自動取得タイトル |
| `ogpImageUrl` | string | null | 任意 | OGP画像URL |
| `createdAt` | timestamp | 必須 | 作成日時 |
| `updatedAt` | timestamp | 必須 | 更新日時 |
| `summaryStatus` | string | 任意 | `queued` / `running` / `done` / `failed` / `skipped_non_html` |
| `summaryMd` | string | null | 任意 | 要約（Markdown） |
| `summaryError` | string | null | 任意 | 失敗時エラー |
| `summaryModel` | string | null | 任意 | 使用モデル名 |
| `summaryUpdatedAt` | timestamp | null | 任意 | 要約更新日時 |

> `summaryStatus` が `queued`/`running` の場合、Workerが処理中であることを示す。

### 2.2 users（ユーザー情報）

- **コレクション**: `users`
- **ドキュメントID**: `uid`

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `uid` | string | 必須 | ユーザーID（ドキュメントIDと同一） |
| `createdAt` | timestamp | 必須 | ユーザー作成日時 |
| `updatedAt` | timestamp | 必須 | 更新日時 |
| `displayName` | string | null | 任意 | 表示名（将来のプロフィール用） |
| `photoUrl` | string | null | 任意 | 画像URL（将来のプロフィール用） |

### 2.3 users/{uid}/bookmarks（ユーザー固有の保存）

- **コレクション**: `users/{uid}/bookmarks`
- **ドキュメントID**: `urlId`（`urls` と同一）

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `urlId` | string | 必須 | URLsコレクションのID |
| `titleOverride` | string | null | 任意 | ユーザーが編集したタイトル |
| `createdAt` | timestamp | 必須 | 保存日時 |
| `updatedAt` | timestamp | 必須 | 更新日時 |

## 3. urlId生成とURL正規化

### 3.1 正規化ルール（MVP）

- スキームを `http`/`https` のみに限定
- 末尾の`/`は削除（`https://example.com/` → `https://example.com`）
- `utm_*` などトラッキング系のクエリは削除（将来拡張）
- `#fragment` は削除

> 正規化ポリシーは将来変更し得るため、正規化後のURLは `url` フィールドに保持する。

### 3.2 urlIdの算出

- `urlId = sha256(normalizedUrl)`
- FirestoreのドキュメントIDとして使用

## 4. 更新フローとトランザクション

### 4.1 保存（upsert）

1. `urls/{urlId}` を取得
2. なければ新規作成、あれば `updatedAt` 等のみ更新
3. `users/{uid}/bookmarks/{urlId}` を upsert
4. HTMLであれば `summaryStatus=queued` にしてCloud Tasksへ投入

### 4.2 要約更新（Worker）

- `summaryStatus` を `running` → `done`/`failed` に更新
- `summaryUpdatedAt` を常に更新

## 5. インデックス設計（MVP）

- `users/{uid}/bookmarks` の `updatedAt` 降順（一覧表示用：将来）
- `urls` の `summaryStatus` + `updatedAt` 複合（再処理キューの監視用途：将来）

> MVPでは明示的な複合インデックスは最小限にし、必要に応じて追加する。

## 6. 参考クエリ

### 6.1 ユーザーの最新ブックマーク

```
/users/{uid}/bookmarks
  orderBy(updatedAt, desc)
  limit(50)
```

### 6.2 要約待ちURL（将来運用）

```
/urls
  where(summaryStatus in ["queued", "failed"])
  orderBy(updatedAt, desc)
```

## 7. 考慮事項（将来拡張）

- **タグ付け**: `bookmarks` に `tags: string[]` 追加 or 別コレクション化
- **全文検索**: Firestore単体では困難なため、外部検索基盤を検討
- **再要約ポリシー**: `summaryUpdatedAt` と `summaryModel` の管理で再生成条件を制御
