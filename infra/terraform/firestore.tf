# Firestore データベース（Native モード）
resource "google_firestore_database" "main" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"

  # 削除保護（本番環境では有効化推奨）
  delete_protection_state = var.environment == "prod" ? "DELETE_PROTECTION_ENABLED" : "DELETE_PROTECTION_DISABLED"

  depends_on = [google_project_service.apis["firestore.googleapis.com"]]
}

# Firestore インデックス（将来用）
# users/{uid}/bookmarks の updatedAt 降順インデックス
resource "google_firestore_index" "bookmarks_updated_at" {
  project    = var.project_id
  database   = google_firestore_database.main.name
  collection = "users/{uid}/bookmarks"

  fields {
    field_path = "updatedAt"
    order      = "DESCENDING"
  }

  fields {
    field_path = "__name__"
    order      = "DESCENDING"
  }

  depends_on = [google_firestore_database.main]
}
