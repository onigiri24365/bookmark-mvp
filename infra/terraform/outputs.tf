output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

output "api_service_account_email" {
  description = "Email of the API service account"
  value       = google_service_account.api.email
}

output "worker_service_account_email" {
  description = "Email of the Worker service account"
  value       = google_service_account.worker.email
}

output "firestore_database_name" {
  description = "Firestore database name"
  value       = google_firestore_database.main.name
}

output "cloud_tasks_queue_name" {
  description = "Cloud Tasks queue name"
  value       = google_cloud_tasks_queue.summary.name
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.services.repository_id}"
}

output "api_url" {
  description = "Cloud Run API service URL"
  value       = var.api_image != "" ? google_cloud_run_v2_service.api[0].uri : "Not deployed yet"
}

output "worker_url" {
  description = "Cloud Run Worker service URL"
  value       = var.worker_image != "" ? google_cloud_run_v2_service.worker[0].uri : "Not deployed yet"
}
