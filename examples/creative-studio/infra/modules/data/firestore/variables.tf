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
  type        = string
  description = "The GCP project ID"
}

variable "gcp_region" {
  type        = string
  description = "The GCP region for Firestore location (e.g., 'us-central1')"
}

variable "database_name" {
  type        = string
  description = "The name of the Firestore database (e.g., 'cstudio-production')"
}

variable "allow_destroy" {
  type        = bool
  description = "Allow Terraform to destroy the Firestore database. Set to true for development/test environments only."
  default     = false
}

variable "deletion_protection_enabled" {
  type        = bool
  description = "Enable deletion protection for Firestore database (strongly recommended for production)"
  default     = false
}
