# Cloud Tasks キュー（要約処理用）
resource "google_cloud_tasks_queue" "summary" {
  project  = var.project_id
  location = var.region
  name     = var.cloud_tasks_queue_name

  rate_limits {
    max_dispatches_per_second = var.cloud_tasks_max_dispatches_per_second
    max_concurrent_dispatches = var.cloud_tasks_max_concurrent_dispatches
  }

  retry_config {
    max_attempts       = 5
    min_backoff        = "10s"
    max_backoff        = "300s"
    max_doublings      = 4
    max_retry_duration = "3600s"
  }

  depends_on = [google_project_service.apis["cloudtasks.googleapis.com"]]
}
