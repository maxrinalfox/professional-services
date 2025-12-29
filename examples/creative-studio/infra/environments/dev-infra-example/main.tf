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
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "google-beta" {
  project               = var.gcp_project_id
  region                = var.gcp_region
  user_project_override = true  # Use resource's project for quota checks (fixes Identity Toolkit quota issues)
}

# Provider alias for project-level operations (creating/importing projects)
# Uses default quota project instead of resource's project
provider "google-beta" {
  alias = "no_user_project_override"
  user_project_override = false
}

# --- GCP Project Firebase Label Management ---
# This manages the Firebase label for the existing GCP project.
# The project must already exist in GCP with the Firebase label.
#
# If the Firebase label is not yet applied, you can:
# 1. Apply it manually via GCP Console: Project Settings → Labels
# 2. Or use gcloud: gcloud resource-manager tags bindings create --tag-key=firebase --tag-value=enabled --resource=projects/YOUR_PROJECT_ID
#

# Call the platform module, passing in all the required variables.
# NOTE: The platform module declares and enables all required Google Cloud APIs
module "creative_studio_platform" {
  source = "../../modules/platform"

  gcp_project_id            = var.gcp_project_id
  gcp_region                = var.gcp_region
  environment               = var.environment
  backend_service_name      = var.backend_service_name
  backend_custom_audiences  = var.backend_custom_audiences
  be_env_vars               = var.be_env_vars
  frontend_service_name     = var.frontend_service_name
  frontend_custom_audiences = var.frontend_custom_audiences
  github_conn_name          = var.github_conn_name
  github_repo_owner         = var.github_repo_owner
  github_repo_name          = var.github_repo_name
  github_branch_name        = var.github_branch_name

  # Firebase web app ID for auto-discovering SDK configuration
  # Find via: gcloud firebase apps list --project=YOUR_PROJECT
  firebase_web_app_id = var.firebase_web_app_id

  # Frontend secrets: Firebase SDK values are now auto-discovered from Firebase web app config
  # Only specify additional secrets needed beyond the standard Firebase SDK config
  frontend_secrets            = var.frontend_secrets
  frontend_secrets_additional = var.frontend_secrets_additional
  backend_secrets             = var.backend_secrets
  backend_runtime_secrets     = var.backend_runtime_secrets
  be_build_substitutions      = var.be_build_substitutions
  fe_build_substitutions      = var.fe_build_substitutions

  # Cloud Run resource sizing
  be_cpu    = var.be_cpu
  be_memory = var.be_memory
  fe_cpu    = var.fe_cpu
  fe_memory = var.fe_memory

  # Cloud Build and Cloud SQL configuration
  enable_cloud_build           = var.enable_cloud_build
  cloud_sql_public_ip_enabled  = var.cloud_sql_public_ip_enabled
  enable_identity_platform     = var.enable_identity_platform

  # VPC Network configuration for private Cloud SQL
  vpc_enable                = var.vpc_enable
  vpc_primary_subnet_cidr   = var.vpc_primary_subnet_cidr
  vpc_connector_subnet_cidr = var.vpc_connector_subnet_cidr

  # Cloud Run Access Control
  backend_invoker_identities = var.backend_invoker_identities

  # Cloud Run Job Configuration (Database Bootstrap)
  enable_cloud_run_job                = var.enable_cloud_run_job
  bootstrap_job_name                  = var.bootstrap_job_name
  bootstrap_image_name                = var.bootstrap_image_name
  bootstrap_job_environment_variables = var.bootstrap_job_environment_variables
  bootstrap_job_secrets               = var.bootstrap_job_secrets
  bootstrap_job_cpu                   = var.bootstrap_job_cpu
  bootstrap_job_memory                = var.bootstrap_job_memory
  bootstrap_job_timeout               = var.bootstrap_job_timeout
}
