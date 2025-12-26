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

variable "enable_cloud_build" {
  type        = bool
  description = "Whether to enable Cloud Build and create Firebase web app"
  default     = true
}

variable "enable_identity_platform" {
  type        = bool
  description = "Whether to enable Identity Platform for authentication"
  default     = true
}

variable "firebase_web_app_id" {
  type        = string
  description = "Existing Firebase Web App ID (leave null to auto-create)"
  default     = null
}

variable "api_initialization" {
  type        = any
  description = "Reference to API initialization resource for proper dependency ordering"
}
