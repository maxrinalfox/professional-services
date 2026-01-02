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
  value       = try(module.backend_service.service_url, null)
}

output "frontend_service_url" {
  description = "The URL of the deployed frontend service."
  value       = try(module.frontend_service.url, null)
}

output "cloud_sql_connection_name" {
  description = "The connection name of the Cloud SQL instance to be used by the bootstrap script."
  value       = module.postgresql.connection_name
}

output "firestore_database_name" {
  description = "The name of the Firestore database (auto-computed from environment)"
  value       = module.firestore.database_name
}

output "firestore_database_id" {
  description = "The ID of the Firestore database"
  value       = module.firestore.database_id
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
# Note: Cloud Run Job is created by Cloud Build trigger, not by Terraform

output "bootstrap_service_account_email" {
  description = "Email of the service account used by the bootstrap job (only if enable_cloud_run_job=true)"
  value       = try(module.bootstrap.bootstrap_sa_email, null)
}

output "bootstrap_artifact_repository" {
  description = "Name of the Artifact Registry repository for bootstrap images (only if enable_cloud_run_job=true)"
  value       = try(module.bootstrap.bootstrap_repo_name, null)
}

# output "bootstrap_trigger_name" {
#   description = "Name of the Cloud Build trigger for bootstrap job"
#   value       = (var.enable_cloud_build && var.enable_cloud_run_job) ? google_cloudbuild_trigger.bootstrap[0].name : null
# }

# --- POST-APPLY INSTRUCTIONS ---
output "post_apply_instructions" {
  description = "Step-by-step instructions to complete infrastructure setup after terraform apply"
  value = var.enable_cloud_build ? (<<-EOT
POST-APPLY SETUP INSTRUCTIONS
════════════════════════════════

CRITICAL: Complete these steps before triggering Cloud Build

1. CREATE OAUTH 2.0 CLIENT ID
   - Go to: https://console.cloud.google.com/apis/credentials?project=${var.gcp_project_id}
   - Create new OAuth 2.0 Web Application credential
   - Add Authorized Redirect URIs:
     * ${local.frontend_url}
     * http://localhost:3000
     * http://localhost:8080
   - Add Authorized JavaScript Origins:
     * ${local.frontend_url}
     * https://localhost:3000
   - Copy the Client ID

2. STORE OAUTH_CLIENT_ID SECRET (REQUIRED BEFORE BUILDS)
   echo -n "YOUR_OAUTH_CLIENT_ID" | gcloud secrets versions add OAUTH_CLIENT_ID \
     --data-file=- --project=${var.gcp_project_id}

3. TRIGGER CLOUD BUILD PIPELINES
   # Bootstrap database and assets:
   gcloud builds triggers run "cstudio-${var.environment}-bootstrap-trigger" \
     --region="us-central1" --project="${var.gcp_project_id}" --branch="${var.github_branch_name}"

   # Deploy backend service:
   gcloud builds triggers run "cstudio-${var.environment}-backend-trigger" \
     --region="us-central1" --project="${var.gcp_project_id}" --branch="${var.github_branch_name}"

   # Deploy frontend application:
   gcloud builds triggers run "cstudio-${var.environment}-frontend-trigger" \
     --region="us-central1" --project="${var.gcp_project_id}" --branch="${var.github_branch_name}"

4. VERIFY DEPLOYMENT
   - Cloud Build: https://console.cloud.google.com/cloud-build/builds?project=${var.gcp_project_id}
   - Frontend: ${local.frontend_url}
   - Backend: ${local.backend_url}
   - Database: ${local.firestore_database_name}
  EOT
) : "Cloud Build is disabled. Enable it to get post-apply instructions."
}
