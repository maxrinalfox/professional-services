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

output "job_name" {
  description = "Name of the created Cloud Run Job"
  value       = google_cloud_run_v2_job.bootstrap.name
}

output "job_id" {
  description = "Fully qualified ID of the Cloud Run Job"
  value       = google_cloud_run_v2_job.bootstrap.id
}

output "job_uri" {
  description = "URI of the Cloud Run Job for gcloud commands"
  value       = "${var.region}/jobs/${google_cloud_run_v2_job.bootstrap.name}"
}

output "service_account_email" {
  description = "Service account email running the job"
  value       = var.service_account_email
}

output "execution_command" {
  description = "gcloud command to execute the job"
  value       = "gcloud run jobs execute ${google_cloud_run_v2_job.bootstrap.name} --region ${var.region} --project ${var.project_id} --wait"
}

output "logs_filter" {
  description = "Cloud Logging filter for job logs"
  value       = "resource.type=cloud_run_job AND resource.labels.job_name=${var.job_name}"
}
