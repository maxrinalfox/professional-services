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
# This module creates and manages all secrets required by the frontend service
# Each secret is provisioned with IAM bindings to the Cloud Build trigger SA

# Create the "shell" for each frontend secret
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
# This allows Cloud Build to read secrets during the build process
resource "google_secret_manager_secret_iam_member" "trigger_frontend_access" {
  for_each = toset(var.frontend_secrets)
  provider = google-beta

  project   = google_secret_manager_secret.frontend[each.key].project
  secret_id = google_secret_manager_secret.frontend[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.trigger_sa.member
}

# Create placeholder versions for each secret
# These ensure Cloud Build can reference the secret path even if the actual
# secret data will be added later or already exists
resource "google_secret_manager_secret_version" "frontend" {
  for_each = toset(var.frontend_secrets)
  provider = google-beta

  secret      = google_secret_manager_secret.frontend[each.key].id
  secret_data = "placeholder_${each.key}_will_be_updated"

  lifecycle {
    # Once created, subsequent applies won't overwrite the secret data
    # This allows manual updates via gcloud or GCP console
    ignore_changes = [secret_data]
  }
}

# Export created secrets for reference by other modules
output "frontend_secrets_created" {
  value       = { for k, v in google_secret_manager_secret.frontend : k => v.secret_id }
  description = "Created frontend secret IDs"
}
