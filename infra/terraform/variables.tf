variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast1"
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  default     = "dev"
}

# Cloud Run 設定
variable "api_image" {
  description = "Container image for API service"
  type        = string
  default     = ""
}

variable "worker_image" {
  description = "Container image for Worker service"
  type        = string
  default     = ""
}

variable "cloud_run_min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 0
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 10
}

# Firestore 設定
variable "firestore_location" {
  description = "Firestore database location"
  type        = string
  default     = "asia-northeast1"
}

# Cloud Tasks 設定
variable "cloud_tasks_queue_name" {
  description = "Name of Cloud Tasks queue"
  type        = string
  default     = "summary-queue"
}

variable "cloud_tasks_max_dispatches_per_second" {
  description = "Maximum dispatches per second"
  type        = number
  default     = 10
}

variable "cloud_tasks_max_concurrent_dispatches" {
  description = "Maximum concurrent dispatches"
  type        = number
  default     = 5
}
