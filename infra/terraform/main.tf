provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# プロジェクトデータの取得
data "google_project" "project" {
  project_id = var.project_id
}

# ローカル変数
locals {
  service_name_api    = "bookmark-api"
  service_name_worker = "bookmark-worker"
  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}
