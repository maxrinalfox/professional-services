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

# 1. Create the "shell" for each secret in the list
resource "google_secret_manager_secret" "this" {
  provider = google-beta
  for_each = toset(var.secret_names) # Loop over the list of names

  project   = var.gcp_project_id
  secret_id = each.key # Use the name from the list as the secret_id

  replication {
    auto {}
  }
}

# 2. Grant the accessor role for each secret to the specified service account
#
# IMPORTANT: This binding intelligently handles both formats:
# - If accessor_sa_email contains ":" (full member format), use as-is
#   Example: "serviceAccount:my-sa@project.iam.gserviceaccount.com"
# - If accessor_sa_email is just email, prefix with "serviceAccount:"
#   Example: "my-sa@project.iam.gserviceaccount.com" → "serviceAccount:my-sa@project.iam.gserviceaccount.com"
#
# Best practice: Pass the .member attribute of service account resources for consistency:
#   accessor_sa_email = google_service_account.my_sa.member
resource "google_secret_manager_secret_iam_member" "accessor" {
  provider = google-beta
  for_each = toset(var.secret_names) # Loop over the same list

  project   = google_secret_manager_secret.this[each.key].project
  secret_id = google_secret_manager_secret.this[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  # Intelligently detect format: if it contains ":", assume it's full member format; otherwise prefix with "serviceAccount:"
  member = strcontains(var.accessor_sa_email, ":") ? var.accessor_sa_email : "serviceAccount:${var.accessor_sa_email}"
}

# 3. Secret versions must be populated manually
# Terraform intentionally does NOT create placeholder versions.
# This ensures:
# - Fast-fail: Missing secrets caught at build time, not runtime
# - Clear feedback: Build pipelines validate and report missing secrets
# - No false confidence: Deployments don't appear successful when they won't work
#
# Populate secrets manually using:
#   gcloud secrets versions add SECRET_NAME --data-file=- --project=PROJECT_ID <<< "VALUE"
