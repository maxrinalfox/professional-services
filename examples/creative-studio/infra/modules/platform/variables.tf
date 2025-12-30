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

variable "gcp_project_id" { type = string }
variable "gcp_region" { type = string }
variable "environment" {
  type        = string
  description = "The deployment environment (development or production)."

  validation {
    condition     = contains(["development", "production"], var.environment)
    error_message = "Environment must be one of: 'development' or 'production'."
  }
}

variable "firebase_db_name" {
  type    = string
  default = "cstudio"
}

variable "firebase_web_app_id" {
  type        = string
  nullable    = true
  default     = null
  description = <<-EOT
    The Firebase web app ID to auto-discover SDK configuration.

    Phase 2 Automation (NEW):
    - Leave as null to enable automatic Firebase web app creation via Terraform
    - Requires: enable_cloud_build = true
    - Terraform will create the web app and auto-discover its configuration
    - Reference: https://firebase.google.com/docs/projects/terraform/get-started

    Phase 1 Manual Creation (Legacy):
    - Provide the web app ID if using manually created Firebase web app
    - Format: '1:PROJECT_NUMBER:web:HASH'
    - Find via: gcloud firebase apps list --project=YOUR_PROJECT
    - This is required when: enable_cloud_build = true AND firebase_web_app_id is provided
  EOT
}

# Backend specific variables
variable "backend_service_name" { type = string }
variable "backend_custom_audiences" { type = list(string) }
variable "be_env_vars" {
  type        = map(string)
  description = "Backend environment variables (flat map of key-value pairs). Each directory handles one environment, so no nesting needed."
}

variable "be_build_substitutions" {
  type        = map(string)
  description = "A map of substitution variables for the backend Cloud Build trigger."
  default     = {}
}

variable "backend_runtime_secrets" {
  type        = map(string)
  description = "Maps environment variable names to Secret Manager secret names for the backend Cloud Run service at runtime."
  default     = {}
}

# Frontend specific variables
variable "frontend_service_name" { type = string }
variable "frontend_custom_audiences" { type = list(string) }

variable "fe_build_substitutions" {
  type        = map(string)
  description = "A map of substitution variables for the frontend Cloud Build trigger."
  default     = {}
}

# Common GitHub variables
variable "github_conn_name" { type = string }
variable "github_repo_owner" { type = string }
variable "github_repo_name" { type = string }
variable "github_branch_name" { type = string }

variable "be_cpu" {
  type    = string
  default = "2000m"
}

variable "be_memory" {
  type    = string
  default = "2048Mi"
}

variable "fe_cpu" {
  type    = string
  default = "2000m"
}

variable "fe_memory" {
  type    = string
  default = "2048Mi"
}


variable "enable_cloud_build" {
  type        = bool
  description = "Whether to create Cloud Build triggers and connections"
  default     = true
}

variable "cloud_sql_public_ip_enabled" {
  type        = bool
  description = "Whether the Cloud SQL instance should have a public IP address"
  default     = true
}

variable "cloud_sql_deletion_protection_enabled" {
  type        = bool
  description = "Enable deletion protection for Cloud SQL instance (strongly recommended for production)"
  default     = false
}

variable "enable_identity_platform" {
  type        = bool
  description = "Whether to enable Firebase Identity Platform for user authentication. Independent of Cloud Build - can be enabled/disabled separately for authentication-only deployments."
  default     = true
}

# Storage Configuration
variable "storage_force_destroy" {
  type        = bool
  description = "Allow Terraform to delete the storage bucket even if it contains objects. Set to true for development environments only."
  default     = false
}

variable "storage_cors_allowed_origins" {
  type        = list(string)
  description = "List of allowed origins for CORS requests. Use [\"*\"] to allow all origins, or specify specific domains for production."
  default     = ["*"]
}

# VPC Configuration
variable "vpc_enable" {
  type        = bool
  description = "Whether to create and use VPC for private Cloud SQL"
  default     = false

  validation {
    condition     = !(var.vpc_enable && var.cloud_sql_public_ip_enabled)
    error_message = "Invalid configuration: vpc_enable = true but cloud_sql_public_ip_enabled = true. When using VPC, Cloud SQL should have private IP only. Set cloud_sql_public_ip_enabled = false."
  }
}

variable "vpc_primary_subnet_cidr" {
  type        = string
  description = "Primary subnetwork IP address range for Cloud Run"
  default     = "10.0.0.0/24"
}

variable "vpc_connector_subnet_cidr" {
  type        = string
  description = "Subnetwork IP address range for Serverless VPC Connector"
  default     = "10.0.1.0/28"
}

# --- Identity Platform Configuration Variables (Phase 3) ---
# Firebase Identity Platform provides authentication services
# Sign-in methods and detailed configuration are managed via GCP Console
# Reference: https://firebase.google.com/docs/projects/terraform/get-started#tf-sample-auth
# Only the OAuth IDP configuration below is managed via Terraform if needed

# --- Cloud Run Access Control ---
variable "backend_invoker_identities" {
  type        = list(string)
  description = <<-EOT
    List of user, group, or service account identities that have Cloud Run invoker (roles/run.invoker) access to the backend service.

    Format examples:
    - "user:john@example.com"
    - "group:developers@example.com"
    - "serviceAccount:my-sa@project.iam.gserviceaccount.com"

    Leave empty to grant invoker access to allUsers (public access).

    Note: Identity Platform authentication is controlled separately via identity_platform_* variables.
  EOT
  default     = []
}

# --- Cloud Run Job Configuration (Database Bootstrap) ---
# Cloud Run Job handles database initialization (migrations, seeding, asset creation)
# Connects to private Cloud SQL via VPC Connector
# Triggered via Cloud Build on code push to bootstrap files

variable "enable_cloud_run_job" {
  type        = bool
  description = "Whether to create and execute Cloud Run Job for database bootstrap"
  default     = false
}

variable "bootstrap_job_name" {
  type        = string
  description = "Name of the Cloud Run Job for database bootstrap"
  nullable    = true
  default     = null
}

variable "bootstrap_image_name" {
  type        = string
  description = "Name of the bootstrap container image in Artifact Registry (without tag or project)"
  default     = "cstudio-bootstrap"
}

variable "bootstrap_job_env_vars" {
  type        = map(string)
  description = "Plain text environment variables for the Cloud Run Job bootstrap container"
  default     = {}
}

variable "bootstrap_job_secrets" {
  type = map(object({
    secret_id = string
  }))
  description = "Secrets from Secret Manager to inject into Cloud Run Job as environment variables"
  default     = {}
}

variable "bootstrap_job_cpu" {
  type        = string
  description = "CPU allocation for bootstrap Cloud Run Job"
  default     = "2000m"
}

variable "bootstrap_job_memory" {
  type        = string
  description = "Memory allocation for bootstrap Cloud Run Job"
  default     = "2048Mi"
}

variable "bootstrap_job_timeout" {
  type        = number
  description = "Timeout in seconds for bootstrap Cloud Run Job"
  default     = 600
}

variable "initial_admin_user_email" {
  type        = string
  description = "Deprecated: include ADMIN_USER_EMAIL in bootstrap_job_environment_variables instead. Email address for the initial admin user to create during bootstrap"
  nullable    = true
  default     = null
}

variable "bootstrap_job_log_level" {
  type        = string
  description = "Deprecated: include LOG_LEVEL in bootstrap_job_environment_variables instead. Log level for bootstrap job (DEBUG, INFO, WARNING, ERROR)"
  nullable    = true
  default     = null
}
