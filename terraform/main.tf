provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# --------------------------------------------------
# Enable Required APIs
# --------------------------------------------------

resource "google_project_service" "storage_api" {
  service = "storage.googleapis.com"
}

resource "google_project_service" "pubsub_api" {
  service = "pubsub.googleapis.com"
}

resource "google_project_service" "secretmanager_api" {
  service = "secretmanager.googleapis.com"
}

resource "google_project_service" "cloudfunctions_api" {
  service = "cloudfunctions.googleapis.com"
}

resource "google_project_service" "cloudbuild_api" {
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "run_api" {
  service = "run.googleapis.com"
}

resource "google_project_service" "eventarc_api" {
  service = "eventarc.googleapis.com"
}

resource "google_project_service" "apigateway_api" {
  service = "apigateway.googleapis.com"
}

# --------------------------------------------------
# Storage Buckets
# --------------------------------------------------

resource "google_storage_bucket" "uploads_bucket" {
  name          = "${var.project_id}-uploads"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = 7
    }
  }

  depends_on = [google_project_service.storage_api]
}

resource "google_storage_bucket" "processed_bucket" {
  name          = "${var.project_id}-processed"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  depends_on = [google_project_service.storage_api]
}

# --------------------------------------------------
# Pub/Sub Topics
# --------------------------------------------------

resource "google_pubsub_topic" "image_requests" {
  name = "image-processing-requests"

  depends_on = [google_project_service.pubsub_api]
}

resource "google_pubsub_topic" "image_results" {
  name = "image-processing-results"

  depends_on = [google_project_service.pubsub_api]
}

# --------------------------------------------------
# Service Account
# --------------------------------------------------

resource "google_service_account" "cloud_function_sa" {
  account_id   = "image-processing-sa"
  display_name = "Cloud Function Service Account"
}

# --------------------------------------------------
# IAM Roles
# --------------------------------------------------

resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cloud_function_sa.email}"
}

resource "google_project_iam_member" "pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.cloud_function_sa.email}"
}

resource "google_project_iam_member" "pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.cloud_function_sa.email}"
}

resource "google_project_iam_member" "secret_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_function_sa.email}"
}

resource "google_project_iam_member" "logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_function_sa.email}"
}
data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}

resource "google_project_iam_member" "gcs_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}
# --------------------------------------------------
# Secret Manager
# --------------------------------------------------

resource "google_secret_manager_secret" "api_key" {
  secret_id = "api-gateway-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager_api]
}

resource "google_secret_manager_secret_version" "api_key_version" {
  secret      = google_secret_manager_secret.api_key.id
  secret_data = "dummy-api-key"
}

# --------------------------------------------------
# Upload Image Function
# --------------------------------------------------

data "archive_file" "upload_function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/upload-image"
  output_path = "${path.module}/upload-image.zip"
}

resource "google_storage_bucket_object" "upload_archive" {
  name   = "upload-image.zip"
  bucket = google_storage_bucket.uploads_bucket.name
  source = data.archive_file.upload_function_zip.output_path
}

resource "google_cloudfunctions2_function" "upload_image" {

  name     = "upload-image"
  location = var.region

  build_config {
    runtime     = "python311"
    entry_point = "upload_image"

    source {
      storage_source {
        bucket = google_storage_bucket.uploads_bucket.name
        object = google_storage_bucket_object.upload_archive.name
      }
    }
  }

  service_config {
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = google_service_account.cloud_function_sa.email
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.storage.object.v1.finalized"

    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.uploads_bucket.name
    }

    retry_policy = "RETRY_POLICY_RETRY"
  }

  depends_on = [
    google_project_service.cloudfunctions_api,
    google_project_service.eventarc_api
  ]
}

# --------------------------------------------------
# Process Image Function
# --------------------------------------------------

data "archive_file" "process_function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/process-image"
  output_path = "${path.module}/process-image.zip"
}

resource "google_storage_bucket_object" "process_archive" {
  name   = "process-image.zip"
  bucket = google_storage_bucket.uploads_bucket.name
  source = data.archive_file.process_function_zip.output_path
}

resource "google_cloudfunctions2_function" "process_image" {

  name     = "process-image"
  location = var.region

  build_config {
    runtime     = "python311"
    entry_point = "process_image"

    source {
      storage_source {
        bucket = google_storage_bucket.uploads_bucket.name
        object = google_storage_bucket_object.process_archive.name
      }
    }
  }

  service_config {
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = google_service_account.cloud_function_sa.email
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.image_requests.id
  }

  depends_on = [
    google_project_service.cloudfunctions_api
  ]
}

# --------------------------------------------------
# Log Notification Function
# --------------------------------------------------

data "archive_file" "log_function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/log-notification"
  output_path = "${path.module}/log-notification.zip"
}

resource "google_storage_bucket_object" "log_archive" {
  name   = "log-notification.zip"
  bucket = google_storage_bucket.uploads_bucket.name
  source = data.archive_file.log_function_zip.output_path
}

resource "google_cloudfunctions2_function" "log_notification" {

  name     = "log-notification"
  location = var.region

  build_config {
    runtime     = "python311"
    entry_point = "log_notification"

    source {
      storage_source {
        bucket = google_storage_bucket.uploads_bucket.name
        object = google_storage_bucket_object.log_archive.name
      }
    }
  }

  service_config {
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = google_service_account.cloud_function_sa.email
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.image_results.id
  }
}

# --------------------------------------------------
# API Gateway
# --------------------------------------------------

resource "google_api_gateway_api" "image_api" {
  provider = google-beta
  api_id   = "image-upload-api"
}

resource "google_api_gateway_api_config" "image_api_config" {
  provider      = google-beta
  api           = google_api_gateway_api.image_api.api_id
  api_config_id = "image-upload-config"

  lifecycle {
    ignore_changes = all
  }

  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = filebase64("${path.module}/../api/openapi.yaml")
    }
  }
}

resource "google_api_gateway_gateway" "image_gateway" {
  provider   = google-beta
  gateway_id = "image-upload-gateway"
  api_config = google_api_gateway_api_config.image_api_config.id
  region     = var.region
}