# Cloud Run API 用サービスアカウント
resource "google_service_account" "api" {
  account_id   = "${local.service_name_api}-sa"
  display_name = "Bookmark API Service Account"
  description  = "Service account for Bookmark API Cloud Run service"
  project      = var.project_id
}

# Cloud Run Worker 用サービスアカウント
resource "google_service_account" "worker" {
  account_id   = "${local.service_name_worker}-sa"
  display_name = "Bookmark Worker Service Account"
  description  = "Service account for Bookmark Worker Cloud Run service"
  project      = var.project_id
}

# API サービスアカウントに Firestore アクセス権限を付与
resource "google_project_iam_member" "api_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.api.email}"
}

# API サービスアカウントに Cloud Tasks 作成権限を付与
resource "google_project_iam_member" "api_cloudtasks" {
  project = var.project_id
  role    = "roles/cloudtasks.enqueuer"
  member  = "serviceAccount:${google_service_account.api.email}"
}

# Worker サービスアカウントに Firestore アクセス権限を付与
resource "google_project_iam_member" "worker_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.worker.email}"
}

# Worker サービスアカウントに Secret Manager アクセス権限を付与
resource "google_project_iam_member" "worker_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.worker.email}"
}

# API サービスアカウントに Secret Manager アクセス権限を付与
resource "google_project_iam_member" "api_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.api.email}"
}

# Cloud Tasks が Worker を呼び出すための権限
resource "google_cloud_run_service_iam_member" "worker_invoker" {
  count = var.worker_image != "" ? 1 : 0

  project  = var.project_id
  location = var.region
  service  = google_cloud_run_v2_service.worker[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.api.email}"
}
