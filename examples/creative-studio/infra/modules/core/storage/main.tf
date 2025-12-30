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

# --- Shared Storage Resources ---

resource "google_storage_bucket" "genmedia" {
  name                        = "creative-studio-${var.gcp_project_id}-assets"
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy

  cors {
    origin          = var.cors_allowed_origins
    method          = ["GET", "PUT", "POST", "DELETE", "HEAD", "OPTIONS"]
    response_header = ["Content-Type", "Access-Control-Allow-Origin", "x-goog-resumable", "Authorization", "Origin"]
    max_age_seconds = 3600
  }
}

resource "google_service_account" "bucket_writer_sa" {
  account_id   = "cs-${var.environment}-writer"
  display_name = "SA for reading/writing GenMedia (${var.environment}) bucket"
}

resource "google_storage_bucket_iam_member" "bucket_viewer_binding" {
  bucket = google_storage_bucket.genmedia.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.bucket_writer_sa.member
}

resource "google_storage_bucket_iam_member" "bucket_creator_binding" {
  bucket = google_storage_bucket.genmedia.name
  role   = "roles/storage.objectCreator"
  member = google_service_account.bucket_writer_sa.member
}

output "bucket_name" {
  value       = google_storage_bucket.genmedia.name
  description = "Name of the GenMedia storage bucket"
}

output "bucket_writer_sa_email" {
  value       = google_service_account.bucket_writer_sa.email
  description = "Email of the bucket writer service account"
}
