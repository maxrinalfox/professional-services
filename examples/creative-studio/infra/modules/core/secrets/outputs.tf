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

output "secrets" {
  description = "A map of the created secret resources, keyed by their secret_id."
  value = {
    for secret in google_secret_manager_secret.this : secret.secret_id => secret
  }
}

output "secret_names" {
  description = "List of all created secret names (useful for reference in scripts)"
  value       = keys(google_secret_manager_secret.this)
}

output "secret_ids" {
  description = "Map of secret names to their full resource IDs (projects/{project}/secrets/{secret_id})"
  value = {
    for secret_name, secret in google_secret_manager_secret.this :
    secret_name => secret.id
  }
}

output "accessor_bindings" {
  description = "Created Secret Manager Accessor IAM bindings (read access to secret versions)"
  value       = google_secret_manager_secret_iam_member.accessor
}

output "version_adder_bindings" {
  description = "Created Secret Manager Version Adder IAM bindings (ability to add/rotate secret versions)"
  value       = google_secret_manager_secret_iam_member.version_adder
}

output "secret_population_commands" {
  description = "Helper commands to populate secrets manually via gcloud CLI"
  value = {
    for secret_name in keys(google_secret_manager_secret.this) :
    secret_name => "gcloud secrets versions add ${secret_name} --data-file=- --project=${var.gcp_project_id} <<< \"YOUR_${secret_name}_VALUE\""
  }
}
