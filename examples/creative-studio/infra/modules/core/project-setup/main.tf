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

# --- Enable Required Google Cloud APIs ---
# These APIs are foundational for all platform infrastructure
locals {
  required_apis = [
    # ========== FIREBASE CORE APIs (Required for Phase 2 automation) ==========
    "firebase.googleapis.com",             # Firebase Management API - REQUIRED for google_firebase_project
    "firebasehosting.googleapis.com",      # Firebase Hosting API
    "identitytoolkit.googleapis.com",      # Firebase Identity Toolkit - Required for Identity Platform auth
    "cloudresourcemanager.googleapis.com", # Cloud Resource Manager - REQUIRED for Firebase project linking

    # ========== CORE INFRASTRUCTURE APIs ==========
    "serviceusage.googleapis.com",   # Service Usage API - REQUIRED to enable other APIs
    "iam.googleapis.com",            # IAM Management - REQUIRED for service accounts & roles
    "iamcredentials.googleapis.com", # IAM Credentials

    # ========== CLOUD BUILD & DEPLOYMENT APIs ==========
    "cloudbuild.googleapis.com",       # Cloud Build - REQUIRED for CI/CD triggers
    "artifactregistry.googleapis.com", # Artifact Registry - Required for container images

    # ========== CLOUD RUN APIs ==========
    "run.googleapis.com", # Cloud Run - REQUIRED for serverless backend

    # ========== NETWORKING & VPC APIs ==========
    "compute.googleapis.com",           # Compute Engine - REQUIRED for VPC resources
    "servicenetworking.googleapis.com", # Service Networking - REQUIRED for Cloud SQL private IP
    "vpcaccess.googleapis.com",         # Serverless VPC Connector - REQUIRED for VPC access

    # ========== DATABASE APIs ==========
    "sqladmin.googleapis.com", # Cloud SQL Admin - REQUIRED for Cloud SQL management

    # ========== DATA & STORAGE APIs ==========
    "firestore.googleapis.com",      # Firestore Database
    "cloudfunctions.googleapis.com", # Cloud Functions (optional, for advanced features)
    "aiplatform.googleapis.com",     # Vertex AI (for ML features)
    "texttospeech.googleapis.com",   # Text-to-Speech (if used by backend)

    # ========== SECRETS & SECURITY APIs ==========
    "secretmanager.googleapis.com", # Secret Manager - REQUIRED for storing credentials
  ]
}

resource "google_project_service" "apis" {
  # Use a for_each loop to enable each API from the variable list
  for_each = toset(local.required_apis)

  project = var.gcp_project_id
  service = each.key

  # This prevents Terraform from disabling APIs when you run `terraform destroy`
  disable_on_destroy = false
}

# --- API Initialization Delay ---
# Google Cloud APIs take time to fully initialize after being enabled.
# This is especially important for Identity Toolkit which is needed for Identity Platform.
# Without this delay, "SERVICE_DISABLED" errors can occur even though the API is enabled.
# Reference: https://cloud.google.com/docs/authentication/adc-troubleshooting/user-creds
resource "time_sleep" "api_initialization" {
  create_duration = "10s"
  depends_on = [
    google_project_service.apis
  ]
}

data "google_project" "project" {
  project_id = var.gcp_project_id
}

# Export APIs resource for dependency tracking
output "apis_resource" {
  value       = google_project_service.apis
  description = "Enabled APIs resource for dependency management"
}

output "api_initialization" {
  value       = time_sleep.api_initialization
  description = "API initialization delay for dependency management"
}

output "project_number" {
  value       = data.google_project.project.number
  description = "GCP Project number"
}
