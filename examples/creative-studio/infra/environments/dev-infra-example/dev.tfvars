gcp_project_id = "YOUR_GCP_PROJECT_ID"
gcp_region     = "us-central1"
environment    = "development"

# --- Firebase Configuration (PHASE 1: AUTO-DISCOVERY) ---
# Firebase web app ID for auto-discovering SDK configuration
# Find via: gcloud firebase apps list --project=YOUR_GCP_PROJECT_ID
# Format: '1:PROJECT_NUMBER:web:HASH' (e.g., '1:123456789:web:abc123xyz')
# Firebase SDK secrets (API_KEY, AUTH_DOMAIN, etc.) are now AUTO-DISCOVERED!
firebase_web_app_id = "YOUR_FIREBASE_WEB_APP_ID"

# --- Service Names ---
backend_service_name  = "cstudio-backend-dev"
frontend_service_name = "cstudio-frontend-dev"

# --- GitHub Repo Details ---
github_conn_name   = "gh-repo-owner-con"
github_repo_owner  = "RepoOwnerName"
github_repo_name   = "repo-owner-vertex-ai-creative-studio"
github_branch_name = "develop"

# --- Custom Audiences ---
# AUTO-POPULATED: GCP Project ID is always included
# OPTIONAL: OAuth Client ID added later in Phase 3 when Firebase is ready
backend_custom_audiences  = []  # Will auto-include gcp_project_id + optional OAuth Client ID
frontend_custom_audiences = []  # Will auto-include gcp_project_id + optional OAuth Client ID

# --- Backend Environment Variables ---
# Flat map of environment variables for the backend service.
# Each environment directory provides its own flat configuration.
#
# BUILT-IN (Auto-Set by Terraform, DO NOT CHANGE):
#   - CORS_ORIGINS: Auto-populated with Frontend URL
#   - GENMEDIA_BUCKET: Auto-populated with storage bucket name
#   - SIGNING_SA_EMAIL: Auto-populated with service account email
#
# CHANGE AS NEEDED:
#   - LOG_LEVEL: Logging level (INFO, DEBUG, WARNING)
#   - ENVIRONMENT: Current environment name
#   - FIREBASE_DB: Your Firestore database name
#   - IDENTITY_PLATFORM_ALLOWED_ORGS: Comma-separated org list or empty for any

be_env_vars = {
  LOG_LEVEL                       = "INFO"
  ENVIRONMENT                     = "development"
  FIREBASE_DB                     = "cstudio-development"
  IDENTITY_PLATFORM_ALLOWED_ORGS  = ""
}

be_build_substitutions = {
  # Add any backend-specific build substitutions here
}

fe_build_substitutions = {
  _ANGULAR_BUILD_COMMAND = "build-dev"
}

# --- Cloud Run Resource Sizing ---
be_cpu    = "2000m"    # Backend CPU (default: 2 CPUs)
be_memory = "2048Mi"   # Backend Memory (default: 2 GB)
fe_cpu    = "2000m"    # Frontend CPU (default: 2 CPUs)
fe_memory = "2048Mi"   # Frontend Memory (default: 2 GB)

# --- Frontend Secrets ---
# Firebase SDK secrets (API_KEY, AUTH_DOMAIN, PROJECT_ID, STORAGE_BUCKET, MESSAGING_SENDER_ID, MEASUREMENT_ID)
# are now AUTO-DISCOVERED from the Firebase web app configuration via firebase_web_app_id.
# Only specify ADDITIONAL secrets needed beyond the standard Firebase SDK config
frontend_secrets_additional = [
  "GOOGLE_CLIENT_ID",  # Your Google OAuth 2.0 Client ID for web (if using OAuth)
]

# --- Backend Secrets ---
backend_secrets = [
  "GOOGLE_TOKEN_AUDIENCE",  # JWT audience for backend API authentication
]

backend_runtime_secrets = {
  "GOOGLE_TOKEN_AUDIENCE" = "GOOGLE_TOKEN_AUDIENCE"
}

# Identity Platform configuration is managed via GCP Console (sign-in methods, OAuth settings, etc.)

# --- Bootstrap Job Environment Variables ---
bootstrap_job_env_vars = {}

# --- Cloud Run Access Control ---
# List of identities that can invoke the backend Cloud Run service
# Leave empty to allow public access (allUsers)
# Examples:
#   - "user:john@example.com"
#   - "group:developers@example.com"
#   - "serviceAccount:backend-sa@project.iam.gserviceaccount.com"
#
# Note: This controls who can invoke the service via API
# Authentication (Identity Platform) is configured separately via identity_platform_* variables
backend_invoker_identities = []

# --- VPC Configuration ---
vpc_enable                = false           # Set to true for private Cloud SQL
vpc_primary_subnet_cidr   = "10.0.0.0/24"   # Primary subnet CIDR
vpc_connector_subnet_cidr = "10.0.1.0/28"   # VPC Connector subnet CIDR

# --- Storage Configuration ---
storage_force_destroy            = true   # Allow bucket deletion (safe for dev/sandbox)
storage_cors_allowed_origins     = ["*"]  # Allow all origins for development

# --- Build & Deployment ---
enable_cloud_build                        = true    # Set to true to deploy services via Cloud Build
cloud_sql_public_ip_enabled               = true    # Set to false for private database access
cloud_sql_deletion_protection_enabled     = false   # Set to true for production
enable_identity_platform                  = true    # Set to true to enable Firebase Authentication
