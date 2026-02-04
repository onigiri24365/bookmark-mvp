# Cloud Run API サービス
resource "google_cloud_run_v2_service" "api" {
  count = var.api_image != "" ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = local.service_name_api
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.api.email

    scaling {
      min_instance_count = var.cloud_run_min_instances
      max_instance_count = var.cloud_run_max_instances
    }

    containers {
      image = var.api_image

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }

      env {
        name  = "REGION"
        value = var.region
      }

      env {
        name  = "CLOUD_TASKS_QUEUE"
        value = google_cloud_tasks_queue.summary.name
      }

      env {
        name  = "WORKER_URL"
        value = var.worker_image != "" ? google_cloud_run_v2_service.worker[0].uri : ""
      }

      startup_probe {
        http_get {
          path = "/health"
        }
        initial_delay_seconds = 5
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/health"
        }
        period_seconds    = 30
        failure_threshold = 3
      }
    }

    labels = local.labels
  }

  depends_on = [
    google_project_service.apis["run.googleapis.com"],
    google_cloud_tasks_queue.summary,
  ]
}

# Cloud Run API サービスを公開（認証なしでアクセス可能）
resource "google_cloud_run_v2_service_iam_member" "api_public" {
  count = var.api_image != "" ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cloud Run Worker サービス
resource "google_cloud_run_v2_service" "worker" {
  count = var.worker_image != "" ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = local.service_name_worker
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = google_service_account.worker.email

    scaling {
      min_instance_count = 0
      max_instance_count = var.cloud_run_max_instances
    }

    containers {
      image = var.worker_image

      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }

      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }

      # Gemini API Key は Secret Manager から取得
      env {
        name = "GEMINI_API_KEY"
        value_source {
          secret_key_ref {
            secret  = "gemini-api-key"
            version = "latest"
          }
        }
      }

      startup_probe {
        http_get {
          path = "/health"
        }
        initial_delay_seconds = 5
        period_seconds        = 10
        failure_threshold     = 3
      }
    }

    labels = local.labels
  }

  depends_on = [
    google_project_service.apis["run.googleapis.com"],
  ]
}
