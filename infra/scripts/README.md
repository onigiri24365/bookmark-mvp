# GCP 初期化スクリプト

GCP プロジェクトを GitHub Actions + Terraform で管理するための初期設定を自動化するスクリプトです。

## 前提条件

- Google Cloud Shell または gcloud CLI がインストールされた環境
- GCP プロジェクトが作成済みで、適切な権限（Owner または Editor）があること
- GitHub リポジトリが作成済みであること

## ファイル構成

```
scripts/
├── .env.example    # 環境変数の例
├── .env            # 環境変数（.gitignore 済み）
├── gcloud-init.sh  # 初期化スクリプト
└── README.md       # このファイル
```

## 使い方

### 1. 環境変数ファイルの作成

```bash
cd scripts
cp .env.example .env
```

### 2. .env ファイルの編集

```bash
# .env を編集
vi .env
```

設定する変数：

| 変数名 | 説明 | 必須 | デフォルト値 |
|--------|------|------|--------------|
| `PROJECT_ID` | GCP プロジェクト ID | いいえ | `gcloud config` から取得 |
| `REGION` | GCP リージョン | いいえ | `asia-northeast1` |
| `BUCKET_NAME` | Terraform state 用バケット名 | いいえ | `${PROJECT_ID}-tfstate` |
| `GH_USER` | GitHub ユーザー名 | **はい** | - |
| `GH_REPO` | GitHub リポジトリ名 | **はい** | - |

### 3. スクリプトの実行

```bash
./gcloud-init.sh
```

## 実行内容

スクリプトは以下のステップを実行します：

### ステップ 1: GCS バケットの作成

Terraform の state ファイルを保存するためのバケットを作成します。

- バケット名: `${PROJECT_ID}-tfstate`（カスタマイズ可能）
- バージョニング: 有効

### ステップ 2: GCP API の有効化

以下の API を有効化します：

- `iam.googleapis.com` - IAM API
- `iamcredentials.googleapis.com` - IAM Credentials API
- `cloudresourcemanager.googleapis.com` - Cloud Resource Manager API
- `artifactregistry.googleapis.com` - Artifact Registry API
- `run.googleapis.com` - Cloud Run API

### ステップ 3: Workload Identity Federation (WIF) の設定

GitHub Actions から GCP に安全に認証するための設定を行います：

1. WIF プール（`github-pool`）の作成
2. OIDC プロバイダ（`github-provider`）の作成
3. サービスアカウント（`github-actions-sa`）の作成
4. 権限の付与

### ステップ 4: GitHub Secrets 用の値出力

GitHub リポジトリに登録する必要がある Secrets の値を出力します：

- `GCP_PROJECT_ID`
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT`
- `GCS_BUCKET_NAME`

## 冪等性

このスクリプトは冪等性を持っています：

- 既存のリソース（バケット、WIF プール、サービスアカウント等）がある場合はスキップ
- 何度実行しても安全

## トラブルシューティング

### エラー: "PROJECT_ID が設定されていません"

```bash
gcloud config set project YOUR_PROJECT_ID
```

を実行してプロジェクトを設定するか、`.env` ファイルに `PROJECT_ID` を明記してください。

### エラー: "GH_USER と GH_REPO は必須です"

`.env` ファイルに GitHub のユーザー名とリポジトリ名を設定してください。

### エラー: 権限関連

スクリプトを実行するユーザーに以下の権限が必要です：

- `roles/storage.admin` - バケットの作成
- `roles/iam.workloadIdentityPoolAdmin` - WIF の設定
- `roles/iam.serviceAccountAdmin` - サービスアカウントの作成
- `roles/resourcemanager.projectIamAdmin` - IAM ポリシーの設定

プロジェクト Owner であれば問題ありません。

## 次のステップ

1. 出力された値を GitHub の **Settings > Secrets and variables > Actions** に登録
2. コードをプッシュして GitHub Actions をトリガー
3. Pull Request を作成して `terraform plan` の結果を確認
4. main ブランチにマージして自動デプロイ

