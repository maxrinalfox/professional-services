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

  # --- Core Configuration ---
  gcp_project_id  = var.gcp_project_id
  gcp_region      = var.gcp_region
  environment     = var.environment

  # --- Service Configuration ---
  backend_service_name      = var.backend_service_name
  backend_custom_audiences  = var.backend_custom_audiences
  frontend_service_name     = var.frontend_service_name
  frontend_custom_audiences = var.frontend_custom_audiences

  # --- GitHub Configuration ---
  github_conn_name   = var.github_conn_name
  github_repo_owner  = var.github_repo_owner
  github_repo_name   = var.github_repo_name
  github_branch_name = var.github_branch_name

  # --- Environment Variables & Secrets ---
  be_env_vars                = var.be_env_vars
  be_build_substitutions     = var.be_build_substitutions
  fe_build_substitutions     = var.fe_build_substitutions
  frontend_secrets           = var.frontend_secrets
  frontend_secrets_additional = var.frontend_secrets_additional
  backend_secrets            = var.backend_secrets
  backend_runtime_secrets    = var.backend_runtime_secrets

  # --- Firebase Configuration ---
  firebase_web_app_id = var.firebase_web_app_id

  # --- Cloud Run Resource Sizing ---
  be_cpu    = var.be_cpu
  be_memory = var.be_memory
  fe_cpu    = var.fe_cpu
  fe_memory = var.fe_memory

  # --- Cloud Run Access Control ---
  backend_invoker_identities = var.backend_invoker_identities

  # --- VPC Configuration ---
  vpc_enable                = var.vpc_enable
  vpc_primary_subnet_cidr   = var.vpc_primary_subnet_cidr
  vpc_connector_subnet_cidr = var.vpc_connector_subnet_cidr

  # --- Build & Deployment ---
  enable_cloud_build          = var.enable_cloud_build
  cloud_sql_public_ip_enabled = var.cloud_sql_public_ip_enabled
  enable_identity_platform    = var.enable_identity_platform
}
