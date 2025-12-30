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

# Create secrets with auto-replication
resource "google_secret_manager_secret" "this" {
  provider = google-beta
  for_each = var.secrets_config

  project   = var.gcp_project_id
  secret_id = each.key

  # Labels have a maximum value length of 63 characters
  # Truncate description if needed
  labels = each.value.description != "" ? {
    description = substr(each.value.description, 0, 63)
  } : {}

  replication {
    auto {}
  }
}

# Grant Secret Manager Accessor role to all specified service accounts
# Creates a flattened map of (secret_name, accessor) pairs and grants each accessor
# permission to access the corresponding secret
locals {
  secret_accessor_pairs = flatten([
    for secret_name, config in var.secrets_config : [
      for accessor in config.accessors : {
        secret_name = secret_name
        accessor    = accessor
        pair_key    = "${secret_name}:${accessor}"
      }
    ]
  ])

  secret_accessor_map = {
    for pair in local.secret_accessor_pairs :
    pair.pair_key => pair
  }
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  provider = google-beta
  for_each = local.secret_accessor_map

  project   = google_secret_manager_secret.this[each.value.secret_name].project
  secret_id = google_secret_manager_secret.this[each.value.secret_name].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.accessor
}

# Secret versions must be populated manually
# Terraform intentionally does NOT create placeholder versions.
# This ensures:
# - Fast-fail: Missing secrets caught at build time, not runtime
# - Clear feedback: Build pipelines validate and report missing secrets
# - No false confidence: Deployments don't appear successful when they won't work
#
# Populate secrets manually using:
#   gcloud secrets versions add SECRET_NAME --data-file=- --project=PROJECT_ID <<< "VALUE"
