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

# --- Service Accounts ---
resource "google_service_account" "run_sa" {
  account_id   = "${var.resource_prefix}-${var.environment}-run"
  display_name = "SA for ${var.service_name} (${var.environment}) Runtime"
}

resource "google_service_account" "trigger_sa" {
  account_id   = "${var.resource_prefix}-${var.environment}-trig"
  display_name = "SA for ${var.service_name} (${var.environment}) Trigger"
}

# --- Core Resources ---
resource "google_artifact_registry_repository" "repo" {
  location      = var.gcp_region
  repository_id = "${var.resource_prefix}-${var.environment}-repo"
  description   = "Docker repository for ${var.service_name}"
  format        = "DOCKER"
}

resource "google_cloud_run_v2_service" "this" {
  name             = var.service_name
  location         = var.gcp_region
  custom_audiences = var.custom_audiences
  deletion_protection = false

  template {
    service_account = google_service_account.run_sa.email

    dynamic "vpc_access" {
      for_each = var.vpc_connector_id != null ? [1] : []
      content {
        connector = var.vpc_connector_id
        egress    = "PRIVATE_RANGES_ONLY"
      }
    }
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [var.cloud_sql_connection_name]
      }
    }
    containers {
      # --- Container Image Configuration ---
      # IMPORTANT: This placeholder image is used during initial Cloud Run service creation ONLY.
      # The actual application image is deployed via Cloud Build CI/CD pipeline (cloudbuild.yaml).
      #
      # Why a placeholder image?
      # - Cloud Run service requires a valid image URI to be created
      # - The placeholder satisfies this requirement during Terraform apply
      # - Actual application code is built and pushed to Artifact Registry by Cloud Build
      #
      # How it works:
      # 1. Terraform creates Cloud Run service with this placeholder image
      # 2. Cloud Build trigger monitors GitHub repository for code changes
      # 3. On push to configured branch, Cloud Build:
      #    a. Builds your application code into a Docker image
      #    b. Pushes image to Artifact Registry (${var.gcp_region}-docker.pkg.dev/...)
      #    c. Updates Cloud Run service with the new image
      # 4. The 'lifecycle.ignore_changes' below ensures Terraform ignores image updates
      #    (allows Cloud Build to manage image without Terraform trying to revert it)
      #
      # Note: This is a standard pattern for serverless deployments - Terraform handles
      # infrastructure setup and lifecycle management, while CI/CD handles application updates.
      image = "us-docker.pkg.dev/cloudrun/container/hello:latest"
      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      env {
        name = "INSTANCE_CONNECTION_NAME"
        value = var.cloud_sql_connection_name
      }
      env {
        name = "DB_HOST"
        value = "/cloudsql/${var.cloud_sql_connection_name}"
      }
      env {
        name = "DB_NAME"
        value = var.db_name
      }
      env {
        name = "DB_USER"
        value = var.db_user
      }

      env {
        name = "DB_PASS"
        value_source {
          secret_key_ref {
            secret = var.db_secret_id
            version = "latest"
          }
        }
      }

      # non secret env vars
      dynamic "env" {
        for_each = var.container_env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # secrets
      dynamic "env" {
        for_each = var.runtime_secrets
        content {
          name = env.key # The ENV_VAR_NAME
          value_source {
            secret_key_ref {
              secret  = env.value # The SECRET_NAME
              version = "latest"
            }
          }
        }
      }

      volume_mounts {
        name = "cloudsql"
        mount_path = "/cloudsql"
      }
    }
    scaling {
      min_instance_count = var.scaling_min_instances
      max_instance_count = var.scaling_max_instances
    }
  }

  # --- Lifecycle Management ---
  # Prevent Terraform from reverting image updates made by Cloud Build CI/CD pipeline.
  #
  # Why ignore_changes = image?
  # - Cloud Build automatically updates the image whenever code is pushed to GitHub
  # - Without ignore_changes, running 'terraform apply' would revert the image to
  #   the placeholder, undoing the latest deployment
  # - This configuration allows Cloud Build to manage image deployments independently
  #
  # What Terraform WILL manage:
  # - Service configuration (environment variables, scaling, network settings, etc.)
  # - IAM roles and access control
  # - All other infrastructure aspects
  #
  # What Cloud Build manages:
  # - Actual Docker image (source code → Docker image → Artifact Registry → Cloud Run)
  lifecycle {
    ignore_changes = [template[0].containers[0].image, client, client_version]
  }
}

resource "google_cloudbuild_trigger" "this" {
  count           = var.enable_cloud_build_trigger ? 1 : 0
  name            = "${var.service_name}-trigger"
  location        = var.gcp_region
  service_account = google_service_account.trigger_sa.id
  filename        = var.cloudbuild_yaml_path
  substitutions   = merge(var.build_substitutions, {
    _REPO_NAME           = google_artifact_registry_repository.repo.name
    _ARTIFACT_REGISTRY   = google_artifact_registry_repository.repo.location
  })

  repository_event_config {
    repository = var.source_repository_id
    push {
      branch = "^${var.github_branch_name}$"
    }
  }

  included_files = var.included_files_glob
}

# --- Cloud Build Trigger Service Account IAM Bindings ---
# These permissions allow the Cloud Build trigger (trigger_sa) to:
# - Write logs to Cloud Logging
# - Push container images to Artifact Registry
# - Deploy to Cloud Run
# - Impersonate the Cloud Run runtime service account
#
# Only created when Cloud Build trigger is enabled

resource "google_project_iam_member" "trigger_sa_logging_writer" {
  count   = var.enable_cloud_build_trigger ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.trigger_sa.member
}

resource "google_artifact_registry_repository_iam_member" "trigger_sa_ar_writer" {
  count      = var.enable_cloud_build_trigger ? 1 : 0
  location   = var.gcp_region
  repository = google_artifact_registry_repository.repo.name
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.trigger_sa.member
}

resource "google_cloud_run_v2_service_iam_member" "trigger_sa_run_developer" {
  count    = var.enable_cloud_build_trigger ? 1 : 0
  name     = google_cloud_run_v2_service.this.name
  location = google_cloud_run_v2_service.this.location
  role     = "roles/run.developer"
  member   = google_service_account.trigger_sa.member
}

resource "google_service_account_iam_member" "trigger_sa_impersonate_run_sa" {
  count              = var.enable_cloud_build_trigger ? 1 : 0
  service_account_id = google_service_account.run_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.trigger_sa.member
}

# --- Cloud Run Runtime Service Account IAM Bindings ---
# These permissions allow the Cloud Run service (run_sa) to:
# - Access Vertex AI APIs for ML features (aiplatform.user)
# - Read/write to Cloud Storage buckets (storage.objectAdmin)
# - Access Firestore database (firebase.developAdmin)
# - Create temporary access tokens for other services (iam.serviceAccountTokenCreator)
# - Access Cloud SQL databases (cloudsql.client)
# - Read secrets from Secret Manager (secretmanager.secretAccessor)

locals {
  # List of project-level roles required by the Cloud Run service account
  cloud_run_sa_backend_permissions = [
    "roles/aiplatform.user",
    "roles/storage.objectAdmin",
    "roles/firebase.developAdmin",
    "roles/iam.serviceAccountTokenCreator",
    "roles/cloudsql.client",
  ]
}

# Grant project-level permissions to Cloud Run runtime service account
resource "google_project_iam_member" "run_sa_project_permissions" {
  for_each = toset(local.cloud_run_sa_backend_permissions)

  project = var.gcp_project_id
  role    = each.value
  member  = google_service_account.run_sa.member
}

# Grant Secret Manager access to Cloud Run runtime service account
# Required for reading database password from Secret Manager
resource "google_secret_manager_secret_iam_member" "run_sa_db_password_access" {
  secret_id = var.db_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.run_sa.member
}

# --- Cloud Run Access Control ---
# Grant Cloud Run invoker role (roles/run.invoker) to specified identities
# This controls who can invoke/call the Cloud Run service
# Format: "user:email@domain.com", "group:group@domain.com", "serviceAccount:sa@project.iam.gserviceaccount.com"
resource "google_cloud_run_service_iam_member" "invoker" {
  for_each = toset(var.invoker_identities)

  service  = google_cloud_run_v2_service.this.name
  location = google_cloud_run_v2_service.this.location
  role     = "roles/run.invoker"
  member   = each.value
}
