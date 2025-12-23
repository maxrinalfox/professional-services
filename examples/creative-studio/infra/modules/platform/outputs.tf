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

# modules/platform/outputs.tf

output "backend_service_url" {
  description = "The URL of the deployed backend service."
  value       = try(module.backend_service[0].service_url, null)
}

output "frontend_service_url" {
  description = "The URL of the deployed frontend service."
  value       = try(module.frontend_service[0].url, null)
}

output "cloud_sql_connection_name" {
  description = "The connection name of the Cloud SQL instance to be used by the bootstrap script."
  value       = module.postgresql.connection_name
}

output "vpc_network_id" {
  description = "VPC network ID (if VPC is enabled)"
  value       = try(module.vpc_network[0].network_id, null)
}

output "vpc_connector_id" {
  description = "VPC Connector ID for Cloud Run (if VPC is enabled)"
  value       = try(module.vpc_network[0].vpc_connector_id, null)
}

output "vpc_connector_name" {
  description = "VPC Connector name for Cloud Run (if VPC is enabled)"
  value       = try(module.vpc_network[0].vpc_connector_name, null)
}

# --- Identity Platform Outputs (Phase 3) ---
output "identity_platform_config_created" {
  description = "Whether Identity Platform configuration was created (true if enable_cloud_build=true)"
  value       = var.enable_cloud_build ? true : false
}

output "firebase_project_id" {
  description = "The Firebase Project ID (same as GCP Project ID)"
  value       = var.enable_cloud_build ? var.gcp_project_id : null
}

output "identity_platform_auth_domain" {
  description = "The Firebase Auth domain for authentication (predictable format)"
  value       = var.enable_cloud_build ? "${var.gcp_project_id}.firebaseapp.com" : null
}

# --- Cloud Run Job (Bootstrap) Outputs ---

output "bootstrap_job_name" {
  description = "Name of the Cloud Run Job for database bootstrap"
  value       = var.enable_cloud_run_job ? module.cloud_run_job_bootstrap[0].job_name : null
}

output "bootstrap_job_id" {
  description = "ID of the Cloud Run Job for database bootstrap"
  value       = var.enable_cloud_run_job ? module.cloud_run_job_bootstrap[0].job_id : null
}

output "bootstrap_service_account_email" {
  description = "Email of the service account used by the bootstrap job"
  value       = var.enable_cloud_run_job ? google_service_account.bootstrap_sa[0].email : null
}

output "bootstrap_artifact_repository" {
  description = "Name of the Artifact Registry repository for bootstrap images"
  value       = var.enable_cloud_run_job ? google_artifact_registry_repository.bootstrap_repo[0].repository_id : null
}

output "bootstrap_trigger_name" {
  description = "Name of the Cloud Build trigger for bootstrap job"
  value       = (var.enable_cloud_build && var.enable_cloud_run_job) ? google_cloudbuild_trigger.bootstrap[0].name : null
}
