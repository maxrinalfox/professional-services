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
  description = "The GCP project ID"
}

variable "gcp_region" {
  type        = string
  description = "The GCP region"
}

variable "environment" {
  type        = string
  description = "The deployment environment (development or production)."
}

variable "enable_cloud_build" {
  type        = bool
  description = "Whether to enable Cloud Build for bootstrap"
  default     = true
}

variable "enable_cloud_run_job" {
  type        = bool
  description = "Whether to enable Cloud Run Job for bootstrap"
  default     = true
}

variable "genmedia_bucket_name" {
  type        = string
  description = "Name of the GenMedia storage bucket (from storage module output)"
}

variable "bootstrap_job_secrets" {
  type = map(object({
    secret_id = string
  }))
  description = "Secrets from Secret Manager to inject into Cloud Run Job"
  default     = {}
}

# Cloud Build trigger configuration
variable "source_repository_id" {
  type        = string
  description = "Cloud Build V2 source repository ID"
  nullable    = true
  default     = null
}

variable "github_branch_name" {
  type        = string
  description = "GitHub branch name for Cloud Build trigger"
}

variable "bootstrap_image_name" {
  type        = string
  description = "Name of the bootstrap Docker image"
}

# VPC Connector Configuration - Auto-computed from networking module
# Both of these values are auto-generated and passed through the platform module
# Do NOT customize these - they are derived from the VPC network configuration
variable "vpc_connector_name" {
  type        = string
  description = "VPC connector name (auto-computed from networking module). Used in Cloud Build substitutions for bootstrap job deployment."
  default     = ""
}

variable "vpc_connector_id" {
  type        = string
  description = "VPC connector full resource path (auto-computed from networking module). Used for Cloud Run VPC access configuration."
  default     = ""
}

variable "cloud_sql_connection_name" {
  type        = string
  description = "Cloud SQL instance connection name"
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
  default     = 3600
}

variable "bootstrap_admin_user_email" {
  type        = string
  nullable    = false
  description = "Email address for the initial admin user to create during bootstrap. REQUIRED when bootstrap job is enabled."
}

variable "firestore_database_name" {
  type        = string
  description = "Firestore database name (auto-computed from environment, e.g., 'cstudio-development')"
}

variable "require_approval_for_deploy" {
  type        = bool
  description = "Require manual approval before Cloud Build deployments (recommended for production environments to prevent accidental deployments)"
  default     = false
}
