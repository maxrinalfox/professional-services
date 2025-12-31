# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# --- Bootstrap Service Account ---
# Service account for the bootstrap Cloud Run Job itself
resource "google_service_account" "bootstrap_sa" {
  count        = var.enable_cloud_run_job ? 1 : 0
  account_id   = "cs-bootstrap-${var.environment}"
  display_name = "Service Account for Bootstrap Job (${var.environment})"
  project      = var.gcp_project_id
}

# --- Bootstrap Artifact Registry ---
# Docker repository for bootstrap job images
resource "google_artifact_registry_repository" "bootstrap_repo" {
  count         = var.enable_cloud_run_job ? 1 : 0
  location      = var.gcp_region
  repository_id = "cs-bootstrap-${var.environment}-repo"
  description   = "Docker repository for Creative Studio bootstrap images (${var.environment})"
  format        = "DOCKER"
  project       = var.gcp_project_id
}

# --- Bootstrap Service Account IAM Roles ---

# Grant bootstrap service account access to bootstrap artifact repository
resource "google_artifact_registry_repository_iam_member" "bootstrap_sa_ar_writer" {
  count      = var.enable_cloud_run_job ? 1 : 0
  location   = var.gcp_region
  repository = google_artifact_registry_repository.bootstrap_repo[0].name
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.bootstrap_sa[0].member
  project    = var.gcp_project_id
}

# Grant bootstrap service account Cloud SQL client access
resource "google_project_iam_member" "bootstrap_sa_cloudsql_client" {
  count   = var.enable_cloud_run_job ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/cloudsql.client"
  member  = google_service_account.bootstrap_sa[0].member
}

# Grant bootstrap service account Secret Manager access for runtime secrets
resource "google_project_iam_member" "bootstrap_sa_secret_accessor" {
  count   = var.enable_cloud_run_job ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = google_service_account.bootstrap_sa[0].member
}

# Grant bootstrap job SA permission to create/upload/delete objects to GCS bucket
# This is needed for seed_vto_assets and seed_media_templates functions
# Uses bucket_name from storage module output for consistency
# objectUser allows: create, read, update, delete on objects (minimal necessary permissions)
resource "google_storage_bucket_iam_member" "bootstrap_sa_gcs_object_user" {
  count  = var.enable_cloud_run_job ? 1 : 0
  bucket = var.genmedia_bucket_name
  role   = "roles/storage.objectUser"
  member = google_service_account.bootstrap_sa[0].member
}

# Grant bootstrap service account access to bootstrap job secrets
resource "google_secret_manager_secret_iam_member" "bootstrap_runtime_secret_accessor" {
  for_each = var.enable_cloud_run_job ? var.bootstrap_job_secrets : {}
  provider = google-beta

  project   = var.gcp_project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.bootstrap_sa[0].member

  depends_on = [google_service_account.bootstrap_sa]
}

# --- Bootstrap Cloud Build Trigger Service Account ---
# Service account for the Cloud Build trigger that manages the bootstrap job
resource "google_service_account" "bootstrap_trigger_sa" {
  count        = (var.enable_cloud_build && var.enable_cloud_run_job) ? 1 : 0
  account_id   = "cs-bootstrap-trig-${var.environment}"
  display_name = "Cloud Build Trigger Service Account for Bootstrap (${var.environment})"
  project      = var.gcp_project_id
}

# --- Bootstrap Trigger IAM Roles ---

# Grant bootstrap trigger SA permission to execute Cloud Run Job
resource "google_project_iam_member" "bootstrap_trigger_job_runner" {
  count   = (var.enable_cloud_build && var.enable_cloud_run_job) ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/run.admin"
  member  = google_service_account.bootstrap_trigger_sa[0].member
}

# Grant bootstrap trigger SA permission to use Cloud Build
resource "google_project_iam_member" "bootstrap_trigger_cloudbuild_service_agent" {
  count   = (var.enable_cloud_build && var.enable_cloud_run_job) ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = google_service_account.bootstrap_trigger_sa[0].member
}

# Grant bootstrap trigger SA permission to write logs
resource "google_project_iam_member" "bootstrap_trigger_logging_writer" {
  count   = (var.enable_cloud_build && var.enable_cloud_run_job) ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.bootstrap_trigger_sa[0].member
}

# Grant bootstrap trigger SA permission to write to artifact registry (push images)
# This is needed for Cloud Build to build and push the bootstrap Docker image
resource "google_artifact_registry_repository_iam_member" "bootstrap_trigger_sa_ar_writer" {
  count      = (var.enable_cloud_build && var.enable_cloud_run_job) ? 1 : 0
  location   = var.gcp_region
  repository = google_artifact_registry_repository.bootstrap_repo[0].name
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.bootstrap_trigger_sa[0].member
  project    = var.gcp_project_id
}

# Grant bootstrap trigger SA permission to impersonate the bootstrap job service account
# This is needed for Cloud Build to create the Cloud Run Job with the specified service account
# and to pass the job SA when executing the job
resource "google_service_account_iam_member" "bootstrap_trigger_can_impersonate_job_sa" {
  count              = (var.enable_cloud_build && var.enable_cloud_run_job) ? 1 : 0
  service_account_id = google_service_account.bootstrap_sa[0].name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.bootstrap_trigger_sa[0].member
}

# --- Outputs ---
output "bootstrap_sa_email" {
  value       = var.enable_cloud_run_job ? google_service_account.bootstrap_sa[0].email : null
  description = "Email of the bootstrap job service account"
}

output "bootstrap_trigger_sa_email" {
  value       = (var.enable_cloud_build && var.enable_cloud_run_job) ? google_service_account.bootstrap_trigger_sa[0].email : null
  description = "Email of the bootstrap trigger service account"
}

output "bootstrap_repo_name" {
  value       = var.enable_cloud_run_job ? google_artifact_registry_repository.bootstrap_repo[0].repository_id : null
  description = "Name of the bootstrap artifact registry repository"
}
