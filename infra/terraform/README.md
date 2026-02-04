# Terraform Infrastructure

Bookmark MVP の GCP インフラストラクチャを管理する Terraform コードです。

## 構成リソース

| リソース | 説明 |
|----------|------|
| Cloud Run (API) | ブックマーク API サービス |
| Cloud Run (Worker) | 要約処理ワーカーサービス |
| Firestore | データストア（Native モード） |
| Cloud Tasks | 非同期ジョブキュー |
| Artifact Registry | コンテナイメージリポジトリ |
| Service Account | 各サービス用のサービスアカウント |

## 前提条件

1. `infra/scripts/gcloud-init.sh` を実行済みであること
2. GitHub Secrets に以下の値が設定済みであること：
   - `GCP_PROJECT_ID`
   - `GCP_WORKLOAD_IDENTITY_PROVIDER`
   - `GCP_SERVICE_ACCOUNT`
   - `GCS_BUCKET_NAME`

## ローカルでの実行

```bash
# 1. terraform.tfvars を作成
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集

# 2. 初期化
terraform init -backend-config="bucket=YOUR_BUCKET_NAME"

# 3. プラン確認
terraform plan -var-file=terraform.tfvars

# 4. 適用
terraform apply -var-file=terraform.tfvars
```

## GitHub Actions での実行

- `infra/terraform/` 配下のファイルを変更して PR を作成すると、自動で `terraform plan` が実行されます
- `main` ブランチにマージすると、自動で `terraform apply` が実行されます

## ファイル構成

```
infra/terraform/
├── main.tf                    # プロバイダー設定
├── versions.tf                # Terraform バージョン指定
├── variables.tf               # 変数定義
├── outputs.tf                 # 出力定義
├── apis.tf                    # GCP API 有効化
├── iam.tf                     # サービスアカウント・IAM
├── firestore.tf               # Firestore 設定
├── cloudtasks.tf              # Cloud Tasks 設定
├── cloudrun.tf                # Cloud Run 設定
├── artifact_registry.tf       # Artifact Registry 設定
├── terraform.tfvars.example   # 変数サンプル
└── README.md                  # このファイル
```

## Cloud Run のデプロイ

Cloud Run サービスは、`api_image` / `worker_image` 変数が空の場合はデプロイされません。
アプリケーションコードを作成後、イメージをビルドして変数を設定してください。

```hcl
api_image    = "asia-northeast1-docker.pkg.dev/PROJECT_ID/bookmark-services/api:v1"
worker_image = "asia-northeast1-docker.pkg.dev/PROJECT_ID/bookmark-services/worker:v1"
```

## Secret Manager

Worker サービスは `gemini-api-key` という名前の Secret を参照します。
Secret は手動で作成するか、Terraform で管理してください：

```bash
# 手動で作成する場合
echo -n "YOUR_GEMINI_API_KEY" | gcloud secrets create gemini-api-key --data-file=-
```
