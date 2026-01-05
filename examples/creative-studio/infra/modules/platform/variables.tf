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

# Backend specific variables
variable "be_env_vars" {
  type        = map(string)
  description = "Backend environment variables (flat map of key-value pairs). Each directory handles one environment, so no nesting needed."
}

variable "backend_runtime_secrets" {
  type        = map(string)
  description = "Maps environment variable names to Secret Manager secret names for the backend Cloud Run service at runtime."
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

variable "require_approval_for_deploy" {
  type        = bool
  description = "Require manual approval before Cloud Build deployments. When true, Cloud Build triggers require explicit approval before deployment (recommended for production environments to prevent accidental deployments)."
  default     = false
}

# Bootstrap Job Configuration
variable "bootstrap_admin_user_email" {
  type        = string
  nullable    = true
  default     = null
  description = "Email address for the initial admin user. REQUIRED for database bootstrap initialization. Set to null to disable bootstrap (dev-only)."
}

variable "cloud_sql_public_ip_enabled" {
  type        = bool
  description = "Whether the Cloud SQL instance should have a public IP address"
  default     = true
}


variable "enable_identity_platform" {
  type        = bool
  description = "Whether to enable Firebase Identity Platform for user authentication. Independent of Cloud Build - can be enabled/disabled separately for authentication-only deployments."
  default     = true
}

# Destruction Control
variable "allow_destroy" {
  type        = bool
  description = "Allow Terraform to destroy critical resources (storage bucket, Cloud SQL database). Set to true for development/test environments only. Production should always be false. Note: Firestore deletion protection is automatically enabled when allow_destroy = false."
  default     = false
}

# Storage Configuration

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
    List of identities that are granted Cloud Run invoker (roles/run.invoker) permission to invoke the backend service.
    Only explicitly listed identities can call this service - allUsers access is never granted.

    Format examples:
    - "user:john@example.com"
    - "group:developers@example.com"
    - "serviceAccount:my-sa@project.iam.gserviceaccount.com"

    Leave empty [] to keep the backend service private (no invoker permissions granted).

    Note: Identity Platform authentication is controlled separately via identity_platform_* variables.
  EOT
  default     = []
}

# --- Cloud Run Job Configuration (Database Bootstrap) ---
# Cloud Run Job handles database initialization (migrations, seeding, asset creation)
# Connects to private Cloud SQL via VPC Connector
# Triggered via Cloud Build on code push to bootstrap files

