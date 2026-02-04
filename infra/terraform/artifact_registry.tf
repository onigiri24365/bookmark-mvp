# Artifact Registry リポジトリ（コンテナイメージ用）
resource "google_artifact_registry_repository" "services" {
  project       = var.project_id
  location      = var.region
  repository_id = "bookmark-services"
  description   = "Docker repository for bookmark services"
  format        = "DOCKER"

  labels = local.labels

  depends_on = [google_project_service.apis["artifactregistry.googleapis.com"]]
}
