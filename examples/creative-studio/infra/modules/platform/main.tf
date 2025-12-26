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

# --- Enable Required Google Cloud APIs ---
# These APIs are foundational for all platform infrastructure
locals {
  required_apis = [
    # ========== FIREBASE CORE APIs (Required for Phase 2 automation) ==========
    "firebase.googleapis.com",             # Firebase Management API - REQUIRED for google_firebase_project
    "firebasehosting.googleapis.com",      # Firebase Hosting API
    "identitytoolkit.googleapis.com",      # Firebase Identity Toolkit - Required for Identity Platform auth
    "cloudresourcemanager.googleapis.com", # Cloud Resource Manager - REQUIRED for Firebase project linking

    # ========== CORE INFRASTRUCTURE APIs ==========
    "serviceusage.googleapis.com",   # Service Usage API - REQUIRED to enable other APIs
    "iam.googleapis.com",            # IAM Management - REQUIRED for service accounts & roles
    "iamcredentials.googleapis.com", # IAM Credentials

    # ========== CLOUD BUILD & DEPLOYMENT APIs ==========
    "cloudbuild.googleapis.com",       # Cloud Build - REQUIRED for CI/CD triggers
    "artifactregistry.googleapis.com", # Artifact Registry - Required for container images

    # ========== CLOUD RUN APIs ==========
    "run.googleapis.com", # Cloud Run - REQUIRED for serverless backend

    # ========== NETWORKING & VPC APIs ==========
    "compute.googleapis.com",           # Compute Engine - REQUIRED for VPC resources
    "servicenetworking.googleapis.com", # Service Networking - REQUIRED for Cloud SQL private IP
    "vpcaccess.googleapis.com",         # Serverless VPC Connector - REQUIRED for VPC access

    # ========== DATABASE APIs ==========
    "sqladmin.googleapis.com", # Cloud SQL Admin - REQUIRED for Cloud SQL management

    # ========== DATA & STORAGE APIs ==========
    "firestore.googleapis.com",      # Firestore Database
    "cloudfunctions.googleapis.com", # Cloud Functions (optional, for advanced features)
    "aiplatform.googleapis.com",     # Vertex AI (for ML features)
    "texttospeech.googleapis.com",   # Text-to-Speech (if used by backend)

    # ========== SECRETS & SECURITY APIs ==========
    "secretmanager.googleapis.com", # Secret Manager - REQUIRED for storing credentials
  ]
}

resource "google_project_service" "apis" {
  # Use a for_each loop to enable each API from the variable list
  for_each = toset(local.required_apis)

  project = var.gcp_project_id
  service = each.key

  # This prevents Terraform from disabling APIs when you run `terraform destroy`
  disable_on_destroy = false
}

# --- API Initialization Delay ---
# Google Cloud APIs take time to fully initialize after being enabled.
# This is especially important for Identity Toolkit which is needed for Identity Platform.
# Without this delay, "SERVICE_DISABLED" errors can occur even though the API is enabled.
# Reference: https://cloud.google.com/docs/authentication/adc-troubleshooting/user-creds
resource "time_sleep" "api_initialization" {
  create_duration = "10s"
  depends_on = [
    google_project_service.apis
  ]
}

# --- Shared Platform Resources ---

resource "google_storage_bucket" "genmedia" {
  name                        = "${var.gcp_project_id}-cs-${var.environment}-bucket"
  location                    = var.gcp_region
  uniform_bucket_level_access = true

  cors {
    origin          = ["*"]
    method          = ["GET", "PUT", "POST", "DELETE", "HEAD", "OPTIONS"]
    response_header = ["Content-Type", "Access-Control-Allow-Origin", "x-goog-resumable", "Authorization", "Origin"]
    max_age_seconds = 3600
  }
}

resource "google_service_account" "bucket_reader_sa" {
  account_id   = "cs-${var.environment}-read"
  display_name = "SA for reading GenMedia (${var.environment}) bucket"
}

resource "google_storage_bucket_iam_member" "bucket_viewer_binding" {
  bucket = google_storage_bucket.genmedia.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.bucket_reader_sa.member
}

resource "google_storage_bucket_iam_member" "bucket_creator_binding" {
  bucket = google_storage_bucket.genmedia.name
  role   = "roles/storage.objectCreator"
  member = google_service_account.bucket_reader_sa.member
}

data "google_project" "project" {
  project_id = var.gcp_project_id
}

# --- Firebase Web App Configuration (Auto-Discovery) ---
# This data source retrieves the Firebase web app configuration automatically
# instead of requiring manual population via bootstrap scripts.
#
# IMPORTANT: The Firebase web app must already exist in the Firebase project.
# This typically happens when:
# 1. Firebase project is created via GCP Console (or via google_firebase_project resource in Phase 2)
# 2. A web app is created in Firebase (manually or via google_firebase_web_app resource in Phase 2)
# 3. This data source reads the app's configuration
#
# The data source extracts all 7 Firebase SDK values needed by the frontend,
# eliminating the need to manually enter them via bootstrap scripts or .tfvars.
#
# Note: This data source requires the google-beta provider as it's in beta
# Phase 1 & 2 Compatible: Works with both manually created and auto-created web apps
#
# IMPORTANT: This is ALWAYS evaluated (not conditional on enable_cloud_build)
# Firebase web app configuration is needed for:
# - Frontend service deployment (Firebase Hosting)
# - Identity Platform setup
# The Cloud Build trigger is optional, but the web app itself is required infrastructure
data "google_firebase_web_app_config" "default" {
  count    = (var.firebase_web_app_id != null || (var.enable_cloud_build && var.firebase_web_app_id == null)) ? 1 : 0
  provider = google-beta

  # Determine which web app ID to use:
  # - Phase 1 Manual: Use provided firebase_web_app_id
  # - Phase 2 Automation: Use auto-created google_firebase_web_app.default app_id
  web_app_id = var.firebase_web_app_id != null ? var.firebase_web_app_id : google_firebase_web_app.default[0].app_id

  project = var.gcp_project_id
}

# --- Predictable URLs & Environment Variables ---
locals {
  region_code = join("", [for s in split("-", var.gcp_region) : substr(s, 0, 1)])
  backend_url = "https://${var.backend_service_name}-${data.google_project.project.number}.${var.gcp_region}.run.app"

  frontend_url = "https://${var.gcp_project_id}.web.app" # Predictable Firebase URL

  # Auto-computed Firebase SDK configuration from data source
  # These values are extracted from the Firebase web app configuration
  # No manual entry in .tfvars or bootstrap script needed!
  # Always available if Firebase web app exists (regardless of Cloud Build setting)
  firebase_sdk_config = length(data.google_firebase_web_app_config.default) > 0 ? {
    FIREBASE_API_KEY             = data.google_firebase_web_app_config.default[0].api_key
    FIREBASE_AUTH_DOMAIN         = data.google_firebase_web_app_config.default[0].auth_domain
    FIREBASE_PROJECT_ID          = data.google_firebase_web_app_config.default[0].project
    FIREBASE_STORAGE_BUCKET      = data.google_firebase_web_app_config.default[0].storage_bucket
    FIREBASE_MESSAGING_SENDER_ID = data.google_firebase_web_app_config.default[0].messaging_sender_id
    FIREBASE_MEASUREMENT_ID      = data.google_firebase_web_app_config.default[0].measurement_id
  } : {}

  # Extract secret names from auto-computed Firebase config
  # This replaces the need to manually list frontend_secrets in .tfvars
  frontend_secrets_auto = keys(local.firebase_sdk_config)

  # Auto-populate custom audiences with GCP Project ID (gcp_project_id is always included)
  # Optionally include OAuth Client ID if provided
  # Uses compact() to filter out empty/null values
  backend_custom_audiences_computed = compact(concat(
    [var.gcp_project_id],        # Always include project ID
    var.backend_custom_audiences # Add any additional audiences (e.g., OAuth Client ID)
  ))

  frontend_custom_audiences_computed = compact(concat(
    [var.gcp_project_id],         # Always include project ID
    var.frontend_custom_audiences # Add any additional audiences (e.g., OAuth Client ID)
  ))

  backend_env_vars = merge(
    var.be_env_vars,
    {
      "CORS_ORIGINS"     = "[\"${local.frontend_url}\"]"
      "GENMEDIA_BUCKET"  = google_storage_bucket.genmedia.name
      "SIGNING_SA_EMAIL" = google_service_account.bucket_reader_sa.email
    }
  )

  # Reference to source repo, handling conditional creation
  source_repository_id = var.enable_cloud_build ? google_cloudbuildv2_repository.source_repo[0].id : ""
}


# --- Cloud Build Repository Connection ---
resource "google_cloudbuildv2_repository" "source_repo" {
  count             = var.enable_cloud_build ? 1 : 0
  provider          = google-beta
  name              = var.github_repo_name
  location          = var.gcp_region
  parent_connection = "projects/${var.gcp_project_id}/locations/${var.gcp_region}/connections/${var.github_conn_name}"
  remote_uri        = "https://github.com/${var.github_repo_owner}/${var.github_repo_name}.git"
}

# --- VPC Network Setup ---
module "vpc_network" {
  count                 = var.vpc_enable ? 1 : 0
  source                = "../vpc_network"
  project_id            = var.gcp_project_id
  gcp_region            = var.gcp_region
  name                  = "cs-${var.environment}"
  primary_subnet_cidr   = var.vpc_primary_subnet_cidr
  connector_subnet_cidr = var.vpc_connector_subnet_cidr

  depends_on = [google_project_service.apis]
}

# Postgres Database related
# 1. Generate a secure random password for Cloud SQL
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# 2. Create Secret Manager secret for database password
resource "google_secret_manager_secret" "db_password" {
  secret_id = "creative-studio-db-password"
  project   = var.gcp_project_id

  replication {
    user_managed {
      replicas {
        location = var.gcp_region
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# 3. Store the generated password in Secret Manager
resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

# 4. Call PostgreSQL Module
module "postgresql" {
  source     = "../postgresql"
  project_id = var.gcp_project_id
  gcp_region = var.gcp_region

  # Pass the generated password
  db_password = google_secret_manager_secret_version.db_password.secret_data

  # Control whether the instance has a public IP
  public_ip_enabled = var.cloud_sql_public_ip_enabled

  # Private network configuration (always pass, will be null if vpc_enable=false)
  vpc_network_id = var.vpc_enable ? module.vpc_network[0].network_id : null

  depends_on = [
    google_project_service.apis,
    module.vpc_network,
  ]
}

# --- Service Module Calls ---
# IMPORTANT: Cloud Run services are ALWAYS created
# Cloud Build triggers are CONDITIONAL based on enable_cloud_build
module "backend_service" {
  source = "../cloud-run-service"

  gcp_project_id        = var.gcp_project_id
  gcp_region            = var.gcp_region
  environment           = var.environment
  service_name          = var.backend_service_name
  resource_prefix       = "cs-be"
  github_conn_name      = var.github_conn_name
  github_repo_owner     = var.github_repo_owner
  github_repo_name      = var.github_repo_name
  github_branch_name    = var.github_branch_name
  cloudbuild_yaml_path  = "examples/creative-studio/backend/cloudbuild.yaml"
  included_files_glob   = ["**/creative-studio/backend/**"]
  container_env_vars    = merge(
    local.backend_env_vars,
    {
      "USE_CLOUD_SQL_PRIVATE_IP" = var.cloud_sql_public_ip_enabled ? "false" : "true"
    }
  )
  runtime_secrets       = var.backend_runtime_secrets
  custom_audiences      = local.backend_custom_audiences_computed # Auto-populated with gcp_project_id
  scaling_min_instances = 1
  source_repository_id  = local.source_repository_id
  cpu                   = var.be_cpu
  memory                = var.be_memory
  build_substitutions = merge(var.be_build_substitutions,
    {
      _REGION       = var.gcp_region
      _SERVICE_NAME = var.backend_service_name
    }
  )

  # VPC configuration
  vpc_connector_id = var.vpc_enable ? module.vpc_network[0].vpc_connector_id : null

  # database
  cloud_sql_connection_name = module.postgresql.connection_name
  db_name                   = module.postgresql.db_name
  db_user                   = module.postgresql.db_user

  # Pass the Secret ID reference (NOT the value) for Cloud Run - environment-specific
  db_secret_id = google_secret_manager_secret.db_password.secret_id

  # Cloud Run access control - grant invoker role to specified identities
  invoker_identities = var.backend_invoker_identities

  # Cloud Build trigger configuration - only create trigger when CI/CD is enabled
  enable_cloud_build_trigger = var.enable_cloud_build

  depends_on = [
    google_project_service.apis
  ]
}

resource "google_firebase_project" "default" {
  # Firebase project is needed for:
  # - Firebase Hosting (frontend deployment)
  # - Identity Platform (user authentication)
  # - Firestore database
  #
  # Should be created whenever ANY of these features are enabled:
  count    = (var.enable_cloud_build || var.enable_identity_platform) ? 1 : 0
  provider = google-beta
  project  = var.gcp_project_id

  depends_on = [
    time_sleep.api_initialization  # Wait for all APIs to fully initialize
  ]
}

# --- Identity Platform Configuration (Phase 3) ---
# Enables Firebase Authentication and Google Cloud Identity Platform
# Provides authentication services for both frontend and backend
#
# IMPORTANT: This resource is now controlled by enable_identity_platform variable
# which is INDEPENDENT of enable_cloud_build. This allows you to:
# - Have authentication without CI/CD deployment (enable_identity_platform=true, enable_cloud_build=false)
# - Have CI/CD without authentication (enable_identity_platform=false, enable_cloud_build=true)
# - Control infrastructure and authentication separately
#
# Reference: https://firebase.google.com/docs/projects/terraform/get-started#tf-sample-auth
resource "google_identity_platform_config" "default" {
  count    = var.enable_identity_platform ? 1 : 0
  provider = google-beta
  project  = var.gcp_project_id

  # Identity Platform configuration is intentionally minimal
  # Sign-in methods and other settings are managed via GCP Console
  # or can be configured separately as needed

  # Ignore changes to attributes managed by Google Cloud
  # Google Cloud manages fields like multi_tenant, phone_number, sign_in, etc.
  # These appear in the config but are not managed by Terraform
  # Without this, every terraform plan will show spurious changes
  lifecycle {
    ignore_changes = all  # Ignore all changes since configuration is managed externally
  }

  depends_on = [
    google_firebase_project.default[0],
    time_sleep.api_initialization  # Wait for all APIs (including Identity Toolkit) to fully initialize
  ]
}

# --- Google OAuth IDP Configuration ---
# OAuth configuration for Google Sign-In is managed via GCP Console
# This allows greater flexibility and better integration with Google's authentication systems
# Reference: https://firebase.google.com/docs/auth/social/google

# Phase 2: Automated Firebase Web App Creation
# Creates a Firebase web app automatically (if enable_cloud_build = true and firebase_web_app_id not provided)
resource "google_firebase_web_app" "default" {
  count           = (var.enable_cloud_build && var.firebase_web_app_id == null) ? 1 : 0
  provider        = google-beta
  project         = var.gcp_project_id
  display_name    = "Creative Studio Frontend"
  deletion_policy = "DELETE"

  depends_on = [google_firebase_project.default]
}

module "frontend_service" {
  source = "../firebase-hosting-service"

  source_repository_id = local.source_repository_id
  gcp_project_id       = var.gcp_project_id
  gcp_region           = var.gcp_region
  firebase_project_id  = google_firebase_project.default[0].project
  service_name         = var.gcp_project_id
  trigger_name         = var.frontend_service_name
  environment          = var.environment
  resource_prefix      = "cs-fe"
  github_branch_name   = var.github_branch_name
  cloudbuild_yaml_path = "examples/creative-studio/frontend/cloudbuild-deploy.yaml"
  included_files_glob  = ["**/creative-studio/frontend/**"]

  build_substitutions = merge(
    var.fe_build_substitutions,
    {
      # This block should ONLY contain non-secret, underscore-prefixed values
      _BACKEND_URL         = local.backend_url # Backend Cloud Run URL for frontend API calls
      _FE_SERVICE_NAME     = var.frontend_service_name
      _BACKEND_SERVICE_ID  = var.backend_service_name
      _FIREBASE_PROJECT_ID = var.gcp_project_id
    }
  )

  # Cloud Build trigger configuration - only create trigger when CI/CD is enabled
  enable_cloud_build_trigger = var.enable_cloud_build

  depends_on = [google_project_service.apis]
}

module "frontend_secrets" {
  source = "../secret-manager"

  gcp_project_id = var.gcp_project_id
  # Use auto-computed Firebase secrets instead of manual input
  # These are automatically extracted from the Firebase web app configuration
  secret_names      = concat(local.frontend_secrets_auto, var.frontend_secrets_additional)
  accessor_sa_email = module.frontend_service.trigger_sa_member
}

module "backend_secrets" {
  source = "../secret-manager"

  gcp_project_id    = var.gcp_project_id
  secret_names      = var.backend_secrets
  accessor_sa_email = module.backend_service.trigger_sa_member
}

# Grant the backend Cloud Run runtime service account access to backend secrets
# The runtime service account needs secret access to read GOOGLE_TOKEN_AUDIENCE at runtime
resource "google_secret_manager_secret_iam_member" "backend_runtime_secret_accessor" {
  for_each = toset(var.backend_secrets)

  provider  = google-beta
  project   = var.gcp_project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = module.backend_service.run_sa_member

  depends_on = [module.backend_secrets]
}

# Grant the bootstrap service account access to bootstrap job secrets
# Only created when bootstrap job is enabled
resource "google_secret_manager_secret_iam_member" "bootstrap_runtime_secret_accessor" {
  for_each = var.enable_cloud_run_job ? var.bootstrap_job_secrets : {}

  provider  = google-beta
  project   = var.gcp_project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.bootstrap_sa[0].member

  depends_on = [google_service_account.bootstrap_sa]
}

# --- Cloud Run Job Support Resources ---
# Service account and Artifact Registry for bootstrap job

resource "google_service_account" "bootstrap_sa" {
  count        = var.enable_cloud_run_job ? 1 : 0
  account_id   = "cs-bootstrap-${var.environment}"
  display_name = "Service Account for Bootstrap Job (${var.environment})"
  project      = var.gcp_project_id
}

resource "google_artifact_registry_repository" "bootstrap_repo" {
  count         = var.enable_cloud_run_job ? 1 : 0
  location      = var.gcp_region
  repository_id = "cs-bootstrap-${var.environment}-repo"
  description   = "Docker repository for Creative Studio bootstrap images (${var.environment})"
  format        = "DOCKER"
  project       = var.gcp_project_id
}

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

# Grant bootstrap job SA permission to create/upload objects to GCS bucket
# This is needed for seed_vto_assets and seed_media_templates functions
resource "google_storage_bucket_iam_member" "bootstrap_sa_gcs_object_creator" {
  count  = var.enable_cloud_run_job ? 1 : 0
  bucket = google_storage_bucket.genmedia.name
  role   = "roles/storage.objectCreator"
  member = google_service_account.bootstrap_sa[0].member
}

# NOTE: Cloud Run Job is NOT created via Terraform module
# Instead, it's created and managed by the Cloud Build trigger
# The trigger (cloudbuild-bootstrap.yaml) creates the job definition on first run
# This approach allows the job to be updated independently via Cloud Build
# without Terraform needing to know about the job's existence

# --- Cloud Build Trigger for Bootstrap Job ---
# Automatically executes bootstrap job when backend/bootstrap/** files change
# Only created when enable_cloud_build = true

resource "google_service_account" "bootstrap_trigger_sa" {
  count        = (var.enable_cloud_build && var.enable_cloud_run_job) ? 1 : 0
  account_id   = "cs-bootstrap-trig-${var.environment}"
  display_name = "Cloud Build Trigger Service Account for Bootstrap (${var.environment})"
  project      = var.gcp_project_id
}

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

# Grant bootstrap trigger SA permission to impersonate the bootstrap job service account
# This is needed for Cloud Build to create the Cloud Run Job with the specified service account
# and to pass the job SA when executing the job
resource "google_service_account_iam_member" "bootstrap_trigger_can_impersonate_job_sa" {
  count              = (var.enable_cloud_build && var.enable_cloud_run_job) ? 1 : 0
  service_account_id = google_service_account.bootstrap_sa[0].name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.bootstrap_trigger_sa[0].member
}


# --- Cross-Module Permissions ---

# Grant the Frontend's deploy trigger (which runs `firebase deploy`)
# permission to "get" the Backend's Cloud Run service to validate the rewrite rule.
resource "google_cloud_run_v2_service_iam_member" "fe_trigger_can_view_backend" {
  count    = var.enable_cloud_build ? 1 : 0
  provider = google-beta
  project  = var.gcp_project_id
  name     = module.backend_service.service_name
  location = module.backend_service.location
  role     = "roles/run.viewer"
  member   = module.frontend_service.trigger_sa_member

  # Wait for all backend service resources to be fully created and IAM policies stabilized
  # This prevents ETag conflicts from concurrent policy modifications
  depends_on = [
    module.backend_service,
    google_secret_manager_secret_iam_member.backend_runtime_secret_accessor
  ]
}
