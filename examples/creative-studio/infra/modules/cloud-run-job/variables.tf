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

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region for Cloud Run Job"
  type        = string
  default     = "us-central1"
}

variable "job_name" {
  description = "Name of the Cloud Run Job"
  type        = string
}

variable "container_image" {
  description = "Container image URL for the bootstrap job (same as backend service)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+\\.pkg\\.dev/[a-z0-9-]+/[a-z0-9-]+/[a-z0-9-]+:[a-z0-9-]+$", var.container_image))
    error_message = "Container image must be a valid Artifact Registry image path (e.g., region-docker.pkg.dev/project/repo/image:tag)."
  }
}

variable "service_account_email" {
  description = "Service account email to run the job (backend service account recommended)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+@[a-z0-9-]+\\.iam\\.gserviceaccount\\.com$", var.service_account_email))
    error_message = "Service account email must be a valid GCP service account email."
  }
}

variable "vpc_connector_id" {
  description = "VPC Connector ID for private database connectivity (optional)"
  type        = string
  default     = null

  validation {
    condition     = var.vpc_connector_id == null || can(regex("^projects/[a-z0-9-]+/locations/[a-z0-9-]+/connectors/[a-z0-9-]+$", var.vpc_connector_id))
    error_message = "VPC Connector ID must be in format: projects/PROJECT/locations/REGION/connectors/CONNECTOR_NAME."
  }
}

variable "environment_variables" {
  description = "Environment variables to pass to the job"
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for key in keys(var.environment_variables) : can(regex("^[A-Z_][A-Z0-9_]*$", key))])
    error_message = "Environment variable names must be valid (uppercase, alphanumeric, underscores)."
  }
}

variable "secrets" {
  description = "Secret references for the job (secret_id -> version mapping)"
  type = map(object({
    secret_id = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for secret in var.secrets : can(regex("^[a-z0-9-]+$", secret.secret_id))
    ])
    error_message = "Secret IDs must be lowercase alphanumeric with hyphens only."
  }
}

variable "timeout" {
  description = "Job execution timeout in seconds"
  type        = number
  default     = 3600  # 1 hour

  validation {
    condition     = var.timeout >= 60 && var.timeout <= 86400
    error_message = "Timeout must be between 60 seconds (1 min) and 86400 seconds (24 hours)."
  }
}

variable "cpu" {
  description = "CPU allocation for the job (e.g., '1', '2', '4')"
  type        = string
  default     = "2"

  validation {
    condition     = can(regex("^(0\\.25|0\\.5|1|2|4)$", var.cpu))
    error_message = "CPU must be one of: 0.25, 0.5, 1, 2, 4"
  }
}

variable "memory" {
  description = "Memory allocation for the job (e.g., '512Mi', '1Gi', '2Gi', '4Gi')"
  type        = string
  default     = "4Gi"

  validation {
    condition     = can(regex("^[0-9]+(Mi|Gi)$", var.memory))
    error_message = "Memory must be in format: number + unit (Mi or Gi), e.g., '512Mi', '1Gi', '2Gi', '4Gi'"
  }
}
