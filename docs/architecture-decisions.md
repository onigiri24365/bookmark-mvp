# アーキテクチャ/運用の決定事項

このドキュメントは、リポジトリ構成と環境変数・シークレット方針の決定事項をまとめたものです。チーム体制は一人で運用し、GitHub Actions と Terraform を採用します。

## 1. リポジトリ構成

### 決定
Flutter / Cloud Run API / Worker / Terraform を **単一リポジトリ（monorepo）** で運用します。

### 理由
- 一人運用のため、開発・レビュー・デプロイの流れを単一の履歴で把握できる。
- GitHub Actions でパイプラインを一元管理し、CI/CDの管理コストを抑える。
- Terraform でのインフラコードとアプリコードの整合性を取りやすい。

### 推奨ディレクトリ構成（案）
```
apps/
  flutter/
services/
  api/        # Cloud Run API
  worker/     # Cloud Run Worker (Cloud Tasks 起動)
infra/
  terraform/
docs/
```

### 将来の分離方針（必要時）
- チーム拡大やリリース独立性が必要になった場合、`apps/` と `services/` を段階的に分離。
- Terraform は引き続き単独リポジトリまたは専用インフラリポジトリへ移行を検討。

## 2. 環境変数・シークレット方針

### 全体方針
- **秘密情報はすべて GCP Secret Manager で管理**し、Terraform で定義・プロビジョニングする。
- リポジトリには秘密情報を含めず、`.env.example` など **サンプルのみ** を置く。
- GitHub Actions からのデプロイは **Workload Identity で鍵レス認証**を前提とする。

### サービス別の取り扱い

#### Cloud Run API / Worker
- Secret Manager のシークレットを環境変数としてマウント。
- 例: `GEMINI_API_KEY`, `FIRESTORE_PROJECT_ID`, `FIRESTORE_DATABASE_ID`
- Terraform で以下を管理:
  - Secret の作成
  - Cloud Run サービスアカウントへの `secretAccessor` 付与
  - Cloud Run へのシークレット注入設定

#### Flutter（クライアント）
- **秘密情報は保持しない**（APIキーはサーバー側で保護）。
- 公開しても問題ない設定値のみビルド時に注入（例: API ベースURL）。
- `--dart-define` などのビルドフラグで注入し、`.env` の直接参照は避ける。

### ローカル開発
- `.env.local`（gitignore 対象）でローカル用の値を管理。
- `apps/`・`services/` それぞれに `.env.example` を配置し、必要キーを明示。
- Firestore エミュレータを使う場合は、エミュレータ用の接続設定を `.env.local` に記載。

### CI/CD（GitHub Actions）
- GitHub Actions 側の Secrets は **最小限** に留める。
- Workload Identity で GCP へ接続し、Secret Manager から必要値を取得。
- Terraform 実行用のサービスアカウント権限を明確に分離。

### 管理対象のシークレット例
- `GEMINI_API_KEY`
- `FIRESTORE_PROJECT_ID`
- `FIRESTORE_DATABASE_ID`
- `CLOUD_TASKS_QUEUE`（必要に応じて）

