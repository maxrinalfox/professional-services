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

# --- Frontend Service Secrets Management ---
# This module creates and manages OAuth secrets required by the frontend service.
# Firebase SDK secrets are passed directly via Cloud Build substitutions (_FIREBASE_*),
# so they are no longer stored in Secret Manager.

# Create the unified OAuth credential secret
# This single secret is used by both:
# - Frontend: Cloud Build injects it into the application
# - Backend: Cloud Run mounts it as an environment variable
#
# IMPORTANT: This must be set to your OAuth 2.0 Client ID (same value for both services)
resource "google_secret_manager_secret" "frontend" {
  for_each = toset(var.frontend_secrets)
  provider = google-beta

  project   = var.gcp_project_id
  secret_id = each.key

  replication {
    auto {}
  }
}

# Grant the trigger service account (Cloud Build) access to frontend secrets
# This allows Cloud Build to read OAuth secrets during the build process
resource "google_secret_manager_secret_iam_member" "trigger_frontend_access" {
  for_each = toset(var.frontend_secrets)
  provider = google-beta

  project   = google_secret_manager_secret.frontend[each.key].project
  secret_id = google_secret_manager_secret.frontend[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.trigger_sa.member
}

# Secret versions must be populated manually before deployments
# Frontend Cloud Build will validate that secrets are populated and fail with
# clear error messages if they are missing or contain placeholder values.
# See infra/README.md for secret population instructions

# Export created secrets for reference by other modules
output "frontend_secrets_created" {
  value       = { for k, v in google_secret_manager_secret.frontend : k => v.secret_id }
  description = "Created frontend secret IDs"
}
