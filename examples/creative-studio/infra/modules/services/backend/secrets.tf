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

# --- Backend Service Secrets Management ---
# Backend secrets are now consolidated with frontend secrets:
# - OAuth credential (OAUTH_CLIENT_ID) is created by the frontend module
# - Backend only needs IAM permissions to access the unified OAuth credential
#
# Note: The unified OAUTH_CLIENT_ID secret is mounted as GOOGLE_TOKEN_AUDIENCE
# env var in Cloud Run (mapping is configured in main.tf)

# Backend service accounts need access to the unified OAuth credential secret
# This secret is created by the frontend module as "OAUTH_CLIENT_ID"

variable "frontend_oauth_secret_id" {
  type        = string
  description = "The OAuth credential secret ID from the frontend module (OAUTH_CLIENT_ID)"
  default     = "OAUTH_CLIENT_ID"
}

# Grant the trigger service account (Cloud Build) access to OAuth credential
# This is needed if backend build steps require the credential
resource "google_secret_manager_secret_iam_member" "trigger_oauth_access" {
  provider  = google-beta
  secret_id = var.frontend_oauth_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.trigger_sa.member
  project   = var.gcp_project_id
}

# Grant the runtime service account (Cloud Run) access to OAuth credential
# This allows Cloud Run to mount GOOGLE_TOKEN_AUDIENCE from OAUTH_CLIENT_ID secret
resource "google_secret_manager_secret_iam_member" "run_sa_oauth_access" {
  provider  = google-beta
  secret_id = var.frontend_oauth_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.run_sa.member
  project   = var.gcp_project_id
}
