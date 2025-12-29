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

✅ FIREBASE SDK SECRETS: AUTOMATICALLY CONFIGURED!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Firebase SDK secrets (FIREBASE_API_KEY, FIREBASE_AUTH_DOMAIN, FIREBASE_PROJECT_ID,
FIREBASE_STORAGE_BUCKET, FIREBASE_MESSAGING_SENDER_ID, FIREBASE_MEASUREMENT_ID)
are auto-discovered from your Firebase Web App and injected directly into Cloud Build
via Terraform. No manual population needed!

⚠️  ONLY OAUTH SECRETS REQUIRE MANUAL SETUP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The frontend MUST wait for OAUTH secrets to be populated in Secret Manager.
If you rebuild frontend NOW without setting GOOGLE_CLIENT_ID, the build will fail.

Timeline:
1. Terraform auto-discovers Firebase SDK secrets (no action needed)
2. OAuth secrets → Must be created/configured manually
3. ONLY after OAuth secrets are populated → Frontend build can proceed

📋 STEP 1: CONFIGURE OAUTH SECRETS (Required for Frontend & Backend)
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

  [ ] ✅ Firebase SDK secrets auto-discovered via Terraform (no action needed)
  [ ] Step 1: Created OAuth Client ID in GCP Console
  [ ] Step 1: Updated GOOGLE_CLIENT_ID secret in Secret Manager
  [ ] Step 1: Updated GOOGLE_TOKEN_AUDIENCE secret (set equal to GOOGLE_CLIENT_ID)
  [ ] Step 2: Triggered frontend build
  [ ] Step 3: Backend health checks respond (HTTP 200)
  [ ] Step 4: Frontend loads without placeholder errors
  [ ] Step 4: Google login prompt appears
  [ ] Step 4: Can sign in and see home page


✅ DEPLOYMENT COMPLETE when all items are checked!

  EOT
  sensitive = false
}

output "required_secrets_to_populate" {
  description = "OAuth secrets that MUST be manually populated before frontend deployment"
  value = {
    "GOOGLE_CLIENT_ID" = {
      description = "OAuth 2.0 Client ID for Google Sign-In (frontend authentication)"
      type = "OAuth"
      status = "⚠️  MUST POPULATE - Manual setup in GCP Console"
      setup_location = "GCP Console → APIs & Services → Credentials"
      gcp_console_url = "https://console.cloud.google.com/apis/credentials?project=${var.gcp_project_id}"
      current_value = "placeholder_GOOGLE_CLIENT_ID_will_be_updated"
      required_before = "Frontend build"
      population_method = "1. Create OAuth Client ID in GCP Console\n2. Run: gcloud secrets versions add GOOGLE_CLIENT_ID --data-file=- --project=${var.gcp_project_id} <<< \"YOUR_CLIENT_ID\""
    }
    "GOOGLE_TOKEN_AUDIENCE" = {
      description = "JWT audience for backend token validation (MUST equal GOOGLE_CLIENT_ID)"
      type = "OAuth"
      status = "⚠️  MUST POPULATE - Manual setup in Secret Manager"
      setup_location = "GCP Console → Secret Manager"
      gcp_console_url = "https://console.cloud.google.com/security/secret-manager?project=${var.gcp_project_id}"
      current_value = "placeholder_GOOGLE_TOKEN_AUDIENCE_will_be_updated"
      required_before = "Backend deployment"
      population_method = "Set to same value as GOOGLE_CLIENT_ID: gcloud secrets versions add GOOGLE_TOKEN_AUDIENCE --data-file=- --project=${var.gcp_project_id} <<< \"YOUR_CLIENT_ID\""
      note = "CRITICAL: This value MUST be identical to GOOGLE_CLIENT_ID for backend JWT validation to work"
    }
  }
}

output "firebase_sdk_configuration" {
  description = "Firebase SDK configuration that is auto-discovered and injected via Cloud Build substitutions"
  value = {
    "FIREBASE_API_KEY" = {
      status = "✅ AUTO-AVAILABLE - Auto-discovered from Firebase Web App"
      source = "Automatically extracted from Firebase web app configuration"
      required = true
      note = "Passed to frontend via Cloud Build substitution (_FIREBASE_API_KEY). No manual population needed."
    }
    "FIREBASE_AUTH_DOMAIN" = {
      status = "✅ AUTO-AVAILABLE - Auto-discovered from Firebase Web App"
      source = "Automatically extracted from Firebase web app configuration"
      required = true
      note = "Passed to frontend via Cloud Build substitution (_FIREBASE_AUTH_DOMAIN). No manual population needed."
    }
    "FIREBASE_PROJECT_ID" = {
      status = "✅ AUTO-AVAILABLE - Auto-discovered from GCP Project"
      source = "GCP Project ID: ${var.gcp_project_id}"
      required = true
      note = "Passed to frontend via Cloud Build substitution (_FIREBASE_PROJECT_ID_SDK). No manual population needed."
    }
    "FIREBASE_STORAGE_BUCKET" = {
      status = "✅ AUTO-AVAILABLE - Auto-discovered from Firebase Web App"
      source = "Automatically extracted from Firebase web app configuration"
      required = true
      note = "Passed to frontend via Cloud Build substitution (_FIREBASE_STORAGE_BUCKET). No manual population needed."
    }
    "FIREBASE_MESSAGING_SENDER_ID" = {
      status = "✅ AUTO-AVAILABLE - Auto-discovered from Firebase Web App"
      source = "Automatically extracted from Firebase web app configuration"
      required = true
      note = "Passed to frontend via Cloud Build substitution (_FIREBASE_MESSAGING_SENDER_ID). No manual population needed."
    }
    "FIREBASE_MEASUREMENT_ID" = {
      status = "✅ AUTO-AVAILABLE - Auto-discovered from Firebase Web App (optional)"
      source = "Automatically extracted from Firebase web app configuration"
      required = false
      note = "Passed to frontend via Cloud Build substitution (_FIREBASE_MEASUREMENT_ID). Can be empty. No manual population needed."
    }
  }
}

output "all_secrets_reference" {
  description = "Complete reference matrix showing Firebase auto-discovery and OAuth manual setup"
  value = <<-EOT
┌──────────────────────────────────────────────────────────────────────────────────┐
│                         🔐 ALL SECRETS REFERENCE MATRIX                          │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│ FIREBASE SDK SECRETS (6 total) - AUTO-DISCOVERED & AUTO-INJECTED                │
│ ────────────────────────────────────────────────────────────────────────────── │
│ ✅ FIREBASE_API_KEY           → Auto-discovered, passed via substitution         │
│ ✅ FIREBASE_AUTH_DOMAIN       → Auto-discovered, passed via substitution         │
│ ✅ FIREBASE_PROJECT_ID        → Auto-discovered, passed via substitution         │
│ ✅ FIREBASE_STORAGE_BUCKET    → Auto-discovered, passed via substitution         │
│ ✅ FIREBASE_MESSAGING_SENDER_ID → Auto-discovered, passed via substitution      │
│ ✅ FIREBASE_MEASUREMENT_ID    → Auto-discovered, passed via substitution         │
│                                                                                  │
│ OAUTH AUTHENTICATION SECRETS (2 total) - MANUAL SETUP REQUIRED                   │
│ ────────────────────────────────────────────────────────────────────────────── │
│ ⚠️  GOOGLE_CLIENT_ID          → Manual: Create OAuth Client ID in GCP Console   │
│ ⚠️  GOOGLE_TOKEN_AUDIENCE     → Manual: Set equal to GOOGLE_CLIENT_ID value     │
│                                                                                  │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│ DEPLOYMENT TIMELINE:                                                            │
│                                                                                  │
│ 1. ✅ terraform apply                                                            │
│    → Firebase web app auto-discovered via Terraform                             │
│    → Firebase SDK config extracted and stored for Cloud Build                   │
│    → Only OAuth secrets created as placeholders in Secret Manager               │
│                                                                                  │
│ 2. ⚠️  STEP 1: Configure OAuth Secrets (Required)                                │
│    → Create OAuth Client ID in GCP Console                                      │
│    → Set GOOGLE_CLIENT_ID to the created OAuth Client ID                        │
│    → Set GOOGLE_TOKEN_AUDIENCE to same value as GOOGLE_CLIENT_ID                │
│    → Progress: 2/2 OAuth secrets populated                                      │
│                                                                                  │
│ 3. ✅ STEP 2: Firebase SDK Config Auto-Ready                                     │
│    → Terraform has already auto-discovered Firebase SDK values                  │
│    → Cloud Build will inject these values as _FIREBASE_* substitutions          │
│    → No manual population needed for Firebase secrets!                          │
│                                                                                  │
│ 4. ✅ STEP 3: Trigger Frontend Build                                             │
│    → Only proceed after OAuth secrets are populated (step 1)                     │
│    → Cloud Build will inject:                                                   │
│      - Firebase SDK config via substitutions                                    │
│      - OAuth credentials from Secret Manager                                    │
│    → Frontend deployment complete ✅                                             │
│                                                                                  │
│ RESULT:                                                                          │
│ • Firebase SDK configuration guaranteed via Terraform                            │
│ • OAuth secrets properly secured in Secret Manager                               │
│ • Frontend built with valid Firebase SDK + OAuth config                          │
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
