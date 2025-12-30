# Platform Module

## Overview

The platform module is the **main entry point and orchestration layer** for the entire Creative Studio infrastructure. It:
- Enables and manages GCP APIs
- Manages database passwords and secrets
- Orchestrates all sub-modules (core, services, data, networking, bootstrap)
- Handles cross-module IAM bindings and permissions
- Provides unified configuration interface

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│              Platform Module                                 │
│         (Service Orchestration Layer)                         │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ├─ APIs Enablement                                          │
│  │  └─ google_project_service (25+ GCP APIs)               │
│  │                                                           │
│  ├─ Database Secrets Management                             │
│  │  ├─ Random password generation                           │
│  │  └─ Secret Manager storage                              │
│  │                                                           │
│  ├─ Sub-module Orchestration                               │
│  │  ├─ module.firebase (Firebase project, web app)         │
│  │  ├─ module.storage (GCS, service accounts)              │
│  │  ├─ module.vpc_network (VPC, subnets, connectors)       │
│  │  ├─ module.postgresql (Cloud SQL database)              │
│  │  ├─ module.backend_service (Backend Cloud Run)          │
│  │  ├─ module.frontend_service (Frontend Cloud Run)        │
│  │  └─ module.bootstrap (Cloud Run Job)                    │
│  │                                                           │
│  └─ Cross-Module IAM Bindings                               │
│     ├─ Frontend trigger → view backend                      │
│     ├─ Backend → write to storage                           │
│     └─ Bootstrap → access database & storage               │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## Main.tf Structure

### 1. API Enablement

```hcl
locals {
  required_apis = [
    "firebase.googleapis.com",
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    # ... 20+ more APIs
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)
  # Enables each API
  # disable_on_destroy = false  # Keep APIs enabled after destroy
}

resource "time_sleep" "api_initialization" {
  # Wait 10 seconds for APIs to fully initialize
  # Critical for Identity Toolkit which requires delay
}
```

**Why This Matters**: GCP APIs take time to initialize. Without the delay, "SERVICE_DISABLED" errors occur even though the API is enabled.

### 2. Database Password Management

```hcl
resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "creative-studio-db-password"
  # User-managed replication for security
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}
```

**Why This Matters**: 
- Random password prevents hardcoding credentials
- Secret Manager secures password storage
- Automatically passed to Cloud SQL module
- Available to services and Cloud Build

### 3. Computed Locals for URLs & Configuration

```hcl
locals {
  # Backend URL computed from project number
  backend_url = "https://${var.backend_service_name}-${data.google_project.project.number}.${var.gcp_region}.run.app"
  
  # Frontend URL predictable from Firebase
  frontend_url = "https://${var.gcp_project_id}.web.app"
  
  # Firebase SDK config auto-discovered from Firebase module
  firebase_sdk_config = length(module.firebase.firebase_web_app_config) > 0 ? {
    FIREBASE_API_KEY             = module.firebase.firebase_web_app_config[0].api_key
    FIREBASE_AUTH_DOMAIN         = module.firebase.firebase_web_app_config[0].auth_domain
    # ... 5 more Firebase config values
  } : {}
  
  # Backend env vars computed with CORS origins, storage bucket, etc.
  backend_env_vars = merge(
    var.be_env_vars,
    {
      "CORS_ORIGINS"     = "[\"${local.frontend_url}\"]"
      "GENMEDIA_BUCKET"  = module.storage.bucket_name
      "SIGNING_SA_EMAIL" = module.storage.bucket_reader_sa_email
    }
  )
  
  # Source repo ID from Cloud Build connection (if enabled)
  source_repository_id = var.enable_cloud_build ? google_cloudbuildv2_repository.source_repo[0].id : ""
}
```

**Why This Matters**:
- Predictable URLs eliminate manual configuration
- Firebase config auto-discovery reduces manual setup
- Custom audiences auto-populated with project ID
- Reduces configuration errors

### 4. Module Calls (Orchestration)

```hcl
module "firebase" {
  source = "../core/firebase"
  # Provides: firebase_project_id, firebase_web_app_id, firebase_web_app_config
}

module "storage" {
  source = "../core/storage"
  # Provides: bucket_name, bucket_reader_sa_email
}

module "vpc_network" {
  count = var.vpc_enable ? 1 : 0  # Optional VPC
  source = "../networking"
  # Provides: network_id, vpc_connector_id, vpc_connector_name
}

module "postgresql" {
  source = "../data/postgresql"
  db_password = google_secret_manager_secret_version.db_password.secret_data
  # Provides: connection_name, db_name, db_user
}

module "backend_service" {
  source = "../services/backend"
  cloud_sql_connection_name = module.postgresql.connection_name
  db_secret_id = google_secret_manager_secret.db_password.secret_id
  # Provides: service_name, service_url, run_sa_member
}

module "frontend_service" {
  source = "../services/frontend"
  source_repository_id = local.source_repository_id
  build_substitutions = merge(var.fe_build_substitutions, {
    _BACKEND_URL         = local.backend_url
    _FIREBASE_APP_ID     = module.firebase.firebase_web_app_id
  })
  # Provides: service_name, url, trigger_sa_member
}

module "bootstrap" {
  source = "../bootstrap"
  cloud_sql_connection_name = module.postgresql.connection_name
  genmedia_bucket_name = module.storage.bucket_name
  # Provides: bootstrap_sa_email, bootstrap_repo_name
}
```

### 5. Centralized Secrets Management

```hcl
module "app_secrets" {
  source = "../core/secrets"

  secrets_config = {
    # Unified OAuth credential used by both frontend and backend
    "OAUTH_CLIENT_ID" = {
      description = "OAuth 2.0 Client ID for frontend and backend"
      accessors = [
        # Frontend Cloud Build needs access to inject into build
        module.frontend_service.trigger_sa_member,
        # Backend Cloud Build needs access to validate during build
        module.backend_service.trigger_sa_member,
        # Backend Cloud Run needs access to read at runtime
        module.backend_service.run_sa_member,
      ]
    }
  }

  depends_on = [
    module.frontend_service,
    module.backend_service
  ]
}
```

**Why This Matters**:
- Single source of truth for secret-to-service-account mapping
- Centralized permission granting for all application secrets
- Automatic IAM binding management
- Supports multiple service accounts per secret

### 6. Cross-Module IAM Bindings

```hcl
# Frontend trigger can query backend health
resource "google_cloud_run_v2_service_iam_member" "fe_trigger_can_view_backend" {
  count    = var.enable_cloud_build ? 1 : 0
  name     = module.backend_service.service_name
  role     = "roles/run.viewer"
  member   = module.frontend_service.trigger_sa_member
  depends_on = [module.backend_service, module.frontend_service]
}

# Backend can write to storage bucket
resource "google_storage_bucket_iam_member" "backend_sa_gcs_object_creator" {
  bucket = module.storage.bucket_name
  role   = "roles/storage.objectCreator"
  member = module.backend_service.run_sa_member
}

# Backend can read from storage
resource "google_project_iam_member" "backend_run_sa_bucket_reader" {
  project = var.gcp_project_id
  role    = "roles/storage.objectViewer"
  member  = module.backend_service.run_sa_member
}
```

**Why This Matters**:
- Centralizes all cross-module permissions
- Explicit dependency declarations prevent race conditions
- Clear audit trail of who has access to what
- Separated from secret management concerns

## Configuration Variables

### API & Project Configuration

```hcl
gcp_project_id              # GCP project ID
gcp_region                  # GCP region (e.g., "us-central1")
environment                 # Environment (e.g., "dev", "prod")
```

### GitHub & Cloud Build Configuration

```hcl
github_repo_owner           # GitHub org
github_repo_name            # Repository name
github_branch_name          # Branch for triggers (e.g., "main")
github_conn_name            # Cloud Build GitHub connection name
enable_cloud_build          # Enable CI/CD triggers (default: true)
```

### Service Configuration

```hcl
backend_service_name        # Cloud Run service name (e.g., "backend-api")
frontend_service_name       # Cloud Run service name (e.g., "frontend-app")
backend_custom_audiences    # OAuth audiences for backend
frontend_custom_audiences   # OAuth audiences for frontend
```

### Firebase Configuration

```hcl
firebase_web_app_id        # If manually created Firebase web app
enable_identity_platform    # Enable Firebase Authentication
enable_cloud_build          # Also controls Firebase creation
```

### Database Configuration

```hcl
cloud_sql_public_ip_enabled # Allow public IP access (dev)
vpc_enable                  # Enable VPC networking (prod)
```

### Bootstrap Configuration

```hcl
enable_cloud_run_job        # Enable bootstrap job
initial_admin_user_email    # Admin user email
bootstrap_job_name          # Job name (auto-generated)
bootstrap_image_name        # Docker image name
bootstrap_job_cpu           # CPU allocation (default: "2000m")
bootstrap_job_memory        # Memory allocation (default: "2048Mi")
bootstrap_job_timeout       # Job timeout (default: 3600)
```

### Build & Runtime Configuration

```hcl
be_build_substitutions      # Custom backend build variables
fe_build_substitutions      # Custom frontend build variables
be_env_vars                 # Backend environment variables (flat map)
bootstrap_job_env_vars      # Bootstrap job environment variables
bootstrap_job_secrets       # Bootstrap job secrets
```

**Note:** Application secrets (OAUTH_CLIENT_ID, database password) are now managed centrally by the `core/secrets` module and automatically granted to appropriate service accounts.

## Module Outputs

The platform module exports everything needed by environments:

```hcl
backend_service_url              # Backend Cloud Run service URL
frontend_service_url             # Frontend Cloud Run service URL
cloud_sql_connection_name        # Cloud SQL connection string
vpc_network_id                   # VPC network ID (if enabled)
vpc_connector_id                 # VPC connector ID (if enabled)
vpc_connector_name               # VPC connector name (if enabled)
firebase_project_id              # Firebase project ID
identity_platform_auth_domain    # Firebase auth domain
bootstrap_service_account_email  # Bootstrap SA email
bootstrap_artifact_repository    # Bootstrap Artifact Registry repo
```

## Dependency Management

### Dependency Chain

```
APIs Enabled (google_project_service)
        ↓
API Initialization (time_sleep)
        ├→ Firebase Module
        ├→ Storage Module
        ├→ VPC Network Module
        └→ PostgreSQL Module
                ├→ Backend Service
                ├→ Frontend Service
                └→ Bootstrap Module
```

All `depends_on` declarations explicitly managed to avoid:
- Race conditions
- API not ready errors
- Module initialization failures

## Best Practices Implemented

### 1. **Explicit Dependencies**
```hcl
depends_on = [
  google_project_service.apis,
  module.vpc_network,
  module.storage
]
```

### 2. **Conditional Resource Creation**
```hcl
count = var.enable_cloud_build ? 1 : 0
```

### 3. **Least Privilege IAM**
Each service account only has roles needed:
- Backend: `cloudsql.client`, `secretmanager.secretAccessor`, `storage.objectCreator`
- Frontend: `secretmanager.secretAccessor` (minimal)
- Bootstrap: `cloudsql.client`, `secretmanager.secretAccessor`, `storage.objectCreator`

### 4. **Configuration Externalization**
All variable values configurable via tfvars:
```hcl
be_env_vars = {
  "CUSTOM_VAR" = "value"
}
```

### 5. **Auto-Discovery Patterns**
Eliminates manual configuration:
- Firebase SDK config auto-discovered
- URLs computed from other resources
- Backend URL passed to frontend automatically

## Module Relationships Diagram

```
┌────────────────────────────────────────────────────────────┐
│ Platform Module                                            │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  ┌──────────────────┐                                     │
│  │ Core Module      │                                     │
│  │  ├─ Firebase ◄───┼─ Used by: Frontend               │
│  │  ├─ Storage  ◄───┼─ Used by: Backend, Bootstrap     │
│  │  └─ Project  ◄───┼─ APIs, secrets, config           │
│  └──────────────────┘                                     │
│           │                                               │
│           ├──────────────────────────┐                   │
│           │                          │                   │
│  ┌────────▼────────┐        ┌────────▼────────┐        │
│  │ Data Module     │        │ Networking      │        │
│  │  └─ PostgreSQL  ◄─┼─ Used by: Backend,  │        │
│  │                 │        │   Bootstrap     │        │
│  └─────────────────┘        └─────────────────┘        │
│           │                          │                   │
│           │                          ├──────────────┐   │
│           │                          │              │   │
│  ┌────────▼──────────────┬──────────▼────┐  ┌──────▼────┐
│  │ Backend Service       │ Frontend Svc   │  │ Bootstrap │
│  │ • Cloud Run API       │ • Cloud Run UI │  │ • Cloud   │
│  │ • Cloud Build Trigger │ • Cloud Build  │  │   Run Job │
│  │ • Service Account     │ • Service Acct │  │ • Cloud   │
│  └───────────────────────┴────────────────┘  │   Build   │
│           │                    │             │   Trigger │
│           └─────┬──────────────┘             └────┬──────┘
│                 │ Cross-module IAM bindings       │
│                 │ (Frontend can view Backend)     │
│                 ▼                                 ▼
│         (Outputs to Environment Modules)
│
└────────────────────────────────────────────────────────────┘
```

## Usage in Environments

Environment modules import platform:

```hcl
# infra/environments/dev-infra-example/main.tf
module "creative_studio_platform" {
  source = "../../modules/platform"
  
  gcp_project_id       = var.gcp_project_id
  gcp_region          = var.gcp_region
  environment         = var.environment
  
  # ... 50+ variable assignments
}
```

Then access outputs:

```hcl
# outputs.tf
output "backend_url" {
  value = module.creative_studio_platform.backend_service_url
}
```

## Troubleshooting

### API Not Ready

**Error**: "SERVICE_DISABLED: The service X is disabled for project..."

**Solution**: Increase `time_sleep` delay:
```hcl
resource "time_sleep" "api_initialization" {
  create_duration = "20s"  # Increase from 10s
}
```

### Database Password Not Found

**Error**: "Secret not found" when deploying backend

**Solution**: Ensure database secrets are created:
```bash
gcloud secrets list | grep db-password
```

### Cross-Module Variable Mismatch

**Error**: "got unexpected value type <different type>"

**Solution**: Check module output types:
```bash
terraform output -json module.backend_service.service_url
```

### Circular Dependencies

**Error**: "Cycle detected" in module graph

**Solution**: Use `depends_on` explicitly, avoid circular module references

## Performance Optimization

### Parallel Module Execution
Terraform automatically parallelizes modules with no dependencies:
- Firebase, Storage, VPC Network can initialize in parallel
- PostgreSQL waits for VPC (if enabled)
- Services wait for Core + Data modules

###  API Enablement Optimization
All APIs enabled in parallel via `for_each`:
- Typical time: 1-2 minutes for all 25+ APIs

## Cost Considerations

### Always-On Resources
- Firebase project (free tier)
- Cloud SQL instance (costs depend on size)
- Cloud Storage bucket (minimal storage cost)
- Cloud Run services (pay-per-request)

### Optional Resources
- VPC connector (can disable to reduce costs)
- Bootstrap job (only when triggered)
- Cloud Build (free tier for limited builds)

## Related Documentation

- [Backend Service Module](./services/backend/README.md)
- [Frontend Service Module](./services/frontend/README.md)
- [Bootstrap Module](./bootstrap/README.md)
- [Core Modules](./core/README.md)
- [Data Modules](./data/README.md)
- [Networking Module](./networking/README.md)
- [Cloud Build Triggers](../CLOUD_BUILD_TRIGGERS.md)
- [Architecture Overview](../ARCHITECTURE.md)
