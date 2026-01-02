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

# --- Firebase Hosting Site Configuration ---
# Creates the Firebase Hosting site infrastructure for deploying the frontend application.
#
# IMPORTANT: Firebase Hosting site is created empty/placeholder state.
# Actual frontend application is deployed via Cloud Build CI/CD pipeline (cloudbuild-deploy.yaml).
#
# Deployment Pattern:
# 1. Terraform creates Firebase Hosting site (infrastructure setup)
# 2. Cloud Build trigger monitors GitHub repository for code changes
# 3. On push to configured branch, Cloud Build:
#    a. Installs frontend dependencies (npm ci)
#    b. Injects configuration and secrets:
#       - Backend API URL (from _BACKEND_URL substitution)
#       - Firebase SDK config (from _FIREBASE_* substitutions - auto-discovered by Terraform)
#       - Google OAuth Client ID (from Secret Manager)
#    c. Builds Angular application (npm run build --configuration=production)
#    d. Deploys to Firebase Hosting (firebase deploy)
# 4. Firebase Hosting serves the built static files (HTML, CSS, JS)
#
# Note: Unlike Cloud Run (which has container images), Firebase Hosting directly
# deploys built static files. No placeholder file replacement needed - Cloud Build
# handles entire build and deployment cycle.

resource "google_firebase_hosting_site" "this" {
  provider = google-beta
  project = var.firebase_project_id
  site_id = var.service_name
}

# 2. Create a dedicated Service Account for the frontend trigger
resource "google_service_account" "trigger_sa" {
  account_id   = "${var.resource_prefix}-${var.environment}-trig"
  display_name = "SA for ${var.service_name} Trigger (${var.environment})"
}

# --- Cloud Build CI/CD Trigger for Frontend ---
# Automatically builds and deploys frontend whenever code is pushed to GitHub.
#
# How it works:
# 1. Cloud Build monitors the GitHub repository for pushes to the configured branch
# 2. On code push, Cloud Build executes cloudbuild-deploy.yaml steps:
#    - Step 1: npm ci (install dependencies from package-lock.json)
#    - Step 2: Inject configuration (backend URL, Firebase SDK config, OAuth Client ID)
#      * Uses Cloud Build substitutions for Firebase SDK config (auto-discovered from Terraform)
#      * Uses Secret Manager for OAuth credentials (GOOGLE_CLIENT_ID - requires manual setup)
#    - Step 3: npm run build (compile Angular application for production)
#    - Step 4: firebase deploy (deploy built files to Firebase Hosting)
#
# build_substitutions:
#   - Contains Terraform-managed values (backend URL, service IDs)
#   - These are injected into application config files (environment.prod.ts, firebase.json)
#   - Allows frontend to dynamically reference infrastructure values
#
# availableSecrets (in cloudbuild-deploy.yaml):
#   - Retrieved from Google Secret Manager during build
#   - Never exposed in git or Terraform logs
#   - Examples: GOOGLE_CLIENT_ID (OAuth credential)
#   - Note: Firebase SDK config comes via build_substitutions, not Secret Manager

resource "google_cloudbuild_trigger" "this" {
  count           = var.enable_cloud_build_trigger ? 1 : 0
  name            = "cstudio-${var.environment}-frontend-trigger"
  location        = var.gcp_region
  service_account = google_service_account.trigger_sa.id
  filename        = var.cloudbuild_yaml_path
  substitutions   = var.build_substitutions

  repository_event_config {
    repository = var.source_repository_id # Uses the ID passed from the platform
    push {
      branch = "^${var.github_branch_name}$"
    }
  }

  included_files = var.included_files_glob

  # When require_approval_for_deploy is true, the build will become pending
  # and require explicit approval before running (best practice for production)
  approval_config {
    approval_required = var.require_approval_for_deploy
  }
}

# 4. Give the trigger SA permission to deploy to Firebase Hosting
# Only created when Cloud Build trigger is enabled
resource "google_project_iam_member" "firebase_admin" {
  count   = var.enable_cloud_build_trigger ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/firebasehosting.admin"
  member  = google_service_account.trigger_sa.member
}

# 5. Give the trigger SA permission to write logs
# Only created when Cloud Build trigger is enabled
resource "google_project_iam_member" "logging_writer" {
  count   = var.enable_cloud_build_trigger ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.trigger_sa.member
}
