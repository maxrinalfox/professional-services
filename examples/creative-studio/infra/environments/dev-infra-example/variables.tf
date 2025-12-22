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

variable "gcp_project_id" {
  type        = string
  description = "The GCP Project ID for the development environment."
}

variable "gcp_region" {
  type        = string
  description = "The GCP region for the development environment."
}

variable "environment" {
  type        = string
  description = "The name of the environment, e.g., 'development'."
}

# --- Service Names ---
variable "backend_service_name" {
  type        = string
  description = "The full name of the backend Cloud Run service for this environment."
}

variable "frontend_service_name" {
  type        = string
  description = "The full name of the frontend Cloud Run service for this environment."
}

# --- GitHub Repo Details ---
variable "github_conn_name" {
  type        = string
  description = "The name of the Cloud Build GitHub connection."
}

variable "github_repo_owner" {
  type        = string
  description = "The owner of the GitHub repository."
}

variable "github_repo_name" {
  type        = string
  description = "The name of the GitHub repository."
}

variable "github_branch_name" {
  type        = string
  description = "The branch name to trigger builds from."
}

# --- Custom Audiences ---
variable "backend_custom_audiences" {
  type        = list(string)
  description = "List of custom audiences for the backend service."
}

variable "frontend_custom_audiences" {
  type        = list(string)
  description = "List of custom audiences for the frontend service."
}

# --- Service-Specific Environment Variables ---
variable "be_env_vars" {
  type        = map(string)
  description = "Backend environment variables (flat map of key-value pairs). Each directory handles one environment, so no nesting needed."
}

variable "be_build_substitutions" {
  type        = map(string)
  description = "A map of substitution variables for the backend Cloud Build trigger."
  default     = {}
}

variable "fe_build_substitutions" {
  type        = map(string)
  description = "A map of substitution variables for the frontend Cloud Build trigger."
  default     = {}
}

variable "frontend_secrets" {
  type        = list(string)
  description = "A list of secret names required by the frontend build."
  default = []
}

variable "backend_secrets" {
  type        = list(string)
  description = "A list of secret names required by the backend build."
  default = []
}

variable "backend_runtime_secrets" {
  type        = map(string)
  description = "Secrets to mount in the backend container at runtime."
}

variable "be_cpu" {
  type        = string
  description = "CPU allocation for backend Cloud Run service (e.g., '2000m' = 2 CPUs)"
  default     = "2000m"
}

variable "be_memory" {
  type        = string
  description = "Memory allocation for backend Cloud Run service (e.g., '2048Mi' = 2 GB)"
  default     = "2048Mi"
}

variable "fe_cpu" {
  type        = string
  description = "CPU allocation for frontend Cloud Run build runner"
  default     = "2000m"
}

variable "fe_memory" {
  type        = string
  description = "Memory allocation for frontend Cloud Run build runner"
  default     = "2048Mi"
}

variable "firebase_web_app_id" {
  type        = string
  nullable    = true
  default     = null
  description = <<-EOT
    The Firebase web app ID to auto-discover SDK configuration.

    Phase 2 Automation (NEW - RECOMMENDED):
    - Leave as null to enable automatic Firebase web app creation via Terraform
    - Terraform will automatically create the web app and discover its configuration
    - No manual Firebase Console steps needed!
    - Reference: https://firebase.google.com/docs/projects/terraform/get-started

    Phase 1 Manual Creation (Legacy):
    - Provide the web app ID if using manually created Firebase web app
    - Format: '1:PROJECT_NUMBER:web:HASH'
    - Find via: gcloud firebase apps list --project=YOUR_PROJECT
  EOT
}

variable "frontend_secrets_additional" {
  type        = list(string)
  description = "Additional secret names (beyond auto-computed Firebase SDK config) required by the frontend build. Firebase SDK secrets (API_KEY, AUTH_DOMAIN, etc.) are automatically discovered."
  default     = ["GOOGLE_CLIENT_ID"]
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

variable "enable_identity_platform" {
  type        = bool
  description = "Whether to enable Firebase Identity Platform for user authentication (independent of Cloud Build)"
  default     = true
}

# --- VPC Network Configuration ---
variable "vpc_enable" {
  type        = bool
  description = "Whether to create and use VPC for private Cloud SQL"
  default     = false
}

variable "vpc_primary_subnet_cidr" {
  type        = string
  description = "Primary subnetwork IP address range for Cloud Run and services"
  default     = "10.0.0.0/24"
}

variable "vpc_connector_subnet_cidr" {
  type        = string
  description = "Subnetwork IP address range for Serverless VPC Connector"
  default     = "10.0.1.0/28"
}

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

