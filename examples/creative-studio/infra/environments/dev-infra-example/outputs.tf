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

output "gcp_project_id" {
  description = "The GCP project ID for this environment."
  value       = var.gcp_project_id
}

output "frontend_secrets" {
  description = "A list of frontend secret names."
  value       = var.frontend_secrets
}

output "backend_secrets" {
  description = "A list of backend secret names."
  value       = var.backend_secrets
}

output "cloud_sql_connection_name" {
  description = "The connection name of the Cloud SQL instance to be used by the bootstrap script."
  value       = module.creative_studio_platform.cloud_sql_connection_name
}

output "vpc_connector_id" {
  description = "VPC Connector ID for Cloud Run (if VPC is enabled)"
  value       = module.creative_studio_platform.vpc_connector_id
}

output "vpc_connector_name" {
  description = "VPC Connector name for Cloud Run (if VPC is enabled)"
  value       = module.creative_studio_platform.vpc_connector_name
}

output "vpc_network_id" {
  description = "VPC network ID (if VPC is enabled)"
  value       = module.creative_studio_platform.vpc_network_id
}

# ============================================================================
# POST-DEPLOYMENT INSTRUCTIONS
# ============================================================================
# The outputs below provide step-by-step instructions for completing
# the deployment after terraform apply finishes.

output "post_deployment_instructions" {
  description = "Step-by-step instructions for completing the deployment"
  value = <<-EOT

╔════════════════════════════════════════════════════════════════════════════╗
║                    🚀 TERRAFORM APPLY SUCCESSFUL                           ║
║                                                                            ║
║  Infrastructure created! Now complete these manual steps:                  ║
╚════════════════════════════════════════════════════════════════════════════╝

⚠️  CRITICAL: DO NOT REBUILD FRONTEND YET!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The frontend MUST wait for ALL 8 secrets to be populated in Secret Manager.
If you rebuild frontend NOW, it will use empty/placeholder values and fail with "API key not valid".

Timeline:
1. Terraform creates all 8 secrets with placeholder values
2. Firebase SDK secrets (6 secrets) → Must be populated from Firebase Web App config
3. OAuth secrets (2 secrets) → Must be created/configured manually
4. ONLY after all 8 are populated → Frontend build can proceed

📋 STEP 1: POPULATE FIREBASE SDK SECRETS (6 secrets from Firebase Web App)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Firebase SDK secrets (FIREBASE_API_KEY, FIREBASE_AUTH_DOMAIN, FIREBASE_PROJECT_ID,
FIREBASE_STORAGE_BUCKET, FIREBASE_MESSAGING_SENDER_ID, FIREBASE_MEASUREMENT_ID)
must be extracted from your Firebase Web App configuration and populated into Secret Manager.

Method 1: Use the provided update_secrets.sh script (RECOMMENDED):

$ cd infra/environments/${var.environment}
$ ./update_secrets.sh

This script will:
  ✅ Auto-discover Firebase Web App configuration
  ✅ Auto-populate all 6 Firebase SDK secrets
  ✅ Ask you to manually provide OAuth secrets

Method 2: Manual gcloud commands:

First, find your Firebase Web App configuration:
$ firebase apps:list --project=${var.gcp_project_id}

Then get the SDK config:
$ firebase apps:sdkconfig WEB <APP_ID> --project=${var.gcp_project_id}

Finally, populate each Firebase secret:
$ gcloud secrets versions add FIREBASE_API_KEY --data-file=- --project=${var.gcp_project_id} <<< "YOUR_API_KEY"
$ gcloud secrets versions add FIREBASE_AUTH_DOMAIN --data-file=- --project=${var.gcp_project_id} <<< "YOUR_AUTH_DOMAIN"
# ... (repeat for other 4 Firebase secrets)

⚠️  After step 1, you should have 6/8 secrets populated. Proceed to STEP 2.


📋 STEP 2: CONFIGURE OAUTH SECRETS (Required for Frontend & Backend)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This step configures TWO secrets that are CRITICAL for authentication to work:
- GOOGLE_CLIENT_ID: Frontend login
- GOOGLE_TOKEN_AUDIENCE: Backend JWT validation (must equal GOOGLE_CLIENT_ID)

A. CREATE OAUTH CLIENT ID:

1. Go to GCP Console:
   → APIs & Services → Credentials → Create Credentials → OAuth client ID

2. Choose: Web application

3. Add Authorized Redirect URIs:
   • https://${var.gcp_project_id}.firebaseapp.com/__/auth/handler
   • https://${var.gcp_project_id}.web.app/__/auth/handler

4. Copy the OAuth Client ID (looks like: 123456789-abcdefghijk.apps.googleusercontent.com)

B. UPDATE BOTH SECRETS:

$ OAUTH_CLIENT_ID="YOUR_OAUTH_CLIENT_ID"

# Update GOOGLE_CLIENT_ID (for frontend login)
$ gcloud secrets versions add GOOGLE_CLIENT_ID \
    --data-file=- --project=${var.gcp_project_id} \
    <<< "$OAUTH_CLIENT_ID"

# Update GOOGLE_TOKEN_AUDIENCE (for backend JWT validation - MUST be same as GOOGLE_CLIENT_ID)
$ gcloud secrets versions add GOOGLE_TOKEN_AUDIENCE \
    --data-file=- --project=${var.gcp_project_id} \
    <<< "$OAUTH_CLIENT_ID"


📋 STEP 3: TRIGGER FRONTEND BUILD (After Secrets are Populated)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Once GOOGLE_CLIENT_ID is in Secret Manager, rebuild the frontend:

$ gcloud builds submit \
    --config=frontend/cloudbuild-deploy.yaml \
    --project=${var.gcp_project_id} \
    --substitutions=_FIREBASE_PROJECT_ID=${var.gcp_project_id}

Monitor the build:
$ gcloud builds log <BUILD_ID> --project=${var.gcp_project_id}


📋 STEP 4: TEST BACKEND HEALTH CHECKS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Once deployed, test the backend is accessible:

$ curl https://<BACKEND_URL>/
Expected: "You are calling Creative Studio Backend"

$ curl https://<BACKEND_URL>/api/version
Expected: "v0.0.1"


📋 STEP 5: TEST LOGIN FLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Open the frontend URL in your browser:
https://${var.gcp_project_id}.firebaseapp.com

1. Click "Login with Google"
2. Google prompt should appear (not a placeholder)
3. Sign in with your email
4. Should redirect to home page

If login fails, see DEPLOYMENT_TROUBLESHOOTING.md


🔗 USEFUL LINKS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Deployment Troubleshooting:
→ See: DEPLOYMENT_TROUBLESHOOTING.md (in repo root)

Bootstrap Job Configuration:
→ See: backend/BOOTSTRAP.md

Secret Management:
→ See: infra/SECRETS_CONFIGURATION.md

Creating OAuth Client ID:
→ https://console.cloud.google.com/apis/credentials

Firebase Hosting:
→ https://console.firebase.google.com/project/${var.gcp_project_id}/hosting

Cloud Run Services:
→ https://console.cloud.google.com/run/services?project=${var.gcp_project_id}

Secret Manager:
→ https://console.cloud.google.com/security/secret-manager?project=${var.gcp_project_id}


📌 CHECKLIST - Mark as You Complete:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [ ] Step 1: Ran update_secrets.sh to populate 6 Firebase SDK secrets
  [ ] Step 1: Verified 6/8 secrets now populated in Secret Manager
  [ ] Step 2: Created OAuth Client ID in GCP Console
  [ ] Step 2: Updated GOOGLE_CLIENT_ID secret in Secret Manager
  [ ] Step 2: Updated GOOGLE_TOKEN_AUDIENCE secret (set equal to GOOGLE_CLIENT_ID)
  [ ] Step 2: Verified 8/8 secrets now populated in Secret Manager
  [ ] Step 3: Triggered frontend build
  [ ] Step 4: Backend health checks respond (HTTP 200)
  [ ] Step 5: Frontend loads without placeholder errors
  [ ] Step 5: Google login prompt appears
  [ ] Step 5: Can sign in and see home page


✅ DEPLOYMENT COMPLETE when all items are checked!

  EOT
  sensitive = false
}

output "required_secrets_to_populate" {
  description = "All 8 secrets (6 Firebase + 2 OAuth) that MUST be populated before frontend/backend build"
  value = {
    # Firebase SDK secrets (6 total) - populated via update_secrets.sh
    "FIREBASE_API_KEY" = {
      description = "Firebase API Key for SDK initialization"
      type = "Firebase SDK"
      status = "⚠️  MUST POPULATE - Via update_secrets.sh"
      setup_location = "Run update_secrets.sh script"
      current_value = "placeholder_FIREBASE_API_KEY_will_be_updated"
      required_before = "Frontend build"
      population_method = "update_secrets.sh or 'firebase apps:sdkconfig' command"
    }
    "FIREBASE_AUTH_DOMAIN" = {
      description = "Firebase Authentication domain (e.g., project-id.firebaseapp.com)"
      type = "Firebase SDK"
      status = "⚠️  MUST POPULATE - Via update_secrets.sh"
      setup_location = "Run update_secrets.sh script"
      current_value = "placeholder_FIREBASE_AUTH_DOMAIN_will_be_updated"
      required_before = "Frontend build"
      population_method = "update_secrets.sh or 'firebase apps:sdkconfig' command"
    }
    "FIREBASE_PROJECT_ID" = {
      description = "Firebase Project ID (same as GCP project ID)"
      type = "Firebase SDK"
      status = "⚠️  MUST POPULATE - Via update_secrets.sh"
      setup_location = "Run update_secrets.sh script"
      current_value = "placeholder_FIREBASE_PROJECT_ID_will_be_updated"
      required_before = "Frontend build"
      population_method = "update_secrets.sh (auto-populated from project ID)"
    }
    "FIREBASE_STORAGE_BUCKET" = {
      description = "Firebase Cloud Storage bucket name (e.g., project-id.appspot.com)"
      type = "Firebase SDK"
      status = "⚠️  MUST POPULATE - Via update_secrets.sh"
      setup_location = "Run update_secrets.sh script"
      current_value = "placeholder_FIREBASE_STORAGE_BUCKET_will_be_updated"
      required_before = "Frontend build"
      population_method = "update_secrets.sh or 'firebase apps:sdkconfig' command"
    }
    "FIREBASE_MESSAGING_SENDER_ID" = {
      description = "Firebase Cloud Messaging sender ID"
      type = "Firebase SDK"
      status = "⚠️  MUST POPULATE - Via update_secrets.sh"
      setup_location = "Run update_secrets.sh script"
      current_value = "placeholder_FIREBASE_MESSAGING_SENDER_ID_will_be_updated"
      required_before = "Frontend build"
      population_method = "update_secrets.sh or 'firebase apps:sdkconfig' command"
    }
    "FIREBASE_MEASUREMENT_ID" = {
      description = "Firebase Analytics measurement ID (can be empty string)"
      type = "Firebase SDK"
      status = "⚠️  MUST POPULATE - Via update_secrets.sh"
      setup_location = "Run update_secrets.sh script"
      current_value = "placeholder_FIREBASE_MEASUREMENT_ID_will_be_updated"
      required_before = "Frontend build"
      population_method = "update_secrets.sh or 'firebase apps:sdkconfig' command (can be empty)"
    }
    # OAuth secrets (2 total) - manual setup required
    "GOOGLE_CLIENT_ID" = {
      description = "OAuth 2.0 Client ID for Google Sign-In (frontend authentication)"
      type = "OAuth"
      status = "⚠️  MUST POPULATE - Manual setup in GCP Console"
      setup_location = "GCP Console → APIs & Services → Credentials"
      gcp_console_url = "https://console.cloud.google.com/apis/credentials?project=${var.gcp_project_id}"
      current_value = "placeholder_GOOGLE_CLIENT_ID_will_be_updated"
      required_before = "Frontend build"
      population_method = "Create OAuth Client ID in GCP Console, then: gcloud secrets versions add GOOGLE_CLIENT_ID"
    }
    "GOOGLE_TOKEN_AUDIENCE" = {
      description = "JWT audience for backend token validation (MUST equal GOOGLE_CLIENT_ID)"
      type = "OAuth"
      status = "⚠️  MUST POPULATE - Manual setup in Secret Manager"
      setup_location = "GCP Console → Secret Manager"
      gcp_console_url = "https://console.cloud.google.com/security/secret-manager?project=${var.gcp_project_id}"
      current_value = "placeholder_GOOGLE_TOKEN_AUDIENCE_will_be_updated"
      required_before = "Backend deployment"
      population_method = "Set to same value as GOOGLE_CLIENT_ID: gcloud secrets versions add GOOGLE_TOKEN_AUDIENCE"
      note = "CRITICAL: This value MUST be identical to GOOGLE_CLIENT_ID for backend JWT validation to work"
    }
  }
}

output "firebase_sdk_configuration" {
  description = "Firebase SDK secrets that must be populated from Firebase Web App configuration"
  value = {
    "FIREBASE_API_KEY" = {
      status = "⚠️  MANUAL - Must populate from Firebase Web App config"
      source = "Firebase Web App configuration (via firebase CLI or update_secrets.sh)"
      required = true
      note = "Populate using: update_secrets.sh or 'firebase apps:sdkconfig' command"
      secret_manager_path = "projects/${var.gcp_project_id}/secrets/FIREBASE_API_KEY/versions/latest"
    }
    "FIREBASE_AUTH_DOMAIN" = {
      status = "⚠️  MANUAL - Must populate from Firebase Web App config"
      source = "Firebase Web App configuration (via firebase CLI or update_secrets.sh)"
      required = true
      note = "Populate using: update_secrets.sh or 'firebase apps:sdkconfig' command"
      secret_manager_path = "projects/${var.gcp_project_id}/secrets/FIREBASE_AUTH_DOMAIN/versions/latest"
    }
    "FIREBASE_PROJECT_ID" = {
      status = "⚠️  MANUAL - Must populate from GCP Project ID"
      source = "GCP Project ID: ${var.gcp_project_id}"
      required = true
      note = "Populate using: update_secrets.sh or 'gcloud secrets versions add' with project ID"
      secret_manager_path = "projects/${var.gcp_project_id}/secrets/FIREBASE_PROJECT_ID/versions/latest"
    }
    "FIREBASE_STORAGE_BUCKET" = {
      status = "⚠️  MANUAL - Must populate from Firebase Web App config"
      source = "Firebase Web App configuration (via firebase CLI or update_secrets.sh)"
      required = true
      note = "Populate using: update_secrets.sh or 'firebase apps:sdkconfig' command"
      secret_manager_path = "projects/${var.gcp_project_id}/secrets/FIREBASE_STORAGE_BUCKET/versions/latest"
    }
    "FIREBASE_MESSAGING_SENDER_ID" = {
      status = "⚠️  MANUAL - Must populate from Firebase Web App config"
      source = "Firebase Web App configuration (via firebase CLI or update_secrets.sh)"
      required = true
      note = "Populate using: update_secrets.sh or 'firebase apps:sdkconfig' command"
      secret_manager_path = "projects/${var.gcp_project_id}/secrets/FIREBASE_MESSAGING_SENDER_ID/versions/latest"
    }
    "FIREBASE_MEASUREMENT_ID" = {
      status = "⚠️  MANUAL - Must populate from Firebase Web App config (can be empty)"
      source = "Firebase Web App configuration (via firebase CLI or update_secrets.sh)"
      required = true
      note = "Populate using: update_secrets.sh or 'firebase apps:sdkconfig' command. Can be empty string."
      secret_manager_path = "projects/${var.gcp_project_id}/secrets/FIREBASE_MEASUREMENT_ID/versions/latest"
    }
  }
}

output "all_secrets_reference" {
  description = "Complete reference matrix of all 8 secrets with setup status"
  value = <<-EOT
┌──────────────────────────────────────────────────────────────────────────────────┐
│                         🔐 ALL SECRETS REFERENCE MATRIX                          │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│ FIREBASE SDK SECRETS (6 total) - Populate from Firebase Web App                  │
│ ────────────────────────────────────────────────────────────────────────────── │
│ ⚠️  FIREBASE_API_KEY           → Populate via update_secrets.sh or Firebase CLI   │
│ ⚠️  FIREBASE_AUTH_DOMAIN       → Populate via update_secrets.sh or Firebase CLI   │
│ ⚠️  FIREBASE_PROJECT_ID        → Populate via update_secrets.sh (from project ID) │
│ ⚠️  FIREBASE_STORAGE_BUCKET    → Populate via update_secrets.sh or Firebase CLI   │
│ ⚠️  FIREBASE_MESSAGING_SENDER_ID → Populate via update_secrets.sh or Firebase CLI │
│ ⚠️  FIREBASE_MEASUREMENT_ID    → Populate via update_secrets.sh or Firebase CLI   │
│                                                                                  │
│ OAUTH AUTHENTICATION SECRETS (2 total) - Manual Setup Required                  │
│ ────────────────────────────────────────────────────────────────────────────── │
│ ⚠️  GOOGLE_CLIENT_ID          → Manual: Create OAuth Client ID in GCP Console   │
│ ⚠️  GOOGLE_TOKEN_AUDIENCE     → Manual: Set equal to GOOGLE_CLIENT_ID value     │
│                                                                                  │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│ POPULATION TIMELINE:                                                            │
│                                                                                  │
│ 1. ✅ terraform apply                                                            │
│    → Creates all 8 secrets with placeholder values in Secret Manager            │
│                                                                                  │
│ 2. ⚠️  STEP 1: Populate 6 Firebase SDK secrets                                   │
│    → Run: update_secrets.sh                                                     │
│    → OR: Manually use 'firebase apps:sdkconfig' + 'gcloud secrets versions add' │
│    → Progress: 6/8 secrets populated                                            │
│                                                                                  │
│ 3. ⚠️  STEP 2: Configure 2 OAuth secrets                                         │
│    → Create OAuth Client ID in GCP Console                                      │
│    → Set GOOGLE_CLIENT_ID to the created OAuth Client ID                        │
│    → Set GOOGLE_TOKEN_AUDIENCE to same value as GOOGLE_CLIENT_ID                │
│    → Progress: 8/8 secrets populated ✅                                          │
│                                                                                  │
│ 4. ✅ STEP 3: Trigger frontend build                                             │
│    → Only proceed after ALL 8 secrets are populated                             │
│    → Frontend Cloud Build will read all secrets from Secret Manager             │
│    → Frontend will have valid Firebase config and OAuth credentials             │
│                                                                                  │
│ RESULT:                                                                          │
│ • All 8 secrets populated in Secret Manager ✅                                   │
│ • Frontend built with valid Firebase SDK configuration                           │
│ • Frontend can authenticate users via Google Sign-In                             │
│ • Backend can validate JWT tokens with GOOGLE_TOKEN_AUDIENCE                     │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
  EOT
  sensitive = false
}

output "infrastructure_endpoints" {
  description = "Key endpoints and URLs for your deployment"
  value = {
    backend_url = module.creative_studio_platform.backend_service_url
    frontend_url = "https://${var.gcp_project_id}.firebaseapp.com"
    gcp_project_id = var.gcp_project_id
    region = var.gcp_region
    environment = var.environment
  }
}
