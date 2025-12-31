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

  validation {
    condition     = contains(["development", "production"], var.environment)
    error_message = "Environment must be one of: 'development' or 'production'."
  }
}

variable "storage_allow_destroy" {
  type        = bool
  description = "Allow Terraform to destroy the storage bucket and delete its contents. Set to true for development/test environments only. Production should use false."
  default     = false
}

variable "storage_cors_allowed_origins" {
  type        = list(string)
  description = "List of allowed origins for CORS requests. Use [\"*\"] to allow all origins, or specify specific domains for production."
  default     = ["*"]
}
