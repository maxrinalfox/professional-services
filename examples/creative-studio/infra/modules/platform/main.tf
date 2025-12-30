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

# ============================================================================
# PLATFORM MODULE - SERVICE ORCHESTRATION LAYER
# ============================================================================
#
# This module orchestrates all infrastructure services:
# - Core infrastructure (APIs, storage, Firebase, networking)
# - Data layer (PostgreSQL database)
# - Application services (backend, frontend)
# - Bootstrap automation
#
# Each sub-module is designed to be independent and reusable while
# this layer handles the coordination and cross-module dependencies.
# ============================================================================

# --- ENABLE REQUIRED GOOGLE CLOUD APIs ---
# --- BOOTSTRAP JOB LOGIC ---
# The bootstrap job is automatically enabled based on infrastructure needs:
# - Always enabled if cloud_build is enabled (useful for any deployment)
# - Cloud Run Job for database initialization is essential when:
#   * VPC is enabled (DB is private, needs secure access through VPC connector)
#   * DB has public IP (bootstrap job can run in Cloud Run with public IP access)
locals {
  # Compute whether bootstrap job should be enabled
  # If enable_cloud_build is true, we likely want bootstrap job for DB initialization
  # The job is always useful: handles migrations, seeding, asset uploads
  enable_cloud_run_job_computed = var.enable_cloud_build

  required_apis = [
    # ========== FIREBASE CORE APIs ==========
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "identitytoolkit.googleapis.com",
    "cloudresourcemanager.googleapis.com",

    # ========== CORE INFRASTRUCTURE APIs ==========
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",

    # ========== CLOUD BUILD & DEPLOYMENT APIs ==========
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",

    # ========== CLOUD RUN APIs ==========
    "run.googleapis.com",

    # ========== NETWORKING & VPC APIs ==========
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "vpcaccess.googleapis.com",

    # ========== DATABASE APIs ==========
    "sqladmin.googleapis.com",

    # ========== DATA & STORAGE APIs ==========
    "firestore.googleapis.com",
    "cloudfunctions.googleapis.com",
    "aiplatform.googleapis.com",
    "texttospeech.googleapis.com",

    # ========== SECRETS & SECURITY APIs ==========
    "secretmanager.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = var.gcp_project_id
  service            = each.key
  disable_on_destroy = false
}

# API Initialization Delay
resource "time_sleep" "api_initialization" {
  create_duration = "10s"
  depends_on = [
    google_project_service.apis
  ]
}

# --- PROJECT DATA ---
data "google_project" "project" {
  project_id = var.gcp_project_id
}

# --- DATABASE PASSWORD SECRETS ---
resource "random_password" "db_password" {
  length  = 32
  special = true
}

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

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

# --- CLOUD BUILD REPOSITORY CONNECTION ---
resource "google_cloudbuildv2_repository" "source_repo" {
  count             = var.enable_cloud_build ? 1 : 0
  provider          = google-beta
  name              = var.github_repo_name
  location          = var.gcp_region
  parent_connection = "projects/${var.gcp_project_id}/locations/${var.gcp_region}/connections/${var.github_conn_name}"
  remote_uri        = "https://github.com/${var.github_repo_owner}/${var.github_repo_name}.git"
}

# --- COMPUTED LOCALS ---
locals {
  region_code = join("", [for s in split("-", var.gcp_region) : substr(s, 0, 1)])
  backend_url = "https://${var.backend_service_name}-${data.google_project.project.number}.${var.gcp_region}.run.app"
  frontend_url = "https://${var.gcp_project_id}.web.app"

  # Auto-computed Firebase SDK configuration
  firebase_sdk_config = length(module.firebase.firebase_web_app_config) > 0 ? {
    FIREBASE_API_KEY             = module.firebase.firebase_web_app_config[0].api_key
    FIREBASE_AUTH_DOMAIN         = module.firebase.firebase_web_app_config[0].auth_domain
    FIREBASE_PROJECT_ID          = module.firebase.firebase_web_app_config[0].project
    FIREBASE_STORAGE_BUCKET      = module.firebase.firebase_web_app_config[0].storage_bucket
    FIREBASE_MESSAGING_SENDER_ID = module.firebase.firebase_web_app_config[0].messaging_sender_id
    FIREBASE_MEASUREMENT_ID      = module.firebase.firebase_web_app_config[0].measurement_id
  } : {}

  frontend_secrets_auto = keys(local.firebase_sdk_config)

  backend_custom_audiences_computed = compact(concat(
    [var.gcp_project_id],
    var.backend_custom_audiences
  ))

  frontend_custom_audiences_computed = compact(concat(
    [var.gcp_project_id],
    var.frontend_custom_audiences
  ))

  backend_env_vars = merge(
    var.be_env_vars,
    {
      "CORS_ORIGINS"     = "[\"${local.frontend_url}\"]"
      "GENMEDIA_BUCKET"  = module.storage.bucket_name
      "SIGNING_SA_EMAIL" = module.storage.bucket_writer_sa_email
    }
  )

  source_repository_id = var.enable_cloud_build ? google_cloudbuildv2_repository.source_repo[0].id : ""
}

# --- CORE INFRASTRUCTURE ---

module "firebase" {
  source = "../core/firebase"

  gcp_project_id             = var.gcp_project_id
  enable_cloud_build         = var.enable_cloud_build
  enable_identity_platform   = var.enable_identity_platform
  firebase_web_app_id        = var.firebase_web_app_id
  api_initialization         = time_sleep.api_initialization
}

module "storage" {
  source = "../core/storage"

  gcp_project_id           = var.gcp_project_id
  gcp_region               = var.gcp_region
  environment              = var.environment
  force_destroy            = var.storage_force_destroy
  cors_allowed_origins     = var.storage_cors_allowed_origins

  depends_on = [google_project_service.apis]
}

# --- DATA LAYER ---

# PostgreSQL Database
module "postgresql" {
  source     = "../data/postgresql"
  project_id = var.gcp_project_id
  gcp_region = var.gcp_region

  # Pass the generated password
  db_password = google_secret_manager_secret_version.db_password.secret_data

  # Control whether the instance has a public IP
  public_ip_enabled = var.cloud_sql_public_ip_enabled

  # Deletion protection
  deletion_protection_enabled = var.cloud_sql_deletion_protection_enabled

  # Private network configuration (always pass, will be null if vpc_enable=false)
  vpc_network_id = var.vpc_enable ? module.vpc_network[0].network_id : null

  depends_on = [
    google_project_service.apis,
    module.vpc_network,
  ]
}

# --- NETWORKING ---

module "vpc_network" {
  count                 = var.vpc_enable ? 1 : 0
  source                = "../networking"
  project_id            = var.gcp_project_id
  gcp_region            = var.gcp_region
  name                  = "cs-${var.environment}"
  primary_subnet_cidr   = var.vpc_primary_subnet_cidr
  connector_subnet_cidr = var.vpc_connector_subnet_cidr

  depends_on = [google_project_service.apis]
}

# --- APPLICATION SERVICES ---

module "backend_service" {
  source = "../services/backend"

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

  container_env_vars = merge(
    local.backend_env_vars,
    {
      "USE_CLOUD_SQL_PRIVATE_IP" = var.cloud_sql_public_ip_enabled ? "false" : "true"
    }
  )

  runtime_secrets       = var.backend_runtime_secrets
  custom_audiences      = local.backend_custom_audiences_computed
  scaling_min_instances = 1
  source_repository_id  = local.source_repository_id
  cpu                   = var.be_cpu
  memory                = var.be_memory

  build_substitutions = merge(var.be_build_substitutions, {
    _REGION       = var.gcp_region
    _SERVICE_NAME = var.backend_service_name
  })

  # VPC configuration
  vpc_connector_id = var.vpc_enable ? module.vpc_network[0].vpc_connector_id : null

  # Database
  cloud_sql_connection_name = module.postgresql.connection_name
  db_name                   = module.postgresql.db_name
  db_user                   = module.postgresql.db_user
  db_secret_id              = google_secret_manager_secret.db_password.secret_id

  # Cloud Run access control
  invoker_identities = var.backend_invoker_identities

  # Cloud Build trigger
  enable_cloud_build_trigger = var.enable_cloud_build

  depends_on = [
    google_project_service.apis
  ]
}

module "frontend_service" {
  source = "../services/frontend"

  source_repository_id = local.source_repository_id
  gcp_project_id       = var.gcp_project_id
  gcp_region           = var.gcp_region
  firebase_project_id  = module.firebase.firebase_project_id != null ? module.firebase.firebase_project_id : var.gcp_project_id
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
      _BACKEND_URL         = local.backend_url
      _FE_SERVICE_NAME     = var.frontend_service_name
      _BACKEND_SERVICE_ID  = var.backend_service_name
      _FIREBASE_PROJECT_ID = var.gcp_project_id
      _FIREBASE_APP_ID     = var.firebase_web_app_id != null ? var.firebase_web_app_id : (var.enable_cloud_build && length(module.firebase.firebase_web_app_id) > 0 ? module.firebase.firebase_web_app_id : "")

      # Firebase SDK secrets passed directly as substitutions (auto-discovered from Firebase web app)
      # No need to store these in Secret Manager - they're embedded in Cloud Build config
      _FIREBASE_API_KEY             = try(local.firebase_sdk_config["FIREBASE_API_KEY"], "")
      _FIREBASE_AUTH_DOMAIN         = try(local.firebase_sdk_config["FIREBASE_AUTH_DOMAIN"], "")
      _FIREBASE_PROJECT_ID_SDK      = try(local.firebase_sdk_config["FIREBASE_PROJECT_ID"], "")
      _FIREBASE_STORAGE_BUCKET      = try(local.firebase_sdk_config["FIREBASE_STORAGE_BUCKET"], "")
      _FIREBASE_MESSAGING_SENDER_ID = try(local.firebase_sdk_config["FIREBASE_MESSAGING_SENDER_ID"], "")
      _FIREBASE_MEASUREMENT_ID      = try(local.firebase_sdk_config["FIREBASE_MEASUREMENT_ID"], "")
    }
  )

  enable_cloud_build_trigger = var.enable_cloud_build

  depends_on = [
    google_project_service.apis,
    module.firebase
  ]
}

# --- SECRETS MANAGEMENT ---
# Centralized secret creation and permission management
# All application secrets are created here and permissions are granted to the appropriate service accounts
# This is defined AFTER the service modules so we can reference their service account members
module "app_secrets" {
  source = "../core/secrets"

  gcp_project_id = var.gcp_project_id

  # Secrets configuration with their accessors
  # Structure: secret_name -> { description, accessors: [list of service account members] }
  secrets_config = {
    # Unified OAuth credential used by both frontend and backend
    "OAUTH_CLIENT_ID" = {
      description = "Unified OAuth 2.0 Client ID for frontend and backend authentication"
      accessors = [
        # Frontend Cloud Build needs access to inject into build
        module.frontend_service.trigger_sa_member,
        # Backend Cloud Build needs access to validate during build
        module.backend_service.trigger_sa_member,
        # Backend Cloud Run needs access to read at runtime
        module.backend_service.run_sa_member,
      ]
    }
  }

  depends_on = [
    google_project_service.apis,
    module.frontend_service,
    module.backend_service
  ]
}

# --- BOOTSTRAP INFRASTRUCTURE ---

module "bootstrap" {
  source = "../bootstrap"

  gcp_project_id   = var.gcp_project_id
  gcp_region       = var.gcp_region
  environment      = var.environment
  enable_cloud_build = var.enable_cloud_build
  enable_cloud_run_job = local.enable_cloud_run_job_computed

  genmedia_bucket_name = module.storage.bucket_name
  bootstrap_job_secrets = var.bootstrap_job_secrets

  # Cloud Build trigger config
  source_repository_id = local.source_repository_id
  github_branch_name = var.github_branch_name
  bootstrap_job_name = var.bootstrap_job_name
  bootstrap_image_name = var.bootstrap_image_name
  vpc_connector_name = var.vpc_enable ? (length(module.vpc_network) > 0 ? module.vpc_network[0].vpc_connector_name : "") : ""
  vpc_connector_id = var.vpc_enable ? (length(module.vpc_network) > 0 ? module.vpc_network[0].vpc_connector_id : "") : ""
  cloud_sql_connection_name = module.postgresql.connection_name
  bootstrap_job_cpu = var.bootstrap_job_cpu
  bootstrap_job_memory = var.bootstrap_job_memory
  bootstrap_job_timeout = var.bootstrap_job_timeout
  bootstrap_job_env_vars = merge(
    var.bootstrap_job_env_vars,
    {
      "GENMEDIA_BUCKET" = module.storage.bucket_name
    }
  )

  depends_on = [
    module.postgresql,
    module.vpc_network,
    module.storage
  ]
}

# --- CROSS-MODULE PERMISSIONS ---

# Grant the Frontend's deploy trigger permission to view the Backend
resource "google_cloud_run_v2_service_iam_member" "fe_trigger_can_view_backend" {
  count    = var.enable_cloud_build ? 1 : 0
  provider = google-beta
  project  = var.gcp_project_id
  name     = module.backend_service.service_name
  location = module.backend_service.location
  role     = "roles/run.viewer"
  member   = module.frontend_service.trigger_sa_member

  depends_on = [
    module.backend_service.service_iam_done,
    module.frontend_service
  ]
}

# --- ADDITIONAL CROSS-MODULE BINDINGS ---

# Grant backend service account to Genmedia bucket
resource "google_storage_bucket_iam_member" "backend_sa_gcs_object_creator" {
  bucket = module.storage.bucket_name
  role   = "roles/storage.objectCreator"
  member = module.backend_service.run_sa_member

  depends_on = [
    module.storage,
    module.backend_service
  ]
}

# Grant bucket reader SA to backend Cloud Run
resource "google_project_iam_member" "backend_run_sa_bucket_reader" {
  project = var.gcp_project_id
  role    = "roles/storage.objectViewer"
  member  = module.backend_service.run_sa_member

  depends_on = [module.backend_service]
}
