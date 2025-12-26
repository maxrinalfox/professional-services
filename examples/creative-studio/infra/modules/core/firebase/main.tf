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

# --- Firebase Project Creation ---
# Firebase project is needed for:
# - Firebase Hosting (frontend deployment)
# - Identity Platform (user authentication)
# - Firestore database
#
# Should be created whenever ANY of these features are enabled:
resource "google_firebase_project" "default" {
  count    = (var.enable_cloud_build || var.enable_identity_platform) ? 1 : 0
  provider = google-beta
  project  = var.gcp_project_id

  depends_on = [var.api_initialization]
}

# --- Identity Platform Configuration ---
# Enables Firebase Authentication and Google Cloud Identity Platform
# Provides authentication services for both frontend and backend
#
# IMPORTANT: This resource is controlled by enable_identity_platform variable
# which is INDEPENDENT of enable_cloud_build. This allows you to:
# - Have authentication without CI/CD deployment (enable_identity_platform=true, enable_cloud_build=false)
# - Have CI/CD without authentication (enable_identity_platform=false, enable_cloud_build=true)
# - Control infrastructure and authentication separately
#
# Reference: https://firebase.google.com/docs/projects/terraform/get-started#tf-sample-auth
resource "google_identity_platform_config" "default" {
  count    = var.enable_identity_platform ? 1 : 0
  provider = google-beta
  project  = var.gcp_project_id

  # Identity Platform configuration is intentionally minimal
  # Sign-in methods and other settings are managed via GCP Console
  # or can be configured separately as needed

  # Ignore changes to attributes managed by Google Cloud
  # Google Cloud manages fields like multi_tenant, phone_number, sign_in, etc.
  # These appear in the config but are not managed by Terraform
  # Without this, every terraform plan will show spurious changes
  lifecycle {
    ignore_changes = all  # Ignore all changes since configuration is managed externally
  }

  depends_on = [
    google_firebase_project.default[0],
    var.api_initialization  # Wait for all APIs (including Identity Toolkit) to fully initialize
  ]
}

# --- Firebase Web App Creation ---
# Creates a Firebase web app automatically (if enable_cloud_build = true and firebase_web_app_id not provided)
# Phase 2: Automated Firebase Web App Creation
resource "google_firebase_web_app" "default" {
  count           = (var.enable_cloud_build && var.firebase_web_app_id == null) ? 1 : 0
  provider        = google-beta
  project         = var.gcp_project_id
  display_name    = "Creative Studio Frontend"
  deletion_policy = "DELETE"

  depends_on = [google_firebase_project.default]
}

# --- Firebase Web App Configuration (Auto-Discovery) ---
# This data source retrieves the Firebase web app configuration automatically
# instead of requiring manual population via bootstrap scripts.
#
# IMPORTANT: The Firebase web app must already exist in the Firebase project.
# This typically happens when:
# 1. Firebase project is created via GCP Console (or via google_firebase_project resource above)
# 2. A web app is created in Firebase (manually or via google_firebase_web_app resource above)
# 3. This data source reads the app's configuration
#
# The data source extracts all 7 Firebase SDK values needed by the frontend,
# eliminating the need to manually enter them via bootstrap scripts or .tfvars.
#
# Note: This data source requires the google-beta provider as it's in beta
# Phase 1 & 2 Compatible: Works with both manually created and auto-created web apps
#
# IMPORTANT: This is ALWAYS evaluated (not conditional on enable_cloud_build)
# Firebase web app configuration is needed for:
# - Frontend service deployment (Firebase Hosting)
# - Identity Platform setup
# The Cloud Build trigger is optional, but the web app itself is required infrastructure
data "google_firebase_web_app_config" "default" {
  count    = (var.firebase_web_app_id != null || (var.enable_cloud_build && var.firebase_web_app_id == null)) ? 1 : 0
  provider = google-beta

  # Determine which web app ID to use:
  # - Phase 1 Manual: Use provided firebase_web_app_id
  # - Phase 2 Automation: Use auto-created google_firebase_web_app.default app_id
  web_app_id = var.firebase_web_app_id != null ? var.firebase_web_app_id : google_firebase_web_app.default[0].app_id

  project = var.gcp_project_id
}

# --- Exported Firebase Configuration ---
# Compute Firebase SDK config for secret creation
locals {
  firebase_sdk_config = length(data.google_firebase_web_app_config.default) > 0 ? {
    FIREBASE_API_KEY             = data.google_firebase_web_app_config.default[0].api_key
    FIREBASE_AUTH_DOMAIN         = data.google_firebase_web_app_config.default[0].auth_domain
    FIREBASE_PROJECT_ID          = data.google_firebase_web_app_config.default[0].project
    FIREBASE_STORAGE_BUCKET      = data.google_firebase_web_app_config.default[0].storage_bucket
    FIREBASE_MESSAGING_SENDER_ID = data.google_firebase_web_app_config.default[0].messaging_sender_id
    FIREBASE_MEASUREMENT_ID      = data.google_firebase_web_app_config.default[0].measurement_id
  } : {}

  # Extract secret names from auto-computed Firebase config
  frontend_secrets_auto = keys(local.firebase_sdk_config)
}

# --- Outputs ---
output "firebase_project_id" {
  value       = var.enable_cloud_build || var.enable_identity_platform ? var.gcp_project_id : null
  description = "The Firebase Project ID (same as GCP Project ID)"
}

output "firebase_web_app_id" {
  value       = var.firebase_web_app_id != null ? var.firebase_web_app_id : (var.enable_cloud_build && length(google_firebase_web_app.default) > 0 ? google_firebase_web_app.default[0].app_id : null)
  description = "Firebase Web App ID"
}

output "firebase_sdk_config" {
  value       = local.firebase_sdk_config
  description = "Firebase SDK configuration from web app"
  sensitive   = true
}

output "frontend_secrets_auto" {
  value       = local.frontend_secrets_auto
  description = "Frontend secret names auto-discovered from Firebase config"
}

output "auth_domain" {
  value       = var.enable_identity_platform ? "${var.gcp_project_id}.firebaseapp.com" : null
  description = "Firebase Auth domain for authentication"
}

output "firebase_web_app_config" {
  value       = data.google_firebase_web_app_config.default
  description = "Firebase Web App configuration data source (contains SDK values)"
  sensitive   = true
}
