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

terraform {
  required_providers {
    google      = { source = "hashicorp/google" }
    google-beta = { source = "hashicorp/google-beta" }
  }
}

provider "google" {
  project = local.gcp_project_id
  region  = local.gcp_region
}

provider "google-beta" {
  project               = local.gcp_project_id
  region                = local.gcp_region
  user_project_override = true  # Use resource's project for quota checks (fixes Identity Toolkit quota issues)
}

provider "google-beta" {
  alias                 = "no_user_project_override"
  user_project_override = false
}

# ============================================================================
# ENVIRONMENT CONFIGURATION
# ============================================================================
# Inline values with clear comments. Modify these for your environment.
# For advanced customization or multiple environments, use terraform.auto.tfvars
# ============================================================================

locals {
  # === GCP PROJECT & REGION ===
  gcp_project_id = "YOUR_GCP_PROJECT_ID"  # TODO: Replace with your GCP project ID
  gcp_region     = "us-central1"          # GCP region for all resources

  # === ENVIRONMENT IDENTITY ===
  environment = "development"  # Environment name (used in resource naming)

  # === SERVICE NAMES ===
  backend_service_name  = "cstudio-backend-dev"   # Backend Cloud Run service name
  frontend_service_name = "cstudio-frontend-dev"  # Frontend Cloud Run service name

  # === GITHUB CONFIGURATION ===
  github_conn_name   = "github-connection-name"  # Cloud Build GitHub connection (created manually in GCP Console)
  github_repo_owner  = "your-github-username"    # GitHub org or username
  github_repo_name   = "creative-studio"         # GitHub repository name
  github_branch_name = "main"                    # Branch to trigger builds from

  # === FIREBASE WEB APP ID (for SDK auto-discovery) ===
  # Option 1: Leave as null to let Terraform create Firebase web app automatically
  # Option 2: Provide your manually created Firebase web app ID (format: 1:PROJECT_NUMBER:web:HASH)
  # To find: gcloud firebase apps list --project=YOUR_PROJECT_ID
  firebase_web_app_id = null  # null = auto-create, or provide "1:123456789:web:abc123xyz..."

  # === CUSTOM AUDIENCES (for OAuth validation) ===
  backend_custom_audiences  = []  # Empty = auto-populated with GCP project ID
  frontend_custom_audiences = []  # Empty = auto-populated with GCP project ID

  # === BACKEND ENVIRONMENT VARIABLES ===
  # These are passed to the backend Cloud Run service as environment variables
  # NOTE: FIREBASE_DB must reference a Firestore database created separately
  # (not created by Terraform - must be created manually or via backend setup)
  be_env_vars = {
    LOG_LEVEL                      = "INFO"
    ENVIRONMENT                    = local.environment
    FIREBASE_DB                    = "cstudio-development"  # Must match your Firestore database name
    IDENTITY_PLATFORM_ALLOWED_ORGS = ""
  }

  # === BACKEND RUNTIME SECRETS ===
  # Maps environment variable names to Secret Manager secret names
  backend_runtime_secrets = {
    "GOOGLE_TOKEN_AUDIENCE" = "OAUTH_CLIENT_ID"  # Map env var to unified OAuth secret
  }

  # === CLOUD BUILD SUBSTITUTIONS (Optional) ===
  # Additional build variables if needed beyond defaults
  be_build_substitutions = {}  # Backend build substitutions (optional)
  fe_build_substitutions = {}  # Frontend build substitutions (optional)

  # === CLOUD RUN RESOURCE SIZING ===
  be_cpu    = "2000m"   # Backend CPU (1 vCPU = 1000m)
  be_memory = "2048Mi"  # Backend memory
  fe_cpu    = "2000m"   # Frontend CPU
  fe_memory = "2048Mi"  # Frontend memory

  # === CLOUD BUILD TRIGGERS ===
  enable_cloud_build = true  # Enable CI/CD triggers (recommended: true)

  # === CLOUD SQL DATABASE ===
  cloud_sql_public_ip_enabled = true  # Dev: true (public). Prod: false (VPC only)

  # === FIREBASE IDENTITY PLATFORM ===
  enable_identity_platform = true  # Enable user authentication

  # === DESTRUCTION CONTROL ===
  allow_destroy = true  # Dev: true (allow easy cleanup). Prod: false (prevent accidents)

  # === STORAGE & DATABASE PROTECTION ===
  storage_force_destroy                    = true   # Dev: true (empty and delete bucket). Prod: false
  cloud_sql_deletion_protection_enabled    = false  # Dev: false (allow deletion). Prod: true

  # === VPC NETWORKING (for private Cloud SQL) ===
  vpc_enable                = false            # Dev: false. Prod: true for private database
  vpc_primary_subnet_cidr   = "10.0.0.0/24"   # Primary subnet for Cloud Run
  vpc_connector_subnet_cidr = "10.0.1.0/28"   # Subnet for Serverless VPC Connector

  # === CLOUD RUN ACCESS CONTROL ===
  backend_invoker_identities = []  # Empty = public access. Add "user:email@example.com" to restrict

  # === CLOUD RUN JOB (Database Bootstrap) ===
  enable_cloud_run_job      = false                # Enable database bootstrap job
  bootstrap_job_name        = null                 # auto-generated if null
  bootstrap_image_name      = "cstudio-bootstrap"  # Docker image name in Artifact Registry
  bootstrap_job_env_vars    = {}                   # Bootstrap environment variables
  bootstrap_job_secrets     = {}                   # Bootstrap secrets from Secret Manager
  bootstrap_job_cpu         = "2000m"
  bootstrap_job_memory      = "2048Mi"
  bootstrap_job_timeout     = 600  # seconds

  # === STORAGE CONFIGURATION ===
  storage_cors_allowed_origins = ["*"]  # Dev: "*". Prod: specify exact domains
}

# ============================================================================
# INFRASTRUCTURE DEPLOYMENT
# ============================================================================
# Call the platform module with the configuration above
# ============================================================================

module "creative_studio_platform" {
  source = "../../modules/platform"

  # Project & Environment
  gcp_project_id = local.gcp_project_id
  gcp_region     = local.gcp_region
  environment    = local.environment

  # Services
  backend_service_name  = local.backend_service_name
  frontend_service_name = local.frontend_service_name

  # GitHub
  github_conn_name   = local.github_conn_name
  github_repo_owner  = local.github_repo_owner
  github_repo_name   = local.github_repo_name
  github_branch_name = local.github_branch_name

  # Firebase
  firebase_web_app_id = local.firebase_web_app_id

  # Custom Audiences
  backend_custom_audiences  = local.backend_custom_audiences
  frontend_custom_audiences = local.frontend_custom_audiences

  # Backend Configuration
  be_env_vars             = local.be_env_vars
  backend_runtime_secrets = local.backend_runtime_secrets
  be_build_substitutions = local.be_build_substitutions
  be_cpu                 = local.be_cpu
  be_memory              = local.be_memory

  # Frontend Configuration
  fe_build_substitutions = local.fe_build_substitutions

  # Cloud Build
  enable_cloud_build = local.enable_cloud_build

  # Cloud SQL
  cloud_sql_public_ip_enabled              = local.cloud_sql_public_ip_enabled
  cloud_sql_deletion_protection_enabled    = local.cloud_sql_deletion_protection_enabled

  # Identity Platform
  enable_identity_platform = local.enable_identity_platform

  # Destruction Control
  allow_destroy = local.allow_destroy

  # VPC
  vpc_enable                = local.vpc_enable
  vpc_primary_subnet_cidr   = local.vpc_primary_subnet_cidr
  vpc_connector_subnet_cidr = local.vpc_connector_subnet_cidr

  # Cloud Run Access Control
  backend_invoker_identities = local.backend_invoker_identities

  # Bootstrap Job
  enable_cloud_run_job       = local.enable_cloud_run_job
  bootstrap_job_name         = local.bootstrap_job_name
  bootstrap_image_name       = local.bootstrap_image_name
  bootstrap_job_env_vars     = local.bootstrap_job_env_vars
  bootstrap_job_secrets      = local.bootstrap_job_secrets
  bootstrap_job_cpu          = local.bootstrap_job_cpu
  bootstrap_job_memory       = local.bootstrap_job_memory
  bootstrap_job_timeout      = local.bootstrap_job_timeout

  # Storage
  storage_force_destroy        = local.storage_force_destroy
  storage_cors_allowed_origins = local.storage_cors_allowed_origins
}

# ============================================================================
# MODULE OUTPUTS - Forward all platform module outputs to environment outputs
# ============================================================================

output "module_all" {
  description = "All outputs from the platform module (complete infrastructure state)"
  value       = module.creative_studio_platform
}

output "backend_service_url" {
  description = "Backend Cloud Run service URL"
  value       = module.creative_studio_platform.backend_service_url
}

output "frontend_service_url" {
  description = "Frontend Firebase Hosting URL"
  value       = "https://${local.gcp_project_id}.web.app"
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL connection string for the database"
  value       = module.creative_studio_platform.cloud_sql_connection_name
}

output "secret_population_commands" {
  description = "Helper commands to populate OAUTH_CLIENT_ID secret after terraform apply"
  value       = try(module.creative_studio_platform.app_secrets.secret_population_commands, null)
}

output "infrastructure_ready" {
  description = "Infrastructure deployment summary"
  value = {
    project_id = local.gcp_project_id
    region     = local.gcp_region
    environment = local.environment
    backend_url = module.creative_studio_platform.backend_service_url
    frontend_url = "https://${local.gcp_project_id}.web.app"
    next_steps = "1. Populate OAUTH_CLIENT_ID secret (see secret_population_commands output)\n2. Push code to GitHub to trigger Cloud Build\n3. Monitor builds in GCP Console > Cloud Build"
  }
  sensitive = false
}
