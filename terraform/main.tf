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
}

resource "google_storage_bucket" "processed_bucket" {
  name          = "${var.project_id}-processed"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true
}

# --------------------------------------------------
# Pub/Sub Topics
# --------------------------------------------------

resource "google_pubsub_topic" "image_requests" {
  name = "image-processing-requests"
}

resource "google_pubsub_topic" "image_results" {
  name = "image-processing-results"
}

# --------------------------------------------------
# Service Account
# --------------------------------------------------

resource "google_service_account" "cloud_function_sa" {
  account_id   = "image-processing-sa"
  display_name = "Cloud Function Service Account"
}

# --------------------------------------------------
# Secret Manager
# --------------------------------------------------

resource "google_secret_manager_secret" "api_key" {
  secret_id = "api-gateway-key"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "api_key_version" {
  secret      = google_secret_manager_secret.api_key.id
  secret_data = "dummy-api-key"
}

# --------------------------------------------------
# STEP 3 — Upload Image Function
# --------------------------------------------------

data "archive_file" "upload_function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/functions/upload-image"
  output_path = "${path.module}/functions/upload-image.zip"
}

resource "google_storage_bucket_object" "upload_function_archive" {
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
        object = google_storage_bucket_object.upload_function_archive.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.image_requests.id
  }
}

# --------------------------------------------------
# STEP 4 — Process Image Function
# --------------------------------------------------

data "archive_file" "process_function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/functions/process-image"
  output_path = "${path.module}/functions/process-image.zip"
}

resource "google_storage_bucket_object" "process_function_archive" {
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
        object = google_storage_bucket_object.process_function_archive.name
      }
    }
  }

  service_config {

    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
  }

  event_trigger {

    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"

    pubsub_topic = google_pubsub_topic.image_requests.id
  }
}

# --------------------------------------------------
# STEP 5 — Log Notification Function
# --------------------------------------------------

data "archive_file" "log_function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/functions/log-notification"
  output_path = "${path.module}/functions/log-notification.zip"
}

resource "google_storage_bucket_object" "log_function_archive" {
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
        object = google_storage_bucket_object.log_function_archive.name
      }
    }
  }

  service_config {

    available_memory   = "256M"
    timeout_seconds    = 60
    max_instance_count = 1
  }

  event_trigger {

    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"

    pubsub_topic = google_pubsub_topic.image_results.id
  }
}

# --------------------------------------------------
# STEP 6 — API Gateway
# --------------------------------------------------

resource "google_api_gateway_api" "image_api" {

  provider = google-beta

  api_id = "image-upload-api"

  depends_on = [google_project_service.apigateway_api]
}

resource "google_api_gateway_api_config" "image_api_config" {

  provider = google-beta

  api = google_api_gateway_api.image_api.api_id

  api_config_id = "image-upload-config"

  openapi_documents {

    document {

      path = "openapi.yaml"

      contents = filebase64("${path.module}/api/openapi.yaml")
    }
  }
}

resource "google_api_gateway_gateway" "image_gateway" {

  provider = google-beta

  gateway_id = "image-upload-gateway"

  api_config = google_api_gateway_api_config.image_api_config.id

  region = var.region
}