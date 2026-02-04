#!/bin/bash
# gcloud-init.sh - GCP プロジェクト初期化スクリプト
#
# このスクリプトは以下を実行します：
# 1. Terraform バックエンド用 GCS バケットの作成
# 2. 必要な GCP API の有効化
# 3. Workload Identity Federation (WIF) の設定
# 4. GitHub Secrets 用の値出力
#
# 使い方:
#   cp .env.example .env
#   # .env を編集
#   ./gcloud-init.sh

set -e

# 色付き出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ出力関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# .env ファイルの読み込み
ENV_FILE="${SCRIPT_DIR}/.env"
if [[ -f "$ENV_FILE" ]]; then
    log_info ".env ファイルを読み込んでいます..."
    # shellcheck disable=SC1090
    source "$ENV_FILE"
else
    log_error ".env ファイルが見つかりません"
    log_info "以下のコマンドで .env ファイルを作成してください："
    echo "  cp ${SCRIPT_DIR}/.env.example ${SCRIPT_DIR}/.env"
    exit 1
fi

# 環境変数の設定（デフォルト値付き）
if [[ -z "$PROJECT_ID" ]]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [[ -z "$PROJECT_ID" ]]; then
        log_error "PROJECT_ID が設定されていません。gcloud config set project <PROJECT_ID> を実行してください。"
        exit 1
    fi
fi

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)' 2>/dev/null)
if [[ -z "$PROJECT_NUMBER" ]]; then
    log_error "プロジェクト番号を取得できませんでした。プロジェクトID: $PROJECT_ID が正しいか確認してください。"
    exit 1
fi

REGION="${REGION:-asia-northeast1}"
BUCKET_NAME="${BUCKET_NAME:-${PROJECT_ID}-tfstate}"
GH_USER="${GH_USER:-}"
GH_REPO="${GH_REPO:-}"

# 必須変数のチェック
if [[ -z "$GH_USER" ]] || [[ -z "$GH_REPO" ]]; then
    log_error "GH_USER と GH_REPO は必須です。.env ファイルを編集してください。"
    exit 1
fi

# 設定内容の表示
echo ""
echo "================================================================"
echo "  GCP プロジェクト初期化スクリプト"
echo "================================================================"
echo ""
log_info "以下の設定で初期化を実行します："
echo "  PROJECT_ID:     $PROJECT_ID"
echo "  PROJECT_NUMBER: $PROJECT_NUMBER"
echo "  REGION:         $REGION"
echo "  BUCKET_NAME:    $BUCKET_NAME"
echo "  GH_USER:        $GH_USER"
echo "  GH_REPO:        $GH_REPO"
echo ""

# 確認プロンプト
read -p "この設定で続行しますか？ (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "キャンセルしました"
    exit 0
fi

echo ""

# ステップ 1: GCS バケットの作成
echo "================================================================"
log_info "ステップ 1/4: Terraform バックエンド用 GCS バケットの作成"
echo "================================================================"

if gcloud storage buckets describe "gs://${BUCKET_NAME}" &>/dev/null; then
    log_warn "バケット gs://${BUCKET_NAME} は既に存在します。スキップします。"
else
    log_info "バケット gs://${BUCKET_NAME} を作成しています..."
    gcloud storage buckets create "gs://${BUCKET_NAME}" \
        --project="${PROJECT_ID}" \
        --location="${REGION}"

    log_info "バージョニングを有効化しています..."
    gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning

    log_success "バケットの作成が完了しました"
fi

echo ""

# ステップ 2: API の有効化
echo "================================================================"
log_info "ステップ 2/4: 必要な GCP API の有効化"
echo "================================================================"

APIS=(
    "iam.googleapis.com"
    "iamcredentials.googleapis.com"
    "cloudresourcemanager.googleapis.com"
    "artifactregistry.googleapis.com"
    "run.googleapis.com"
)

log_info "以下の API を有効化しています："
for api in "${APIS[@]}"; do
    echo "  - $api"
done

gcloud services enable "${APIS[@]}" --project="${PROJECT_ID}"

log_success "API の有効化が完了しました"

echo ""

# ステップ 3: Workload Identity Federation の設定
echo "================================================================"
log_info "ステップ 3/4: Workload Identity Federation (WIF) の設定"
echo "================================================================"

# WIF プールの作成
WIF_POOL_NAME="github-pool"
if gcloud iam workload-identity-pools describe "$WIF_POOL_NAME" \
    --project="${PROJECT_ID}" \
    --location="global" &>/dev/null; then
    log_warn "WIF プール '$WIF_POOL_NAME' は既に存在します。スキップします。"
else
    log_info "WIF プールを作成しています..."
    gcloud iam workload-identity-pools create "$WIF_POOL_NAME" \
        --project="${PROJECT_ID}" \
        --location="global" \
        --display-name="GitHub Actions Pool"
    log_success "WIF プールの作成が完了しました"
fi

# OIDC プロバイダの作成
WIF_PROVIDER_NAME="github-provider"
if gcloud iam workload-identity-pools providers describe "$WIF_PROVIDER_NAME" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --workload-identity-pool="$WIF_POOL_NAME" &>/dev/null; then
    log_warn "OIDC プロバイダ '$WIF_PROVIDER_NAME' は既に存在します。スキップします。"
else
    log_info "OIDC プロバイダを作成しています..."
    gcloud iam workload-identity-pools providers create-oidc "$WIF_PROVIDER_NAME" \
        --project="${PROJECT_ID}" \
        --location="global" \
        --workload-identity-pool="$WIF_POOL_NAME" \
        --display-name="GitHub Actions Provider" \
        --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.owner=assertion.repository_owner" \
        --attribute-condition="assertion.repository_owner == '${GH_USER}'" \
        --issuer-uri="https://token.actions.githubusercontent.com"
    log_success "OIDC プロバイダの作成が完了しました"
fi

# サービスアカウントの作成
SA_NAME="github-actions-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
    log_warn "サービスアカウント '$SA_EMAIL' は既に存在します。スキップします。"
else
    log_info "サービスアカウントを作成しています..."
    gcloud iam service-accounts create "$SA_NAME" \
        --display-name="GitHub Actions Service Account"
    log_success "サービスアカウントの作成が完了しました"
fi

# サービスアカウントに WIF からのアクセスを許可
log_info "サービスアカウントに WIF からのアクセス権限を付与しています..."
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
    --project="${PROJECT_ID}" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL_NAME}/attribute.repository/${GH_USER}/${GH_REPO}" \
    --condition=None 2>/dev/null || true

# サービスアカウントにプロジェクト編集権限を付与
log_info "サービスアカウントにプロジェクト編集権限を付与しています..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/editor" \
    --condition=None 2>/dev/null || true

# サービスアカウントに Cloud Run 管理権限を付与
log_info "サービスアカウントに Cloud Run 管理権限を付与しています..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/run.admin" \
    --condition=None 2>/dev/null || true

log_success "WIF の設定が完了しました"

echo ""

# ステップ 4: GitHub Secrets 用の値出力
echo "================================================================"
log_info "ステップ 4/4: GitHub Secrets 用の値出力"
echo "================================================================"
echo ""
echo "以下の値を GitHub リポジトリの Settings > Secrets and variables > Actions に登録してください："
echo ""
echo "----------------------------------------------------------------"
echo "GCP_PROJECT_ID: ${PROJECT_ID}"
echo "GCP_WORKLOAD_IDENTITY_PROVIDER: projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL_NAME}/providers/${WIF_PROVIDER_NAME}"
echo "GCP_SERVICE_ACCOUNT: ${SA_EMAIL}"
echo "GCS_BUCKET_NAME: ${BUCKET_NAME}"
echo "----------------------------------------------------------------"
echo ""

# 完了メッセージ
echo "================================================================"
log_success "GCP プロジェクトの初期化が完了しました！"
echo "================================================================"
echo ""
log_info "次のステップ："
echo "  1. 上記の値を GitHub Secrets に登録"
echo "  2. コードをプッシュして GitHub Actions をトリガー"
echo "  3. Pull Request を作成して terraform plan を確認"
echo ""
