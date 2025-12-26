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

# Cloud Build trigger for bootstrap job
# Manages the complete lifecycle of the Cloud Run Job:
# - Creates the job on first run with all configuration (env vars, VPC, resources)
# - Updates the job with new image and refreshed environment variables on subsequent runs
# - Executes the job after creation/update
# Triggers on push to configured branch when backend/bootstrap/** files change
resource "google_cloudbuild_trigger" "bootstrap" {
  count           = (var.enable_cloud_build && var.enable_cloud_run_job) ? 1 : 0
  name            = "cstudio-bootstrap-trigger"
  location        = var.gcp_region
  service_account = google_service_account.bootstrap_trigger_sa[0].id
  filename        = "examples/creative-studio/backend/cloudbuild-bootstrap.yaml"
  project         = var.gcp_project_id

  repository_event_config {
    repository = var.source_repository_id
    push {
      branch = "^${var.github_branch_name}$"
    }
  }

  # Only trigger when bootstrap files or configuration changes (not on every push)
  included_files = [
    "**/creative-studio/backend/bootstrap/**",
    "**/creative-studio/backend/Dockerfile.bootstrap",
    "**/creative-studio/backend/cloudbuild-bootstrap.yaml"
  ]

  substitutions = {
    _BOOTSTRAP_JOB_NAME        = var.bootstrap_job_name != null ? var.bootstrap_job_name : "cstudio-bootstrap-${var.environment}"
    _BOOTSTRAP_IMAGE_NAME      = var.bootstrap_image_name
    _REPO_NAME                 = google_artifact_registry_repository.bootstrap_repo[0].repository_id
    _REGION                    = var.gcp_region
    _BOOTSTRAP_SERVICE_ACCOUNT = google_service_account.bootstrap_sa[0].email
    _VPC_CONNECTOR_NAME        = var.vpc_connector_name
    _VPC_CONNECTOR_ID          = var.vpc_connector_id
    _CLOUD_SQL_INSTANCE        = var.cloud_sql_connection_name
    _BOOTSTRAP_CPU             = var.bootstrap_job_cpu
    _BOOTSTRAP_MEMORY          = var.bootstrap_job_memory
    _BOOTSTRAP_TIMEOUT         = format("%ds", var.bootstrap_job_timeout)
    _BOOTSTRAP_ENV_VARS        = join(",", [for k, v in var.bootstrap_job_environment_variables : "${k}=${v}"])
    _BOOTSTRAP_SECRETS = join(",", [
      for env_var, secret_config in var.bootstrap_job_secrets : "${env_var}=${secret_config.secret_id}:latest"
    ])
  }

  depends_on = [
    google_service_account.bootstrap_trigger_sa,
    google_artifact_registry_repository.bootstrap_repo,
    google_service_account.bootstrap_sa,
  ]
}
