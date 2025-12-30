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
  description = "The GCP Project ID."
}

variable "gcp_region" {
  type        = string
  description = "The GCP region for the resources."
}

variable "environment" {
  type        = string
  description = "The deployment environment (development or production)."

  validation {
    condition     = contains(["development", "production"], var.environment)
    error_message = "Environment must be one of: 'development' or 'production'."
  }
}

variable "service_name" {
  type        = string
  description = "The full name of the Cloud Run service."
}

variable "resource_prefix" {
  type        = string
  description = "A short prefix for resource names."
}

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

variable "cloudbuild_yaml_path" {
  type        = string
  description = "The path to the cloudbuild.yaml file."
}

variable "included_files_glob" {
  type        = list(string)
  description = "A list of glob patterns for files that should trigger the build."
}

variable "container_env_vars" {
  type        = map(string)
  description = "A map of environment variables for the Cloud Run container."
  default     = {}
}

variable "build_substitutions" {
  type        = map(string)
  description = "A map of substitution variables for the Cloud Build trigger."
  default     = {}
}

variable "custom_audiences" {
  type        = list(string)
  description = "List of custom audiences for the Cloud Run service."
  default     = []
}

variable "scaling_min_instances" {
  type        = number
  description = "Minimum number of container instances."
  default     = 0
}

variable "scaling_max_instances" {
  type        = number
  description = "Maximum number of container instances."
  default     = 100
}

variable "source_repository_id" {
  type        = string
  description = "The ID of the Cloud Build V2 source repository."
  nullable    = true
  default     = null
}

variable "enable_cloud_build_trigger" {
  type        = bool
  description = "Whether to create a Cloud Build trigger for automatic deployments. When false, the Cloud Run service is still created but no automatic deployments are configured."
  default     = true
}

variable "cpu" {
  type = string
  default = "2000m"
}

variable "memory" {
  type = string
  default = "2048Mi"
}

variable "runtime_secrets" {
  type        = map(string)
  description = "A map of ENV_VAR_NAME = SECRET_NAME to mount at runtime."
  default     = {}
}

# VPC and Networking
variable "vpc_connector_id" {
  description = "VPC Connector ID (full resource path) for Cloud Run to access private Cloud SQL"
  type        = string
  nullable    = true
  default     = null
}

# database
variable "cloud_sql_connection_name" {
  description = "Cloud SQL Instance Connection Name"
  type        = string
}
variable "db_secret_id" {
  description = "Secret Manager Secret ID for DB Password"
  type        = string
}
variable "db_name" { type = string }
variable "db_user" { type = string }

# --- Cloud Run Access Control ---
variable "invoker_identities" {
  type        = list(string)
  description = <<-EOT
    List of user, group, or service account identities that have Cloud Run invoker (roles/run.invoker) access.

    Format examples:
    - "user:john@example.com"
    - "group:developers@example.com"
    - "serviceAccount:my-sa@project.iam.gserviceaccount.com"

    Leave empty to grant invoker access to allUsers (public access).
  EOT
  default     = []
}

