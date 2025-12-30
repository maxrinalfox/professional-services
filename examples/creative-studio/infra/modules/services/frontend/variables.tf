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
variable "gcp_region" {type = string}
variable "firebase_project_id" { type = string }
variable "service_name" { type = string }
variable "trigger_name" {
  type = string
  description = "Name for the Cloud Build trigger (separate from service_name for Firebase Hosting site_id)"
  nullable = true
  default = null
}
variable "environment" {
  type        = string
  description = "The deployment environment (development, production, or sandbox)."

  validation {
    condition     = contains(["development", "production", "sandbox"], var.environment)
    error_message = "Environment must be one of: 'development', 'production', or 'sandbox'."
  }
}
variable "resource_prefix" { type = string }
variable "source_repository_id" {
  type = string
  nullable = true
  default = null
}
variable "github_branch_name" { type = string }
variable "cloudbuild_yaml_path" { type = string }
variable "included_files_glob" { type = list(string) }
variable "build_substitutions" { type = map(string) }
variable "enable_cloud_build_trigger" {
  type = bool
  description = "Whether to create a Cloud Build trigger for Firebase Hosting deployments"
  default = true
}

