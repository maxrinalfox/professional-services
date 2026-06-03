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
  name                = var.service_name
  location            = var.gcp_region
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

      # NOTE: ALL environment variables (including database connection vars and container_env_vars)
      # and runtime_secrets are managed by Cloud Build, not Terraform. This allows:
      # 1. Service to be created without needing placeholder values for secrets
      # 2. Secrets to be mounted AFTER IAM bindings are created
      # 3. Cloud Build to be the single source of truth for runtime configuration
      #
      # Database connection variables set by Cloud Build:
      # - INSTANCE_CONNECTION_NAME: Cloud SQL connection string (PROJECT:REGION:INSTANCE)
      # - DB_HOST: Path to Cloud SQL socket (/cloudsql/...)
      # - DB_NAME: Database name
      # - DB_USER: Database username
      # - DB_PASS: Database password (from Secret Manager)
      #
      # Cloud Build's deploy step (cloudbuild.yaml) uses gcloud run deploy with:
      # - --set-env-vars for all environment variables (database + application)
      # - --set-secrets for runtime_secrets (GOOGLE_TOKEN_AUDIENCE mapped to OAUTH_CLIENT_ID)
      #
      # Terraform's lifecycle.ignore_changes=[template[0].containers[0].env] ensures
      # Cloud Build can update environment variables without Terraform reverting them.
      #
      # See: examples/creative-studio/backend/cloudbuild.yaml (Deploy step)

      volume_mounts {
        name       = "cloudsql"
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
  # Why ignore_changes?
  # - Cloud Build automatically updates the image whenever code is pushed to GitHub
  # - Without ignore_changes, running 'terraform apply' would revert the image to
  #   the placeholder, undoing the latest deployment
  # - Scaling can be adjusted manually in GCP Console without Terraform reverting changes
  #
  # What Terraform WILL manage:
  # - Service configuration (network settings, resource limits, etc.)
  # - IAM roles and access control
  # - All other infrastructure aspects
  #
  # What is ignored (managed externally):
  # - Docker image (managed by Cloud Build CI/CD)
  # - Environment variables and secrets (managed by Cloud Build)
  # - Scaling (can be manually adjusted in GCP Console, won't be reverted by Terraform)
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      template[0].containers[0].env,  # Cloud Build manages env vars and secrets
      template[0].scaling,            # Allow manual scaling adjustments in GCP Console
      client,
      client_version
    ]
  }
}

resource "google_cloudbuild_trigger" "this" {
  count           = var.enable_cloud_build_trigger ? 1 : 0
  name            = "cstudio-${var.environment}-backend-trigger"
  location        = var.gcp_region
  service_account = google_service_account.trigger_sa.id
  filename        = var.cloudbuild_yaml_path
  substitutions = merge(var.build_substitutions, {
    _REPO_NAME         = google_artifact_registry_repository.repo.name
    _ARTIFACT_REGISTRY = google_artifact_registry_repository.repo.location
    # Database connection variables (required for backend to connect to Cloud SQL)
    _INSTANCE_CONNECTION_NAME = var.cloud_sql_connection_name
    _DB_HOST                  = "/cloudsql/${var.cloud_sql_connection_name}"
    _DB_NAME                  = var.db_name
    _DB_USER                  = var.db_user
    # Environment variables: comma-separated KEY=VALUE pairs
    # Includes both application vars (from container_env_vars), database connection vars, and admin user config
    # Cloud Build will use: gcloud run deploy --set-env-vars=_BACKEND_ENV_VARS
    _BACKEND_ENV_VARS = join(",", concat(
      [for k, v in var.container_env_vars : "${k}=${v}"],
      [
        "INSTANCE_CONNECTION_NAME=${var.cloud_sql_connection_name}",
        "DB_HOST=/cloudsql/${var.cloud_sql_connection_name}",
        "DB_NAME=${var.db_name}",
        "DB_USER=${var.db_user}"
      ],
      var.admin_user_email != null ? ["ADMIN_USER_EMAIL=${var.admin_user_email}"] : []
    ))
    # Runtime secrets: comma-separated ENV_VAR=SECRET_NAME:VERSION pairs
    # Includes DB_PASS secret and application-level secrets (GOOGLE_TOKEN_AUDIENCE)
    # Cloud Build will use: gcloud run deploy --set-secrets=_BACKEND_SECRETS
    _BACKEND_SECRETS = join(",", concat(
      [for env_var, secret_name in var.runtime_secrets : "${env_var}=${secret_name}:latest"],
      ["DB_PASS=${var.db_secret_id}:latest"]
    ))
  })

  repository_event_config {
    repository = var.source_repository_id
    push {
      branch = "^${var.github_branch_name}$"
    }
  }

  included_files = var.included_files_glob

  # When require_approval_for_deploy is true, the build will become pending
  # and require explicit approval before running (best practice for production)
  approval_config {
    approval_required = var.require_approval_for_deploy
  }
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
# - Access Cloud SQL databases (cloudsql.client)
# - Manage and execute GCP Workflows (workflows.editor + workflows.invoker)
# - Act as itself, to attach itself as a workflow's identity (serviceAccountUser)
# - Read secrets from Secret Manager (secretmanager.secretAccessor)

locals {
  # List of project-level roles required by the Cloud Run service account
  cloud_run_sa_backend_permissions = [
    "roles/aiplatform.user",
    "roles/storage.objectAdmin",
    "roles/firebase.developAdmin",
    "roles/cloudsql.client",
    # Workflows feature (IAS-3775): manage workflow definitions
    # (workflows.editor) and create executions (workflows.invoker).
    "roles/workflows.editor",
    "roles/workflows.invoker",
  ]
}

# Grant project-level permissions to Cloud Run runtime service account
resource "google_project_iam_member" "run_sa_project_permissions" {
  for_each = toset(local.cloud_run_sa_backend_permissions)

  project = var.gcp_project_id
  role    = each.value
  member  = google_service_account.run_sa.member
}

# Allow the runtime SA to act as itself (IAS-3775). Required to create GCP
# Workflows whose service_account is this SA: the workflow runs as it and makes
# OIDC-authenticated callbacks to the backend. Without this, workflow creation
# fails with "iam.serviceAccounts.ActAs is required to use service account as
# workflow identity". Scoped to this single SA (least privilege).
resource "google_service_account_iam_member" "run_sa_act_as_self" {
  service_account_id = google_service_account.run_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.run_sa.member
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
#
# Only creates bindings for explicitly listed identities (no default public access)
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = toset(var.invoker_identities)

  name     = google_cloud_run_v2_service.this.name
  location = google_cloud_run_v2_service.this.location
  role     = "roles/run.invoker"
  member   = each.value
}
