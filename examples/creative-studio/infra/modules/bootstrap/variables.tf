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
  description = "The deployment environment (development, production, or sandbox)."

  validation {
    condition     = contains(["development", "production", "sandbox"], var.environment)
    error_message = "Environment must be one of: 'development', 'production', or 'sandbox'."
  }
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
  description = "Name of the GenMedia storage bucket"
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

variable "bootstrap_job_name" {
  type        = string
  description = "Name for the bootstrap Cloud Run Job"
  nullable    = true
  default     = null
}

variable "bootstrap_image_name" {
  type        = string
  description = "Name of the bootstrap Docker image"
}

variable "vpc_connector_name" {
  type        = string
  description = "VPC connector name for private Cloud SQL access"
  default     = ""
}

variable "vpc_connector_id" {
  type        = string
  description = "VPC connector ID (full resource path) for private Cloud SQL access"
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

variable "initial_admin_user_email" {
  type        = string
  description = "Email of the initial admin user for bootstrap (deprecated: include in bootstrap_job_environment_variables[ADMIN_USER_EMAIL] instead)"
  nullable    = true
  default     = null
}

variable "bootstrap_job_environment_variables" {
  type        = map(string)
  description = "Additional environment variables for bootstrap job"
  default     = {}
}
