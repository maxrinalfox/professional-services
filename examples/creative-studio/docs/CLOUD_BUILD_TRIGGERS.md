# Cloud Build Triggers Documentation

This document outlines all Cloud Build triggers used in the Creative Studio project, including their purpose, required environment variables, secrets, and execution flow.

**⚠️ CRITICAL:** Secrets and environment variables are created and managed via Terraform infrastructure (see `infra/modules/secret-manager/` and `infra/modules/platform/`).

**BEFORE PROCEEDING:** Read `infra/TERRAFORM_REVIEW.md` - it documents **4 CRITICAL Terraform issues** that will cause Cloud Build failures:
1. **Issue #1:** Hardcoded bootstrap trigger count - always creates trigger even when disabled
2. **Issue #2:** Missing bootstrap substitution variables - bootstrap job uses hardcoded sandbox values instead of actual environment
3. **Issue #3:** Hard-coded database secret ID - all environments share same secret
4. **Issue #4:** Missing bootstrap service account IAM permissions - bootstrap job can't access secrets

These Terraform issues directly prevent Cloud Build triggers from working correctly. See troubleshooting section below.

---

## 1. Backend Service Cloud Build Trigger

**File:** `backend/cloudbuild.yaml`

**Purpose:** Build and deploy the backend service to Cloud Run

**Trigger Configuration:**
- **Trigger on:** Push to configured branch when `backend/**` files change
- **Build Context:** `examples/creative-studio/backend`

### Steps Execution Flow

| Step | Name | Action | Dependencies |
|------|------|--------|---------------|
| 1 | Build | Build Docker image using `Dockerfile.backend` | None |
| 2 | Push | Push image to Google Artifact Registry | Completed Step 1 |
| 3 | Deploy | Deploy to Cloud Run service | Completed Step 2 |

### Environment Variables (Substitutions)

| Variable | Default Value | Purpose | Required |
|----------|---------------|---------|----------|
| `_SERVICE_NAME` | `creative-studio-backend` | Cloud Run service name | Yes |
| `_REPO_NAME` | `cs-be-development-repo` | Artifact Registry repository | Yes |
| `_REGION` | `us-central1` | GCP region for deployment | Yes |

### Secrets Required

**None** - This trigger does not require any secrets from Secret Manager

### Auto-Substituted Variables

| Variable | Description |
|----------|-------------|
| `$PROJECT_ID` | Cloud Build's current GCP project ID |
| `$SHORT_SHA` | Short commit SHA (first 7 characters) |

### Deployment Method

- **Registry:** Google Artifact Registry (`${_REGION}-docker.pkg.dev`)
- **Deployment Target:** Cloud Run service
- **Image Tag:** `${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO_NAME}/${_SERVICE_NAME}:$SHORT_SHA`

---

## 2. Backend Bootstrap Cloud Build Trigger

**File:** `backend/cloudbuild-bootstrap.yaml`

**Purpose:** Build bootstrap container, push to registry, and execute database initialization (migrations, seeding, asset creation)

**Trigger Configuration:**
- **Trigger on:** Push to configured branch when `backend/bootstrap/**` files change
- **Build Context:** `examples/creative-studio/backend`

### Steps Execution Flow

| Step | Name | Action | Dependencies |
|------|------|--------|---------------|
| 1 | Build Bootstrap Image | Build Docker image using `Dockerfile.bootstrap` | None |
| 2 | Push Bootstrap Image | Push image to Google Artifact Registry | Completed Step 1 |
| 3 | Update Job Image | Create or update Cloud Run Job with new image | Completed Step 2 |
| 4 | Execute Bootstrap Job | Execute the Cloud Run Job and wait for completion | Completed Step 3 |

### Environment Variables (Substitutions)

| Variable | Default Value | Purpose | Required |
|----------|---------------|---------|----------|
| `_BOOTSTRAP_IMAGE_NAME` | `cstudio-bootstrap` | Bootstrap container image name | Yes |
| `_REPO_NAME` | `cs-bootstrap-sandbox-repo` | Artifact Registry repository | Yes |
| `_REGION` | `us-central1` | GCP region for deployment | Yes |
| `_BOOTSTRAP_JOB_NAME` | `cstudio-bootstrap-sandbox` | Cloud Run Job name | Yes |
| `_BOOTSTRAP_SERVICE_ACCOUNT` | `cs-bootstrap-sandbox@${PROJECT_ID}.iam.gserviceaccount.com` | Service account for job execution | Yes |
| `_VPC_CONNECTOR_NAME` | `cs-sandbox-cs-connector` | VPC Connector for private Cloud SQL access | Yes |
| `_CLOUD_SQL_INSTANCE` | `${PROJECT_ID}:us-central1:creative-studio-db-c3353262` | Cloud SQL instance connection string | Yes |
| `_BOOTSTRAP_CPU` | `2` | CPU cores for bootstrap job | Yes |
| `_BOOTSTRAP_MEMORY` | `4Gi` | Memory allocation for bootstrap job | Yes |
| `_BOOTSTRAP_TIMEOUT` | `3600` | Job timeout in seconds (1 hour) | Yes |

### Environment Variables (Bootstrap Job Runtime)

| Variable | Default Value | Purpose | Used By |
|----------|---------------|---------|---------|
| `ADMIN_USER_EMAIL` | `admin@example.com` | Email for initial admin user | Bootstrap script |
| `LOG_LEVEL` | `INFO` | Application logging level | Bootstrap script |
| `ENVIRONMENT` | `sandbox` | Environment identifier | Bootstrap script |
| `INSTANCE_CONNECTION_NAME` | `${PROJECT_ID}:us-central1:creative-studio-db-c3353262` | Cloud SQL connection name | Bootstrap script |
| `USE_CLOUD_SQL_PRIVATE_IP` | `false` | Use private IP for Cloud SQL | Bootstrap script |

### Secrets Required

| Secret Name | Secret Manager Path | Purpose | Used By |
|-------------|-------------------|---------|---------|
| `DB_PASS` | `projects/${PROJECT_ID}/secrets/creative-studio-db-password/versions/latest` | Cloud SQL database password | Bootstrap script |

### Auto-Substituted Variables

| Variable | Description |
|----------|-------------|
| `$PROJECT_ID` | Cloud Build's current GCP project ID |
| `$SHORT_SHA` | Short commit SHA (first 7 characters) |

### Deployment Method

- **Registry:** Google Artifact Registry
- **Deployment Target:** Cloud Run Job
- **Execution:**
  - Creates job on first run with full configuration from Terraform
  - Updates only the container image on subsequent runs
  - Waits for job completion before build completes

---

## 3. Frontend Build Trigger

**File:** `frontend/cloudbuild.yaml`

**Purpose:** Build the Angular frontend application and trigger deployment

**Trigger Configuration:**
- **Trigger on:** Push to configured branch when `frontend/**` files change
- **Build Context:** Root directory of repository

### Steps Execution Flow

| Step | Name | Action | Dependencies |
|------|------|--------|---------------|
| 1 | Install Dependencies | Run `npm ci` in frontend directory | None |
| 2 | Build Angular | Run Angular build command based on environment | Completed Step 1 |
| 3 | Trigger Deployment | Trigger deployment cloud build in target project | Completed Step 2 |

### Environment Variables (Substitutions)

| Variable | Default Value | Purpose | Required |
|----------|---------------|---------|----------|
| `_TARGET_PROJECT_ID` | `creative-studio-dev` | Target GCP project for deployment | Yes |
| `_ANGULAR_BUILD_COMMAND` | `build-dev` | Angular build script command | Yes |
| `_FIREBASE_PROJECT_ID` | `creative-studio-dev` | Firebase project ID | Yes |

### Secrets Required

**None** - This trigger does not require any secrets. Secrets are injected in the deployment trigger.

### Deployment Method

- **Method:** Triggers `frontend/cloudbuild-deploy.yaml` in target project asynchronously
- **Pass-through Variables:** `_FIREBASE_PROJECT_ID`

---

## 4. Frontend Deploy Cloud Build Trigger

**File:** `frontend/cloudbuild-deploy.yaml`

**Purpose:** Inject Firebase/Google configuration, build Angular app, and deploy to Firebase Hosting

**Trigger Configuration:**
- **Trigger on:** Triggered by build #3 (Frontend Build Trigger)
- **Build Context:** Root directory of repository

### Steps Execution Flow

| Step | Name | Action | Dependencies |
|------|------|--------|---------------|
| 1 | Install Dependencies | Run `npm ci` in frontend directory | None |
| 2 | Inject Environment Variables | Replace placeholders with secrets and config values | Completed Step 1 |
| 3 | Build Angular App | Run Angular production build | Completed Step 2 |
| 4 | Deploy to Firebase Hosting | Deploy built app to Firebase Hosting | Completed Step 3 |

### Environment Variables (Passed from Build Trigger)

| Variable | Purpose | Source |
|----------|---------|--------|
| `_BACKEND_URL` | Backend API base URL | Trigger substitution |
| `_FE_SERVICE_NAME` | Frontend service name | Trigger substitution |
| `_BACKEND_SERVICE_ID` | Backend service ID for Firebase config | Trigger substitution |

### Secrets Required

All secrets are retrieved from Google Cloud Secret Manager:

| Secret Name | Secret Manager Path | Injected Into | Purpose |
|-------------|-------------------|----------------|---------|
| `GOOGLE_CLIENT_ID` | `projects/${PROJECT_ID}/secrets/GOOGLE_CLIENT_ID/versions/latest` | `environment.prod.ts` | Google OAuth client ID |
| `FIREBASE_API_KEY` | `projects/${PROJECT_ID}/secrets/FIREBASE_API_KEY/versions/latest` | `environment.prod.ts` | Firebase API key |
| `FIREBASE_AUTH_DOMAIN` | `projects/${PROJECT_ID}/secrets/FIREBASE_AUTH_DOMAIN/versions/latest` | `environment.prod.ts` | Firebase auth domain |
| `FIREBASE_PROJECT_ID` | `projects/${PROJECT_ID}/secrets/FIREBASE_PROJECT_ID/versions/latest` | `environment.prod.ts` | Firebase project ID |
| `FIREBASE_STORAGE_BUCKET` | `projects/${PROJECT_ID}/secrets/FIREBASE_STORAGE_BUCKET/versions/latest` | `environment.prod.ts` | Firebase storage bucket |
| `FIREBASE_MESSAGING_SENDER_ID` | `projects/${PROJECT_ID}/secrets/FIREBASE_MESSAGING_SENDER_ID/versions/latest` | `environment.prod.ts` | Firebase messaging sender ID |
| `FIREBASE_APP_ID` | `projects/${PROJECT_ID}/secrets/FIREBASE_APP_ID/versions/latest` | `environment.prod.ts` | Firebase app ID |
| `FIREBASE_MEASUREMENT_ID` | `projects/${PROJECT_ID}/secrets/FIREBASE_MEASUREMENT_ID/versions/latest` | `environment.prod.ts` | Google Analytics measurement ID |

### Configuration Injection Details

**Step 2 (Inject Environment Variables)** replaces placeholders in two files:

1. **`src/environments/environment.prod.ts`** - Placeholders replaced:
   - `BACKEND_URL_PLACEHOLDER` → `${_BACKEND_URL}/api`
   - `GOOGLE_CLIENT_ID_PLACEHOLDER` → `${GOOGLE_CLIENT_ID}`
   - `FIREBASE_API_KEY_PLACEHOLDER` → `${FIREBASE_API_KEY}`
   - `FIREBASE_AUTH_DOMAIN_PLACEHOLDER` → `${FIREBASE_AUTH_DOMAIN}`
   - `FIREBASE_PROJECT_ID_PLACEHOLDER` → `${FIREBASE_PROJECT_ID}`
   - `FIREBASE_STORAGE_BUCKET_PLACEHOLDER` → `${FIREBASE_STORAGE_BUCKET}`
   - `FIREBASE_SENDER_ID_PLACEHOLDER` → `${FIREBASE_MESSAGING_SENDER_ID}`
   - `FIREBASE_APP_ID_PLACEHOLDER` → `${FIREBASE_APP_ID}`
   - `FIREBASE_MEASUREMENT_ID_PLACEHOLDER` → `${FIREBASE_MEASUREMENT_ID}`

2. **`firebase.json`** - Placeholders replaced:
   - `SITE_ID_PLACEHOLDER` → `${PROJECT_ID}`
   - `BACKEND_SERVICE_ID_PLACEHOLDER` → `${_BACKEND_SERVICE_ID}`

### Auto-Substituted Variables

| Variable | Description |
|----------|-------------|
| `$PROJECT_ID` | Cloud Build's current GCP project ID |

### Deployment Method

- **Target:** Firebase Hosting
- **Authentication:** Uses Firebase token (stored in Cloud Build environment)
- **Deployment Command:** `firebase deploy --project=${PROJECT_ID} --only=hosting:${PROJECT_ID} --non-interactive`

---

## Secret Management Summary

### Secrets Creation and Management via Terraform

All secrets are created and managed through the Terraform infrastructure code. The configuration is split into two key modules:

#### 1. Secret Creation Module
**Location:** `infra/modules/secret-manager/`

This module:
- Creates Google Cloud Secret Manager resources for each secret
- Sets up placeholder secret versions (which are updated manually or via pipeline)
- Grants IAM permissions to specified service accounts

**Key Resources:**
- `google_secret_manager_secret` - Creates the secret container
- `google_secret_manager_secret_iam_member` - Grants `roles/secretmanager.secretAccessor` to Cloud Build service account
- `google_secret_manager_secret_version` - Creates placeholder versions

**Module Configuration:**
```hcl
module "secret_manager" {
  source = "../../modules/secret-manager"

  gcp_project_id    = var.gcp_project_id
  secret_names      = var.frontend_secrets_additional  # e.g., ["GOOGLE_CLIENT_ID", ...]
  accessor_sa_email = google_service_account.cloud_build.member
}
```

#### 2. Platform Module Configuration
**Location:** `infra/modules/platform/`

Configures Cloud Build triggers with secret references through:
- `frontend_secrets_additional` - Additional secrets beyond Firebase SDK (e.g., GOOGLE_CLIENT_ID)
- `backend_secrets` - Build-time secrets for backend
- `backend_runtime_secrets` - Runtime secrets mounted into backend container

### Required Secrets in Google Cloud Secret Manager

**Backend Bootstrap Job (Runtime):**
- `creative-studio-db-password` - Cloud SQL database password
  - Path: `projects/${PROJECT_ID}/secrets/creative-studio-db-password/versions/latest`
  - Terraform Variable: `bootstrap_job_secrets`

**Frontend Deployment (Build-time):**
These are auto-discovered from Firebase web app configuration + additional secrets:
- `GOOGLE_CLIENT_ID` - Google OAuth credentials
  - Path: `projects/${PROJECT_ID}/secrets/GOOGLE_CLIENT_ID/versions/latest`
  - Terraform Variable: `frontend_secrets_additional = ["GOOGLE_CLIENT_ID"]`

- `FIREBASE_API_KEY` - Firebase API key (auto-discovered)
- `FIREBASE_AUTH_DOMAIN` - Firebase auth domain (auto-discovered)
- `FIREBASE_PROJECT_ID` - Firebase project ID (auto-discovered)
- `FIREBASE_STORAGE_BUCKET` - Firebase storage bucket (auto-discovered)
- `FIREBASE_MESSAGING_SENDER_ID` - Firebase messaging sender (auto-discovered)
- `FIREBASE_APP_ID` - Firebase app ID (auto-discovered)
- `FIREBASE_MEASUREMENT_ID` - Analytics ID (auto-discovered)

**Total:** 9 secrets across all triggers

### How Terraform Creates and Manages These Secrets

#### Step 1: Define Secret Names in Environment Variables
**File:** `infra/environments/prod_ops_sandbox/variables.tf`
```hcl
variable "frontend_secrets_additional" {
  type        = list(string)
  default     = ["GOOGLE_CLIENT_ID"]
  description = "Additional secret names beyond Firebase SDK config"
}

variable "backend_runtime_secrets" {
  type        = map(string)
  description = "Secrets to mount in backend container at runtime"
}
```

#### Step 2: Create Secrets and Grant Permissions
The secret-manager module creates each secret and grants the Cloud Build service account access:

```hcl
resource "google_secret_manager_secret" "this" {
  project   = var.gcp_project_id
  secret_id = "GOOGLE_CLIENT_ID"  # Example

  replication {
    auto {}  # Auto-replicate across regions
  }
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  secret_id = google_secret_manager_secret.this.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:cloud-builds@${PROJECT_ID}.iam.gserviceaccount.com"
}

resource "google_secret_manager_secret_version" "this" {
  secret      = google_secret_manager_secret.this.id
  secret_data = "placeholder_will_be_updated"

  lifecycle {
    # Don't overwrite on subsequent applies - allows manual updates
    ignore_changes = [secret_data]
  }
}
```

#### Step 3: Update Secret Values (Post-Terraform)
After Terraform creates the secrets, update the actual values:

```bash
# For Firebase secrets (auto-discovered from Firebase web app)
gcloud secrets versions add FIREBASE_API_KEY \
  --data-file=- <<< "YOUR_FIREBASE_API_KEY"

# For Google Client ID
gcloud secrets versions add GOOGLE_CLIENT_ID \
  --data-file=- <<< "YOUR_GOOGLE_CLIENT_ID"

# For database password
gcloud secrets versions add creative-studio-db-password \
  --data-file=- <<< "YOUR_DB_PASSWORD"
```

### Troubleshooting Secret Access Errors

**Error:** `Permission 'secretmanager.versions.access' denied for resource`

**Causes:**
1. Secret doesn't exist - Check `infra/environments/prod_ops_sandbox/variables.tf` to ensure secret name is in the list
2. Service account doesn't have permission - Cloud Build service account must have `roles/secretmanager.secretAccessor`
3. Secret has no versions - Each secret must have at least one version with actual data

**Resolution:**
1. Verify Terraform has been applied: `terraform apply` in `infra/environments/prod_ops_sandbox/`
2. Check Cloud Build service account permissions:
   ```bash
   gcloud projects get-iam-policy PROJECT_ID \
     --flatten="bindings[].members" \
     --filter="bindings.role:roles/secretmanager.secretAccessor"
   ```
3. Ensure secret versions exist:
   ```bash
   gcloud secrets list --project=PROJECT_ID
   gcloud secrets versions list SECRET_NAME --project=PROJECT_ID
   ```
4. Update secret value if using placeholder:
   ```bash
   gcloud secrets versions add SECRET_NAME \
     --data-file=- <<< "ACTUAL_VALUE" \
     --project=PROJECT_ID
   ```

---

## Environment Variables by Stage

### Development Environment (`_ANGULAR_BUILD_COMMAND: build-dev`)
- Uses `creative-studio-dev` project
- Deploys to dev Firebase project
- Dev backend URL configuration

### Production Environment (`_ANGULAR_BUILD_COMMAND: build-prod`)
- Uses appropriate production project
- Deploys to production Firebase project
- Production backend URL configuration

---

## Trigger Dependencies

```
Frontend Build (cloudbuild.yaml)
    ↓
Frontend Deploy (cloudbuild-deploy.yaml)
    ↓
Firebase Hosting

Backend Build (cloudbuild.yaml)
    ↓
Cloud Run Service

Backend Bootstrap (cloudbuild-bootstrap.yaml)
    ↓
Cloud Run Job (Database Setup)
    ↓
Executes: Migrations, Seeding, Admin Creation
```

---

## Complete Cloud Build to Terraform Configuration Mapping

### How Secrets Flow From Terraform to Cloud Build

```
┌─────────────────────────────────────────────────────────────┐
│  Terraform Infrastructure Code                              │
│  Location: infra/environments/prod_ops_sandbox/             │
└─────────────────────────────────────────────────────────────┘
         │
         ├─→ variables.tf
         │   ├─ frontend_secrets_additional = ["GOOGLE_CLIENT_ID"]
         │   ├─ backend_runtime_secrets = { "DB_PASS": "db-password" }
         │   └─ firebase_web_app_id = "1:123:web:abc"
         │
         ├─→ main.tf
         │   └─ module "secret_manager" {}
         │   └─ module "platform" {}
         │
         └─→ Executes: terraform apply

┌─────────────────────────────────────────────────────────────┐
│  Google Cloud Secret Manager                                │
│  Created Resources:                                          │
│  - GOOGLE_CLIENT_ID (secret)                                │
│  - FIREBASE_* (secrets - auto-discovered or created)        │
│  - creative-studio-db-password (secret)                     │
│                                                              │
│  IAM Permissions:                                           │
│  - cloud-builds@PROJECT.iam.gserviceaccount.com             │
│    has roles/secretmanager.secretAccessor                   │
└─────────────────────────────────────────────────────────────┘
         │
         ├─→ Read by: Backend Bootstrap Trigger
         │   Available as: ${FIREBASE_APP_ID}, ${DB_PASS}, etc
         │
         └─→ Read by: Frontend Deploy Trigger
             Available as: secretEnv variables

┌─────────────────────────────────────────────────────────────┐
│  Cloud Build Triggers                                        │
│  Location: backend/cloudbuild*.yaml, frontend/cloudbuild*.yaml
│                                                              │
│  Secret References:                                         │
│  1. availableSecrets.secretManager[*].versionName           │
│     Example: projects/${PROJECT_ID}/secrets/GOOGLE_CLIENT_ID
│                                                              │
│  2. Step 2 uses secretEnv variables                         │
│     Example: - FIREBASE_API_KEY                             │
│                                                              │
│  3. Env var injected into step                              │
│     Example: - '$${FIREBASE_API_KEY}'                       │
└─────────────────────────────────────────────────────────────┘
```

### Configuration Hierarchy

```
Terraform Variables (infra/environments/prod_ops_sandbox/variables.tf)
    ↓
Terraform Modules (infra/modules/secret-manager/, platform/)
    ↓
Google Cloud Resources (Secret Manager, IAM)
    ↓
Cloud Build availableSecrets Configuration
    ↓
Cloud Build Step Environment Variables (secretEnv)
    ↓
Application Usage (environment.prod.ts, bootstrap script, etc)
```

### Step-by-Step Secret Setup Process

#### 1. Define Required Secrets in Terraform Variables
**File:** `infra/environments/prod_ops_sandbox/variables.tf`

```hcl
variable "frontend_secrets_additional" {
  default = ["GOOGLE_CLIENT_ID"]  # Add any additional secrets beyond Firebase SDK
}

variable "backend_runtime_secrets" {
  default = {
    "DB_PASS" = "creative-studio-db-password"  # Maps env var name to secret name
  }
}
```

#### 2. Apply Terraform Infrastructure
```bash
cd infra/environments/prod_ops_sandbox
terraform init
terraform plan
terraform apply
```

This creates:
- Secret containers in Google Cloud Secret Manager
- IAM bindings for Cloud Build service account
- Placeholder secret versions

#### 3. Populate Secret Values
```bash
# Update each secret with actual values
gcloud secrets versions add GOOGLE_CLIENT_ID \
  --data-file=- --project=PROJECT_ID <<< "actual_value"

gcloud secrets versions add creative-studio-db-password \
  --data-file=- --project=PROJECT_ID <<< "actual_password"

# Firebase secrets (auto-discovered or manually set)
gcloud secrets versions add FIREBASE_API_KEY \
  --data-file=- --project=PROJECT_ID <<< "actual_firebase_key"
```

#### 4. Verify Cloud Build Can Access Secrets
```bash
# Check Cloud Build service account has secretAccessor role
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/secretmanager.secretAccessor" \
  --filter="bindings.members:cloud-builds*"

# List all secrets
gcloud secrets list --project=PROJECT_ID

# Check secret versions exist
gcloud secrets versions list GOOGLE_CLIENT_ID --project=PROJECT_ID
```

#### 5. Cloud Build Triggers Access Secrets
Cloud Build steps reference secrets via:
- `availableSecrets.secretManager[*].versionName` - Where to get the secret
- `secretEnv[*]` - Which variables to expose to the step
- `$${SECRET_VAR}` - How to use in the step (note double `$$`)

### Trigger Configuration Checklist

Before enabling each trigger, ensure:

### Backend Service Trigger
- [ ] Artifact Registry repository exists: `${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}`
- [ ] Cloud Run service exists or will be created by trigger
- [ ] Appropriate IAM permissions on Cloud Build service account
- [ ] Terraform has been applied (if using infrastructure-as-code for setup)

### Backend Bootstrap Trigger
- [ ] Terraform has been applied to create secrets: `terraform apply` in `infra/environments/prod_ops_sandbox/`
- [ ] `creative-studio-db-password` secret exists in Secret Manager with actual value
- [ ] All environment variables in substitutions are correctly configured
- [ ] Cloud SQL instance exists and accessible
- [ ] VPC Connector configured if using private IP
- [ ] Bootstrap service account has Cloud SQL Client and Secret Accessor roles
- [ ] Verify Cloud Build service account can access secrets:
  ```bash
  gcloud secrets versions access latest --secret=creative-studio-db-password
  ```

### Frontend Build Trigger
- [ ] Target project ID is correct
- [ ] Angular build scripts exist in `package.json`
- [ ] No secrets required for this trigger (only build and package)

### Frontend Deploy Trigger
- [ ] Terraform has been applied to create frontend secrets
- [ ] All Firebase secrets exist in Secret Manager with actual values
- [ ] `GOOGLE_CLIENT_ID` secret exists with actual OAuth client ID
- [ ] Firebase project is configured and accessible
- [ ] Firebase Hosting is enabled for the project
- [ ] Cloud Build service account has Firebase and Secret Manager access
- [ ] Verify secrets are accessible:
  ```bash
  gcloud secrets list --project=PROJECT_ID | grep FIREBASE
  gcloud secrets versions list GOOGLE_CLIENT_ID --project=PROJECT_ID
  ```

### Critical Terraform Issues Preventing Cloud Build

**READ FIRST:** `infra/TERRAFORM_REVIEW.md` contains detailed analysis of 10 issues, **4 of which are CRITICAL** and will prevent Cloud Build triggers from working.

#### Terraform Issue #1: Hardcoded Bootstrap Trigger Count

**Status:** ❌ **NOT YET FIXED** in your infrastructure

**Problem:** `modules/platform/cloud_build_trigger_bootstrap.tf:10` has `count = 1` (hardcoded)
- Bootstrap trigger is ALWAYS created, even when `enable_cloud_build=false`
- When `enable_cloud_build=false`, the bootstrap service account isn't created
- Terraform fails: `Index error: only 0 items in list when trying to access index 0`

**Current Impact:** You cannot disable the bootstrap trigger. Deployments with `enable_cloud_build=false` fail.

**Fix Required:**
```terraform
# Change from:
count = 1  # ❌ Hardcoded

# To:
count = (var.enable_cloud_build && var.enable_cloud_run_job) ? 1 : 0  # ✅ Conditional
```

See `infra/TERRAFORM_REVIEW.md:22-108` for complete fix.

---

#### Terraform Issue #2: Missing Bootstrap Substitution Variables

**Status:** ❌ **NOT YET FIXED** - This directly causes your Cloud Build failures

**Problem:** Terraform only passes 4 substitution variables to Cloud Build, but the YAML references 8 more with hardcoded values

**Your Current Frontend Error:**
```
ERROR: failed to access secret version for secret projects/YOUR_PROJECT_ID/secrets/FIREBASE_APP_ID
```

**Why It Happens:**
- `modules/platform/cloud_build_trigger_bootstrap.tf` doesn't pass `_BOOTSTRAP_SERVICE_ACCOUNT`, `_VPC_CONNECTOR_NAME`, `_CLOUD_SQL_INSTANCE`, etc.
- `backend/cloudbuild-bootstrap.yaml` uses hardcoded defaults (lines 120-147):
  ```yaml
  _BOOTSTRAP_SERVICE_ACCOUNT: 'cs-bootstrap-sandbox@${PROJECT_ID}.iam.gserviceaccount.com'  # ❌ Hardcoded "sandbox"
  _VPC_CONNECTOR_NAME: 'cs-sandbox-cs-connector'  # ❌ Hardcoded "sandbox"
  _CLOUD_SQL_INSTANCE: '${PROJECT_ID}:us-central1:creative-studio-db-c3353262'  # ❌ Hardcoded hash
  ```

**Your Scenario:**
- Deployed to `YOUR_PROJECT_ID` project
- Actual bootstrap service account: `cs-bootstrap-sandbox@YOUR_PROJECT_ID.iam.gserviceaccount.com`
- But it doesn't have permissions because Terraform wasn't configured correctly

**Fix Required:** Pass all 12 substitution variables from Terraform:
```terraform
substitutions = {
  _BOOTSTRAP_JOB_NAME        = var.bootstrap_job_name
  _BOOTSTRAP_IMAGE_NAME      = var.bootstrap_image_name
  _REPO_NAME                 = google_artifact_registry_repository.bootstrap_repo[0].repository_id
  _REGION                    = var.gcp_region
  _BOOTSTRAP_SERVICE_ACCOUNT = google_service_account.bootstrap_sa[0].email  # NEW
  _VPC_CONNECTOR_NAME        = var.vpc_enable ? module.vpc_network[0].vpc_connector_name : ""  # NEW
  _CLOUD_SQL_INSTANCE        = module.postgresql.connection_name  # NEW
  _BOOTSTRAP_CPU             = var.bootstrap_job_cpu  # NEW
  _BOOTSTRAP_MEMORY          = var.bootstrap_job_memory  # NEW
  _BOOTSTRAP_TIMEOUT         = var.bootstrap_job_timeout  # NEW
  _BOOTSTRAP_ENV_VARS        = join(",", [...])  # NEW
  _BOOTSTRAP_SECRETS         = join(",", [...])  # NEW
}
```

See `infra/TERRAFORM_REVIEW.md:112-293` for complete fix.

---

#### Terraform Issue #3: Hard-Coded Database Secret ID

**Status:** ✅ **FIXED** - Single project, no environment suffix needed

**Note:** Since you're not running multiple environments in the same GCP project, the database secret ID remains `creative-studio-db-password` without environment suffix.

**Final Code:**
```terraform
# modules/platform/main.tf
secret_id = "creative-studio-db-password"
db_secret_id = google_secret_manager_secret.db_password.secret_id
```

**One Project = One Secret:** This is the correct approach for your architecture where each GCP project contains a single environment.

---

#### Terraform Issue #4: Missing Bootstrap Service Account IAM Permissions

**Status:** ❌ **NOT YET FIXED** - Bootstrap job can't access secrets

**Problem:** Bootstrap service account is created but NOT granted `secretmanager.secretAccessor` role

**Current Code:** Missing IAM binding at `modules/platform/main.tf:460`

**Your Frontend Error Connection:**
This directly relates to why frontend deploy fails - the bootstrap job isn't properly configured by Terraform, so Cloud Build trigger references are wrong.

**Fix Required:**
```terraform
# Add this IAM binding for bootstrap secrets
resource "google_secret_manager_secret_iam_member" "bootstrap_runtime_secret_accessor" {
  for_each = var.enable_cloud_run_job ? var.bootstrap_job_secrets : {}

  provider  = google-beta
  project   = var.gcp_project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.bootstrap_sa[0].member
}
```

See `infra/TERRAFORM_REVIEW.md:411-507` for complete fix.

---

### Immediate Action Items

Before Cloud Build triggers will work, fix these Terraform issues in order:

1. **Apply Issue #1 fix** (5 min) - Fix bootstrap trigger count
2. **Apply Issue #2 fix** (30 min) - Pass all substitution variables
3. **Apply Issue #3 fix** (10 min) - Environment-specific secret IDs
4. **Apply Issue #4 fix** (10 min) - Bootstrap IAM permissions
5. **Apply Issue #7 fix** (20 min) - Pass bootstrap vars from environment configs
6. **Apply Issue #9 fix** (5 min) - Export VPC connector name

**Total time:** ~80 minutes to fix all CRITICAL + blocking issues

Then re-run:
```bash
cd infra/environments/prod_ops_sandbox
terraform apply
```

---

### Debugging Failed Cloud Build Triggers

**Error:** `Permission 'secretmanager.versions.access' denied`

**Root Causes:**
1. **Terraform Issues #2-4 not fixed** - Substitution variables and IAM permissions incorrect (MOST COMMON)
2. Secret doesn't exist - Check Terraform created it
3. Service account doesn't have permission - Check IAM bindings

**Diagnostic Steps:**
```bash
# Step 1: Verify Terraform applied successfully
cd infra/environments/prod_ops_sandbox
terraform apply
terraform show | grep google_secret_manager

# Step 2: Check if bootstrap service account exists and has permissions
gcloud iam service-accounts list | grep bootstrap
gcloud secrets get-iam-policy FIREBASE_APP_ID | grep bootstrap

# Step 3: Check Cloud Build service account permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/secretmanager.secretAccessor" | grep cloud-builds

# Step 4: Verify Cloud Build trigger substitutions
gcloud builds log TRIGGER_ID --stream=false | grep -A 20 "substitutions"

# Step 5: Check if secrets have actual values (not placeholders)
gcloud secrets versions access latest --secret=FIREBASE_APP_ID --project=PROJECT_ID
```

**Issue:** Terraform shows "count = 1" in cloud_build_trigger_bootstrap.tf

**Steps to resolve:**
1. Fix Terraform Issue #1 - Change hardcoded count to conditional
2. Fix Terraform Issue #2 - Add missing substitution variables
3. Fix Terraform Issue #3 - Environment-specific secret IDs
4. Fix Terraform Issue #4 - Bootstrap IAM permissions
5. Run: `terraform apply`

**Issue:** Secret placeholder data still showing

This is expected - Terraform creates placeholders to prevent overwriting manual updates. Update with actual data:
```bash
gcloud secrets versions add SECRET_NAME \
  --data-file=- --project=PROJECT_ID <<< "ACTUAL_VALUE"
```
