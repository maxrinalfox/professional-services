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

The frontend MUST wait for Firebase SDK secrets to be auto-populated by the bootstrap job.
If you rebuild frontend NOW, it will use empty/placeholder values and fail with "API key not valid".

WAIT FOR: The bootstrap job (cstudio-bootstrap-${var.environment}) to complete first.
See STEP 1 below to verify Bootstrap job completed successfully.

📋 STEP 1: VERIFY FIREBASE SDK SECRETS (Auto-populated by Bootstrap Job)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

These should be auto-populated by the bootstrap job. Monitor the job logs:

$ gcloud run jobs logs read cstudio-bootstrap-${var.environment} \
    --project=${var.gcp_project_id}

Expected to see:
✅ "Auto-discovered Firebase SDK configuration"
✅ "Admin user created"
✅ "Workspace created"

If the job failed or isn't running, see backend/BOOTSTRAP.md for debugging.


📋 STEP 2: CREATE OAUTH CLIENT ID (Required for Frontend Login)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This is CRITICAL for the frontend login to work. Without it, users cannot sign in.

1. Go to GCP Console:
   → APIs & Services → Credentials → Create Credentials → OAuth client ID

2. Choose: Web application

3. Add Authorized Redirect URIs:
   • https://${var.gcp_project_id}.firebaseapp.com/__/auth/handler
   • https://${var.gcp_project_id}.web.app/__/auth/handler

4. Copy the OAuth Client ID (looks like: 123456789-abcdefghijk.apps.googleusercontent.com)

5. Update the Secret in Secret Manager:
   $ gcloud secrets versions add GOOGLE_CLIENT_ID \
       --data-file=- --project=${var.gcp_project_id} \
       <<< "YOUR_OAUTH_CLIENT_ID"


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

  [ ] Step 1: Verified Firebase secrets are populated (check bootstrap logs)
  [ ] Step 2: Created OAuth Client ID in GCP Console
  [ ] Step 2: Updated GOOGLE_CLIENT_ID secret in Secret Manager
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
  description = "Secrets that need to be manually populated"
  value = {
    "GOOGLE_CLIENT_ID" = {
      description = "OAuth 2.0 Client ID for Google Sign-In"
      status = "⚠️  MANUAL - Must create OAuth Client ID in GCP Console and set manually"
      gcp_console_url = "https://console.cloud.google.com/apis/credentials?project=${var.gcp_project_id}"
      current_value = "placeholder_GOOGLE_CLIENT_ID_will_be_updated"
    }
  }
}

output "auto_populated_secrets" {
  description = "Secrets that are auto-populated by the bootstrap job"
  value = {
    "FIREBASE_API_KEY" = {
      status = "✅ AUTO - Populated by bootstrap job"
      populated_by = "Cloud Run Job: cstudio-bootstrap-${var.environment}"
    }
    "FIREBASE_AUTH_DOMAIN" = {
      status = "✅ AUTO - Populated by bootstrap job"
      populated_by = "Cloud Run Job: cstudio-bootstrap-${var.environment}"
    }
    "FIREBASE_PROJECT_ID" = {
      status = "✅ AUTO - Populated by bootstrap job"
      populated_by = "Cloud Run Job: cstudio-bootstrap-${var.environment}"
    }
    "FIREBASE_STORAGE_BUCKET" = {
      status = "✅ AUTO - Populated by bootstrap job"
      populated_by = "Cloud Run Job: cstudio-bootstrap-${var.environment}"
    }
    "FIREBASE_MESSAGING_SENDER_ID" = {
      status = "✅ AUTO - Populated by bootstrap job"
      populated_by = "Cloud Run Job: cstudio-bootstrap-${var.environment}"
    }
    "FIREBASE_MEASUREMENT_ID" = {
      status = "✅ AUTO - Populated by bootstrap job"
      populated_by = "Cloud Run Job: cstudio-bootstrap-${var.environment}"
    }
  }
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
