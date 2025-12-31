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

output "service_url" {
  description = "The URL of the deployed Cloud Run backend service (use this to access the API)"
  value       = google_cloud_run_v2_service.this.uri
}

output "service_name" {
  description = "The name of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.name
}

output "location" {
  description = "The GCP region where the Cloud Run service is deployed"
  value       = google_cloud_run_v2_service.this.location
}

output "service_revision" {
  description = "The latest revision of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.latest_ready_revision
}

output "trigger_sa_email" {
  description = "The email of the service account used by the Cloud Build trigger (for permissions configuration)"
  value       = google_service_account.trigger_sa.email
}

output "trigger_sa_member" {
  description = "The member identifier (formatted for IAM bindings) of the build trigger service account"
  value       = google_service_account.trigger_sa.member
}

output "run_sa_email" {
  description = "The email of the service account used by the Cloud Run service at runtime (for API calls from the service)"
  value       = google_service_account.run_sa.email
}

output "run_sa_member" {
  description = "The member identifier (formatted for IAM bindings) of the Cloud Run runtime service account"
  value       = google_service_account.run_sa.member
}

output "service_iam_done" {
  description = "Dependency marker for IAM bindings. Used by other modules to ensure proper ordering"
  value       = google_cloud_run_v2_service.this.id
}
