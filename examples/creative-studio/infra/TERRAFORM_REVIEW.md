# Terraform Infrastructure Review - Detailed Issue Report

**Date:** December 26, 2025
**Scope:** Creative Studio Infrastructure (infra/)
**Status:** Critical issues requiring immediate attention

---

## Executive Summary

This review identified **4 critical issues** and **6 warnings** across the Terraform codebase that will cause deployment failures or runtime errors. The most critical issues involve:

1. **Hardcoded Cloud Build trigger count** - Will always create trigger even when disabled
2. **Missing bootstrap substitution variables** - Cloud Build job will use hardcoded values instead of dynamic infrastructure values
3. **Hard-coded database secret ID** - Multi-environment deployments will conflict
4. **Missing bootstrap service account IAM permissions** - Bootstrap job won't have secret access

---

## Critical Issues (Must Fix Before Deployment)

### Issue #1: Cloud Build Bootstrap Trigger - Hardcoded Count Logic

**Severity:** 🔴 CRITICAL - Will cause deployment failures

**Location:** `modules/platform/cloud_build_trigger_bootstrap.tf:10`

**Current Code:**
```terraform
resource "google_cloudbuild_trigger" "bootstrap" {
  count           = 1  # ❌ HARDCODED - IGNORES CONDITIONS
  name            = "cstudio-bootstrap-trigger"
  location        = var.gcp_region
  service_account = google_service_account.bootstrap_trigger_sa[0].id  # ❌ ALWAYS TRIES TO ACCESS [0]
  # ... rest of configuration
}
```

**Problem:**
- The `count = 1` is hardcoded, meaning the trigger will **ALWAYS be created**
- This ignores the conditional variables `enable_cloud_build` and `enable_cloud_run_job`
- The service account reference `google_service_account.bootstrap_trigger_sa[0]` assumes the service account exists
- When `enable_cloud_build = false` OR `enable_cloud_run_job = false`, the service account is NOT created (it has its own conditional count at line 526)
- **Result:** Terraform apply fails with error: `Index error on google_service_account.bootstrap_trigger_sa: only 0 items in list when trying to access index 0`

**Why This Matters:**
- Users may want to deploy infrastructure WITHOUT the bootstrap job (e.g., for development)
- The trigger should respect the `enable_cloud_build` and `enable_cloud_run_job` variables
- Currently, there's no way to disable this trigger

**Impact Scenarios:**

| Scenario | enable_cloud_build | enable_cloud_run_job | Result |
|----------|-------------------|----------------------|--------|
| Bootstrap disabled | false | false | ❌ FAILS - tries to create trigger without SA |
| Only build enabled | true | false | ❌ FAILS - trigger created but job bootstrap SA doesn't exist |
| Only job enabled | false | true | ❌ FAILS - trigger created but build conditions not met |
| Both enabled | true | true | ✅ WORKS |

**Fix:**

Replace the hardcoded count with the proper condition:

```terraform
resource "google_cloudbuild_trigger" "bootstrap" {
  count           = (var.enable_cloud_build && var.enable_cloud_run_job) ? 1 : 0  # ✅ Respect both conditions
  name            = "cstudio-bootstrap-trigger"
  location        = var.gcp_region
  service_account = google_service_account.bootstrap_trigger_sa[0].id
  filename        = "examples/creative-studio/backend/cloudbuild-bootstrap.yaml"
  project         = var.gcp_project_id

  repository_event_config {
    repository = local.source_repository_id
    push {
      branch = "^${var.github_branch_name}$"
    }
  }

  included_files = [
    "**/creative-studio/backend/bootstrap/**",
    "**/creative-studio/backend/Dockerfile.bootstrap",
    "**/creative-studio/backend/cloudbuild-bootstrap.yaml"
  ]

  substitutions = {
    _BOOTSTRAP_JOB_NAME   = var.bootstrap_job_name != null ? var.bootstrap_job_name : "cstudio-bootstrap-${var.environment}"
    _BOOTSTRAP_IMAGE_NAME = var.bootstrap_image_name
    _REPO_NAME            = google_artifact_registry_repository.bootstrap_repo[0].repository_id
    _REGION               = var.gcp_region
  }

  depends_on = [
    google_service_account.bootstrap_trigger_sa,
    google_artifact_registry_repository.bootstrap_repo
  ]
}
```

**Verification:**
After fix, test with:
```bash
# This should NOT create any trigger
terraform apply -var="enable_cloud_build=false" -var="enable_cloud_run_job=false"

# This should create the trigger
terraform apply -var="enable_cloud_build=true" -var="enable_cloud_run_job=true"
```

---

### Issue #2: Missing Bootstrap Substitution Variables in Cloud Build Trigger

**Severity:** 🔴 CRITICAL - Bootstrap job will use hardcoded values

**Location:** `modules/platform/cloud_build_trigger_bootstrap.tf:8-42` and `backend/cloudbuild-bootstrap.yaml:69-105`

**Problem:**

The Cloud Build trigger in Terraform only passes 4 substitution variables:

```terraform
substitutions = {
  _BOOTSTRAP_JOB_NAME   = var.bootstrap_job_name != null ? var.bootstrap_job_name : "cstudio-bootstrap-${var.environment}"
  _BOOTSTRAP_IMAGE_NAME = var.bootstrap_image_name
  _REPO_NAME            = google_artifact_registry_repository.bootstrap_repo[0].repository_id
  _REGION               = var.gcp_region
}
```

But the `cloudbuild-bootstrap.yaml` references 8 additional variables that default to hardcoded values:

| Variable | Current Hardcoded Value | Issue |
|----------|------------------------|-------|
| `_BOOTSTRAP_SERVICE_ACCOUNT` | `cs-bootstrap-sandbox@${PROJECT_ID}.iam.gserviceaccount.com` | References wrong environment name (hardcoded "sandbox") |
| `_VPC_CONNECTOR_NAME` | `cs-sandbox-cs-connector` | Hardcoded "sandbox", won't work in prod, dev, staging |
| `_CLOUD_SQL_INSTANCE` | `${PROJECT_ID}:us-central1:creative-studio-db-c3353262` | Instance hash `c3353262` changes on each terraform destroy/apply |
| `_BOOTSTRAP_CPU` | `2` | Should match `var.bootstrap_job_cpu` |
| `_BOOTSTRAP_MEMORY` | `4Gi` | Should match `var.bootstrap_job_memory` |
| `_BOOTSTRAP_TIMEOUT` | `3600` | Should match `var.bootstrap_job_timeout` |
| `_BOOTSTRAP_ENV_VARS` | Hardcoded with fixed connection name & env | Won't match actual database or environment |
| `_BOOTSTRAP_SECRETS` | `DB_PASS=creative-studio-db-password:latest` | Secret name hardcoded, no other secrets passed |

**Specific Examples from YAML:**

```yaml
# Line 93: Tries to use hardcoded VPC connector
--vpc-connector="projects/$PROJECT_ID/locations/${_REGION}/connectors/${_VPC_CONNECTOR_NAME}" \
# Problem: _VPC_CONNECTOR_NAME = 'cs-sandbox-cs-connector' but actual is 'cs-dev-cs-connector'

# Line 95: Hardcoded service account with wrong environment
--service-account='${_BOOTSTRAP_SERVICE_ACCOUNT}' \
# Problem: _BOOTSTRAP_SERVICE_ACCOUNT = 'cs-bootstrap-sandbox@...' but should be 'cs-bootstrap-dev@...'

# Line 96: Instance hash changes on each apply
--set-cloudsql-instances='${_CLOUD_SQL_INSTANCE}' \
# Problem: _CLOUD_SQL_INSTANCE hardcoded as '...creative-studio-db-c3353262'
# but actual hash from Terraform is different (e.g., 'a1b2c3d4')

# Line 144: Hardcoded environment and connection info
_BOOTSTRAP_ENV_VARS: 'ADMIN_USER_EMAIL=admin@example.com,LOG_LEVEL=INFO,ENVIRONMENT=sandbox,INSTANCE_CONNECTION_NAME=${PROJECT_ID}:us-central1:creative-studio-db-c3353262,USE_CLOUD_SQL_PRIVATE_IP=false'
# Problems:
# - ENVIRONMENT=sandbox (hardcoded, should be dev/prod/staging)
# - INSTANCE_CONNECTION_NAME has wrong hash
# - USE_CLOUD_SQL_PRIVATE_IP=false (should depend on vpc_enable)
```

**Impact:**

When Cloud Build executes the bootstrap trigger, it will attempt to:
1. ❌ Use the wrong VPC connector (won't find it, or uses wrong network isolation)
2. ❌ Use the wrong service account (wrong permissions)
3. ❌ Connect to wrong Cloud SQL instance (wrong hash, may not exist)
4. ❌ Set wrong environment variables (wrong app environment, wrong DB connection)
5. ❌ Not pass additional secrets the bootstrap job might need

**Deployment Scenario:**

```bash
# Deploy to dev environment
terraform apply -var="environment=dev" -var="enable_cloud_build=true" -var="enable_cloud_run_job=true"

# Terraform creates:
# - Service account: cs-bootstrap-dev (correct)
# - VPC connector: cs-dev-cs-connector (correct)
# - Cloud SQL instance: creative-studio-db-a1b2c3d4 (correct)

# But Cloud Build trigger uses:
# - Service account: cs-bootstrap-sandbox (WRONG)
# - VPC connector: cs-sandbox-cs-connector (WRONG)
# - Cloud SQL instance: creative-studio-db-c3353262 (WRONG)

# Result: Bootstrap job fails to execute
```

**Fix:**

Update `cloud_build_trigger_bootstrap.tf` to pass ALL required variables:

```terraform
resource "google_cloudbuild_trigger" "bootstrap" {
  count           = (var.enable_cloud_build && var.enable_cloud_run_job) ? 1 : 0
  name            = "cstudio-bootstrap-trigger"
  location        = var.gcp_region
  service_account = google_service_account.bootstrap_trigger_sa[0].id
  filename        = "examples/creative-studio/backend/cloudbuild-bootstrap.yaml"
  project         = var.gcp_project_id

  repository_event_config {
    repository = local.source_repository_id
    push {
      branch = "^${var.github_branch_name}$"
    }
  }

  included_files = [
    "**/creative-studio/backend/bootstrap/**",
    "**/creative-studio/backend/Dockerfile.bootstrap",
    "**/creative-studio/backend/cloudbuild-bootstrap.yaml"
  ]

  substitutions = {
    # ✅ ADD THESE MISSING VARIABLES
    _BOOTSTRAP_JOB_NAME        = var.bootstrap_job_name != null ? var.bootstrap_job_name : "cstudio-bootstrap-${var.environment}"
    _BOOTSTRAP_IMAGE_NAME      = var.bootstrap_image_name
    _REPO_NAME                 = google_artifact_registry_repository.bootstrap_repo[0].repository_id
    _REGION                    = var.gcp_region

    # ✅ NEW: Service account from Terraform
    _BOOTSTRAP_SERVICE_ACCOUNT = google_service_account.bootstrap_sa[0].email

    # ✅ NEW: VPC connector (only if VPC is enabled)
    _VPC_CONNECTOR_NAME        = var.vpc_enable ? module.vpc_network[0].vpc_connector_name : ""

    # ✅ NEW: Cloud SQL instance from Terraform
    _CLOUD_SQL_INSTANCE        = module.postgresql.connection_name

    # ✅ NEW: Resource allocation from variables
    _BOOTSTRAP_CPU             = var.bootstrap_job_cpu
    _BOOTSTRAP_MEMORY          = var.bootstrap_job_memory
    _BOOTSTRAP_TIMEOUT         = var.bootstrap_job_timeout

    # ✅ NEW: Environment variables from Terraform
    # Format: KEY1=value1,KEY2=value2
    _BOOTSTRAP_ENV_VARS        = join(",", concat(
      [
        "ENVIRONMENT=${var.environment}",
        "INSTANCE_CONNECTION_NAME=${module.postgresql.connection_name}",
        "USE_CLOUD_SQL_PRIVATE_IP=${var.vpc_enable ? "true" : "false"}",
        "DB_NAME=${module.postgresql.db_name}",
        "DB_USER=${module.postgresql.db_user}",
      ],
      [for k, v in var.bootstrap_job_environment_variables : "${k}=${v}"]
    ))

    # ✅ NEW: Secrets from Terraform
    # Format: KEY=secret-name:version
    _BOOTSTRAP_SECRETS         = join(",", concat(
      ["DB_PASS=creative-studio-db-password:latest"],
      [for env_var, secret_config in var.bootstrap_job_secrets : "${env_var}=${secret_config.secret_id}:latest"]
    ))
  }

  depends_on = [
    google_service_account.bootstrap_trigger_sa,
    google_artifact_registry_repository.bootstrap_repo,
    google_service_account.bootstrap_sa,
    module.postgresql
  ]
}
```

**Also required:** Export these values from VPC module

**File:** `modules/vpc_network/outputs.tf`
Add:
```terraform
output "vpc_connector_name" {
  description = "Name of the VPC Connector"
  value       = google_vpc_access_connector.default.name
}
```

**Verification:**

```bash
# After fix, verify substitutions are dynamic
terraform plan -var="environment=dev" -var="enable_cloud_build=true" -var="enable_cloud_run_job=true" | grep -A 20 "substitutions"

# Should show actual values like:
# _BOOTSTRAP_SERVICE_ACCOUNT = "cs-bootstrap-dev@project.iam.gserviceaccount.com"
# _CLOUD_SQL_INSTANCE = "project:us-central1:creative-studio-db-a1b2c3d4"
```

---

### Issue #3: Hard-Coded Database Secret ID

**Severity:** 🔴 CRITICAL - Multi-environment deployments will conflict

**Location:** `modules/platform/main.tf:317`

**Current Code:**
```terraform
module "backend_service" {
  source = "../cloud-run-service"

  # ... many variables ...

  # ❌ HARDCODED SECRET ID
  db_secret_id = "creative-studio-db-password"

  # ... rest of module ...
}
```

**Problem:**

The database password secret ID is hardcoded as `"creative-studio-db-password"` for ALL environments and deployments. However, Terraform CREATES this secret at lines 230-249:

```terraform
resource "google_secret_manager_secret" "db_password" {
  secret_id = "creative-studio-db-password"  # ❌ Also hardcoded here
  project   = var.gcp_project_id
  # ...
}
```

**Issues This Causes:**

1. **Multi-Environment Conflict:** If you deploy to the same GCP project with multiple environments (dev, staging, prod), all services try to use the same secret:
   - Dev backend → reads `creative-studio-db-password`
   - Staging backend → reads `creative-studio-db-password` (SAME)
   - Prod backend → reads `creative-studio-db-password` (SAME)
   - **Result:** All environments share the SAME database password, which is a security violation

2. **Database Password Leak Between Environments:** If the dev database is compromised, the attacker gets a password that also works for staging and production

3. **Hard to Manage Secrets:** If you want different passwords per environment, you have no way to distinguish them

4. **Secret Version Conflicts:** If you rotate the password in dev, it updates the shared secret that prod uses

**Better Architecture:**

Each environment should have its own secret:
- `creative-studio-db-password-dev`
- `creative-studio-db-password-staging`
- `creative-studio-db-password-prod`

**Fix:**

Option 1: Reference the secret created by Terraform (RECOMMENDED)

```terraform
# At platform/main.tf line 230-249 (existing code)
resource "google_secret_manager_secret" "db_password" {
  # Make secret ID environment-specific
  secret_id = "creative-studio-db-password-${var.environment}"
  project   = var.gcp_project_id

  replication {
    user_managed {
      replicas {
        location = var.gcp_region
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# ... existing secret version code ...

# At line 317, reference the secret we just created
module "backend_service" {
  source = "../cloud-run-service"

  # ... other variables ...

  # ✅ Reference the secret we created above
  db_secret_id = google_secret_manager_secret.db_password.secret_id

  depends_on = [
    google_project_service.apis
  ]
}
```

**Verification:**

```bash
# Deploy to dev
terraform apply -var="environment=dev"

# Check that secret is created with correct name
gcloud secrets list --filter="name:*db-password*"
# Should show: creative-studio-db-password-dev

# Deploy to prod (same project)
terraform apply -var="environment=prod"

# Now you should have TWO separate secrets
gcloud secrets list --filter="name:*db-password*"
# Should show:
#   creative-studio-db-password-dev
#   creative-studio-db-password-prod
```

---

### Issue #4: Missing Bootstrap Service Account IAM Permissions for Secrets

**Severity:** 🔴 CRITICAL - Bootstrap job will fail to access secrets at runtime

**Location:** `modules/platform/main.tf` (lines 449-459 and missing section)

**Current Code:**

```terraform
# Lines 449-459: Grants backend service account access to backend secrets
resource "google_secret_manager_secret_iam_member" "backend_runtime_secret_accessor" {
  for_each = toset(var.backend_secrets)

  provider  = google-beta
  project   = var.gcp_project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = module.backend_service.run_sa_member

  depends_on = [module.backend_secrets]
}

# ❌ MISSING: Similar binding for bootstrap service account
# Bootstrap job needs access to bootstrap_job_secrets
```

**Problem:**

The code grants the backend Cloud Run service account access to backend secrets, but there's NO corresponding IAM binding for the bootstrap service account to access `bootstrap_job_secrets`.

When the bootstrap Cloud Run Job tries to mount secrets from Secret Manager, it will fail with:

```
Permission denied: secretmanager.secretVersions.get
```

**Why This Matters:**

- The bootstrap job at platform/main.tf:464-513 creates a service account: `google_service_account.bootstrap_sa`
- The module passes `var.bootstrap_job_secrets` which is a map of secrets
- But the bootstrap service account is NEVER granted `secretmanager.secretAccessor` role
- When Cloud Build executes the job with these secrets, it fails

**Example Scenario:**

```terraform
# User defines bootstrap secrets
bootstrap_job_secrets = {
  DB_ENCRYPTION_KEY = { secret_id = "db-encryption-key" }
  API_SIGNING_KEY   = { secret_id = "api-signing-key" }
}

# Terraform creates the service account: cs-bootstrap-dev@project.iam.gserviceaccount.com
# But NEVER grants it access to those two secrets
# Result: Cloud Run Job execution fails
```

**Fix:**

Add this IAM binding after the backend secrets binding (around line 460):

```terraform
# Grant the bootstrap service account access to bootstrap job secrets
# Only created when bootstrap job is enabled
resource "google_secret_manager_secret_iam_member" "bootstrap_runtime_secret_accessor" {
  for_each = var.enable_cloud_run_job ? var.bootstrap_job_secrets : {}

  provider  = google-beta
  project   = var.gcp_project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.bootstrap_sa[0].member

  depends_on = [google_service_account.bootstrap_sa]
}
```

**Why This Fix Works:**

- Uses `for_each` to loop over each secret in `bootstrap_job_secrets`
- Grants `secretmanager.secretAccessor` role to the bootstrap service account
- Only created when `enable_cloud_run_job = true`
- Uses proper dependency on the service account creation

**Verification:**

```bash
# Deploy with bootstrap enabled and secrets
terraform apply \
  -var="enable_cloud_run_job=true" \
  -var="bootstrap_job_secrets={DB_PASS={secret_id=\"db-pass\"}}"

# Verify IAM binding exists
gcloud secrets get-iam-policy db-pass --format json | grep bootstrap

# Should show: cs-bootstrap-dev@project.iam.gserviceaccount.com has secretAccessor role
```

---

## Warning Issues (Should Fix Before Production)

### Issue #5: Cloud Build Bootstrap YAML - Hardcoded Database Instance Hash

**Severity:** 🟡 WARNING - Bootstrap job will fail if database instance is recreated

**Location:** `backend/cloudbuild-bootstrap.yaml:136`

**Current Code:**
```yaml
substitutions:
  # ... other substitutions ...
  _CLOUD_SQL_INSTANCE: '${PROJECT_ID}:us-central1:creative-studio-db-c3353262'
```

**Problem:**

The Cloud SQL instance connection name includes a random hash suffix that changes every time the instance is recreated. This hash is generated by Terraform's `random_id` resource (postgresql/main.tf:15-17):

```terraform
resource "random_id" "db_name_suffix" {
  byte_length = 4  # Generates a 4-byte hex string
}
```

Each time you run `terraform destroy` and `terraform apply`, this hash changes. The YAML file has a hardcoded hash `c3353262` which will be WRONG after the first apply.

**Scenarios Where This Fails:**

1. **After First Deployment:** The hardcoded hash `c3353262` is used, but Terraform creates instance with hash `a1b2c3d4` → Mismatch
2. **After Database Recreation:** If someone runs `terraform destroy` and `terraform apply`, the hash changes → Mismatch
3. **Multiple Deployments:** Each environment has a different hash, but YAML has only one → Conflicts

**Impact:**

Bootstrap Cloud Build job tries to connect to non-existent Cloud SQL instance:
```
ERROR: Cloud SQL instance not found: ...creative-studio-db-c3353262
```

**Fix:**

Pass the actual instance connection name from Terraform (addressed in Issue #2). This issue is resolved by implementing Issue #2's fix which adds:

```terraform
_CLOUD_SQL_INSTANCE = module.postgresql.connection_name
```

---

### Issue #6: Bootstrap Environment Variables - Hardcoded Values

**Severity:** 🟡 WARNING - Bootstrap job environment won't match infrastructure

**Location:** `backend/cloudbuild-bootstrap.yaml:144`

**Current Code:**
```yaml
_BOOTSTRAP_ENV_VARS: 'ADMIN_USER_EMAIL=admin@example.com,LOG_LEVEL=INFO,ENVIRONMENT=sandbox,INSTANCE_CONNECTION_NAME=${PROJECT_ID}:us-central1:creative-studio-db-c3353262,USE_CLOUD_SQL_PRIVATE_IP=false'
```

**Problems:**

| Variable | Hardcoded Value | Should Be | Why |
|----------|-----------------|-----------|-----|
| `ENVIRONMENT` | `sandbox` | `var.environment` | Hardcoded to one environment only |
| `INSTANCE_CONNECTION_NAME` | Hardcoded with wrong hash | `module.postgresql.connection_name` | Hash changes, connection string is wrong |
| `USE_CLOUD_SQL_PRIVATE_IP` | `false` | `var.vpc_enable` | Should respect VPC setting |
| `ADMIN_USER_EMAIL` | `admin@example.com` | Should be variable | Not configurable per environment |
| `LOG_LEVEL` | `INFO` | Should be variable | No way to set debug logging |

**Impact:**

Bootstrap application runs with wrong configuration:
- Always thinks it's in "sandbox" environment
- Always tries to use public IP for Cloud SQL even if VPC is enabled
- Uses hardcoded admin email regardless of actual requirement
- Can't adjust logging levels

**Fix:**

Make these configurable. Add to `modules/platform/variables.tf`:

```terraform
variable "bootstrap_job_admin_email" {
  type        = string
  description = "Admin user email to create during bootstrap"
  default     = "admin@example.com"
}

variable "bootstrap_job_log_level" {
  type        = string
  description = "Log level for bootstrap job (DEBUG, INFO, WARNING, ERROR)"
  default     = "INFO"
}
```

Then update the substitution (in Issue #2's fix):

```terraform
_BOOTSTRAP_ENV_VARS = join(",", concat(
  [
    "ENVIRONMENT=${var.environment}",
    "INSTANCE_CONNECTION_NAME=${module.postgresql.connection_name}",
    "USE_CLOUD_SQL_PRIVATE_IP=${var.vpc_enable ? "true" : "false"}",
    "DB_NAME=${module.postgresql.db_name}",
    "DB_USER=${module.postgresql.db_user}",
    "ADMIN_USER_EMAIL=${var.bootstrap_job_admin_email}",
    "LOG_LEVEL=${var.bootstrap_job_log_level}",
  ],
  [for k, v in var.bootstrap_job_environment_variables : "${k}=${v}"]
))
```

---

### Issue #7: Missing Bootstrap Job Variables in Environment Configs

**Severity:** 🟡 WARNING - Bootstrap configuration not passed from environments

**Location:** `environments/dev-infra-example/main.tf:51` and `environments/prod_ops_sandbox/main.tf:49`

**Current Code:**

The environment's `main.tf` calls the platform module but doesn't pass all the bootstrap job variables:

```terraform
module "creative_studio_platform" {
  source = "../../modules/platform"

  gcp_project_id            = var.gcp_project_id
  gcp_region                = var.gcp_region
  environment               = var.environment
  backend_service_name      = var.backend_service_name
  # ... many other variables ...

  # ❌ MISSING: bootstrap_job_* variables
  # enable_cloud_run_job              = var.enable_cloud_run_job
  # bootstrap_job_name                = var.bootstrap_job_name
  # bootstrap_image_name              = var.bootstrap_image_name
  # bootstrap_job_environment_variables = var.bootstrap_job_environment_variables
  # bootstrap_job_secrets             = var.bootstrap_job_secrets
  # bootstrap_job_cpu                 = var.bootstrap_job_cpu
  # bootstrap_job_memory              = var.bootstrap_job_memory
  # bootstrap_job_timeout             = var.bootstrap_job_timeout
}
```

**Problem:**

The environment-level variables ARE defined in `variables.tf` (lines 218-267 of prod_ops_sandbox), but they're NOT passed to the platform module. This means:

1. Defaults are always used, even if user provides different values
2. Environment-specific bootstrap configurations are ignored
3. User can't override bootstrap settings per environment

**Example Scenario:**

```bash
# User wants a dev environment with 1 CPU and 512Mi memory for bootstrap
terraform apply \
  -var-file="environments/dev/terraform.tfvars" \
  -var="bootstrap_job_cpu=1000m" \
  -var="bootstrap_job_memory=512Mi"

# But since main.tf doesn't pass these variables, they're ignored
# Platform module uses default values:
# - bootstrap_job_cpu = "2000m" (default from platform/variables.tf:220)
# - bootstrap_job_memory = "2048Mi" (default from platform/variables.tf:226)
```

**Fix:**

Update both environment main.tf files to pass bootstrap variables:

**File:** `environments/dev-infra-example/main.tf` (line 51, add these lines):

```terraform
module "creative_studio_platform" {
  source = "../../modules/platform"

  # --- Core Configuration ---
  gcp_project_id  = var.gcp_project_id
  gcp_region      = var.gcp_region
  environment     = var.environment

  # ... existing variables ...

  # --- Cloud Run Job Configuration (Database Bootstrap) ---
  enable_cloud_run_job                = var.enable_cloud_run_job
  bootstrap_job_name                  = var.bootstrap_job_name
  bootstrap_image_name                = var.bootstrap_image_name
  bootstrap_job_environment_variables = var.bootstrap_job_environment_variables
  bootstrap_job_secrets               = var.bootstrap_job_secrets
  bootstrap_job_cpu                   = var.bootstrap_job_cpu
  bootstrap_job_memory                = var.bootstrap_job_memory
  bootstrap_job_timeout               = var.bootstrap_job_timeout
}
```

Do the same for `environments/prod_ops_sandbox/main.tf` (already has most of these, verify they're all there).

---

### Issue #8: VPC Connector Not Passed to Bootstrap Job

**Severity:** 🟡 WARNING - Bootstrap job won't have VPC access when needed

**Location:** `modules/platform/cloud_build_trigger_bootstrap.tf:93` (YAML) and substitutions

**Problem:**

The Cloud Build bootstrap YAML tries to create a Cloud Run Job with VPC access using the `--vpc-connector` flag:

```yaml
--vpc-connector="projects/$PROJECT_ID/locations/${_REGION}/connectors/${_VPC_CONNECTOR_NAME}" \
```

But when the job already exists and only the image is updated, the VPC connector configuration is NOT passed:

```yaml
gcloud run jobs update '${_BOOTSTRAP_JOB_NAME}' \
  --image="$IMAGE" \
  --region='${_REGION}' \
  --project=$PROJECT_ID
  # ❌ Missing: --vpc-connector flag
```

**Scenarios:**

1. **First deployment with VPC:** Creates job with VPC connector ✅
2. **Second deployment (image update):** Updates job WITHOUT VPC connector ❌
   - Job loses VPC access
   - Can't connect to private Cloud SQL anymore

**Why This Happens:**

The YAML script has conditional logic for creating vs. updating, but only the `create` branch includes VPC configuration. The `update` branch only updates the image.

**Fix:**

Update both branches of the YAML to include VPC configuration:

```bash
# Create path (around line 89)
gcloud run jobs create '${_BOOTSTRAP_JOB_NAME}' \
  --image="$IMAGE" \
  --region='${_REGION}' \
  --project=$PROJECT_ID \
  --vpc-connector="projects/$PROJECT_ID/locations/${_REGION}/connectors/${_VPC_CONNECTOR_NAME}" \
  --vpc-egress='private-ranges-only' \
  # ... rest ...

# Update path (around line 83)
gcloud run jobs update '${_BOOTSTRAP_JOB_NAME}' \
  --image="$IMAGE" \
  --region='${_REGION}' \
  --project=$PROJECT_ID \
  --vpc-connector="projects/$PROJECT_ID/locations/${_REGION}/connectors/${_VPC_CONNECTOR_NAME}" \
  --vpc-egress='private-ranges-only'
```

Also ensure the Terraform trigger passes the VPC connector name (handled by Issue #2's fix).

---

### Issue #9: Missing Outputs from VPC Module

**Severity:** 🟡 WARNING - VPC Connector name not exposed for bootstrap configuration

**Location:** `modules/vpc_network/outputs.tf`

**Problem:**

The VPC module creates a VPC connector but doesn't export its name:

```terraform
resource "google_vpc_access_connector" "default" {
  name    = "${var.name}-cs-connector"
  # ...
}
```

But there's no output for the connector name:

```terraform
# Missing in outputs.tf:
# output "vpc_connector_name" {
#   value = google_vpc_access_connector.default.name
# }
```

The platform module needs this name to pass to the bootstrap trigger (Issue #2's fix requires it):

```terraform
_VPC_CONNECTOR_NAME = var.vpc_enable ? module.vpc_network[0].vpc_connector_name : ""
```

**Fix:**

Add to `modules/vpc_network/outputs.tf`:

```terraform
output "vpc_connector_name" {
  description = "Name of the Serverless VPC Connector"
  value       = google_vpc_access_connector.default.name
}

output "vpc_connector_id" {
  description = "ID of the Serverless VPC Connector (for Cloud Run vpc_connector_id)"
  value       = google_vpc_access_connector.default.id
}
```

---

### Issue #10: Firestore Database Not Configured

**Severity:** 🟡 WARNING - Firebase project created but no database

**Location:** `modules/platform/main.tf:330-344`

**Problem:**

The code creates a Firebase project:

```terraform
resource "google_firebase_project" "default" {
  count    = (var.enable_cloud_build || var.enable_identity_platform) ? 1 : 0
  provider = google-beta
  project  = var.gcp_project_id

  depends_on = [
    time_sleep.api_initialization
  ]
}
```

But there's no corresponding Firestore database resource. The comments in multiple files mention "Firestore database" but it's not created.

**What's Missing:**

```terraform
resource "google_firestore_database" "default" {
  count    = (var.enable_cloud_build || var.enable_identity_platform) ? 1 : 0
  provider = google-beta
  project  = var.gcp_project_id
  location_id = var.gcp_region
  type     = "FIRESTORE_NATIVE"

  depends_on = [google_firebase_project.default]
}
```

**Why This Matters:**

- Backend and frontend applications expect Firestore to exist
- Without it, they will fail when trying to access the database
- Users deploying this infrastructure won't have a database ready to use

**Impact:**

Backend Cloud Run service starts but fails when trying to use Firestore:

```
Error: Firestore database not found
Status code: 5 INTERNAL error
```

**Fix:**

Add Firestore database creation. Add to `modules/platform/main.tf` after the Firebase project resource:

```terraform
# Create Firestore database (only when Firebase features are enabled)
resource "google_firestore_database" "default" {
  count    = (var.enable_cloud_build || var.enable_identity_platform) ? 1 : 0
  provider = google-beta
  project  = var.gcp_project_id

  name       = "(default)"
  location_id = var.gcp_region
  type       = "FIRESTORE_NATIVE"  # Use native Firestore, not Datastore mode

  depends_on = [
    google_firebase_project.default,
    time_sleep.api_initialization
  ]
}

# Add to outputs (in platform/outputs.tf if it exists, or create it)
output "firestore_database_id" {
  description = "Firestore database ID"
  value       = try(google_firestore_database.default[0].id, null)
}
```

Also add a variable to platform/variables.tf to control it:

```terraform
variable "enable_firestore" {
  type        = bool
  description = "Whether to create a Firestore database (auto-created when Firebase features are enabled)"
  default     = true
}
```

---

## Summary Table of All Issues

| # | Issue | Severity | File | Line | Type | Fix Complexity |
|---|-------|----------|------|------|------|-----------------|
| 1 | Hardcoded bootstrap trigger count | 🔴 CRITICAL | cloud_build_trigger_bootstrap.tf | 10 | Logic Error | Low |
| 2 | Missing bootstrap substitutions | 🔴 CRITICAL | cloud_build_trigger_bootstrap.tf | 8-42 | Missing Variables | Medium |
| 3 | Hard-coded DB secret ID | 🔴 CRITICAL | main.tf (platform) | 317 | Configuration | Low |
| 4 | Missing bootstrap secret IAM | 🔴 CRITICAL | main.tf (platform) | 460 | Missing IAM | Low |
| 5 | Hardcoded DB instance hash | 🟡 WARNING | cloudbuild-bootstrap.yaml | 136 | Hardcoded Value | Low |
| 6 | Hardcoded bootstrap env vars | 🟡 WARNING | cloudbuild-bootstrap.yaml | 144 | Hardcoded Values | Medium |
| 7 | Missing bootstrap vars in envs | 🟡 WARNING | main.tf (environments) | 51, 49 | Missing Pass-Through | Low |
| 8 | VPC not passed in job update | 🟡 WARNING | cloudbuild-bootstrap.yaml | 83 | Incomplete Conditional | Medium |
| 9 | Missing VPC connector outputs | 🟡 WARNING | vpc_network/outputs.tf | N/A | Missing Export | Very Low |
| 10 | Firestore not created | 🟡 WARNING | main.tf (platform) | 330-344 | Missing Resource | Medium |

---

## Implementation Priority

**Phase 1 (Deploy Blockers - Fix First):**
1. Issue #1 - Bootstrap trigger count (5 minutes)
2. Issue #2 - Bootstrap substitutions (30 minutes)
3. Issue #3 - Database secret ID (10 minutes)
4. Issue #4 - Bootstrap secret IAM (10 minutes)

**Phase 2 (Reliability Fixes - Fix Before Production):**
5. Issue #5 - Database instance hash (covered by #2)
6. Issue #6 - Bootstrap env vars (covered by #2)
7. Issue #7 - Environment vars passing (20 minutes)
8. Issue #8 - VPC in update path (15 minutes)
9. Issue #9 - VPC outputs (5 minutes)
10. Issue #10 - Firestore creation (20 minutes)

---

## Testing Checklist

After applying fixes, verify with these tests:

```bash
# Test 1: Bootstrap disabled
terraform plan -var="enable_cloud_build=false" -var="enable_cloud_run_job=false"
# Should NOT create bootstrap trigger ✓

# Test 2: Only job enabled
terraform plan -var="enable_cloud_build=false" -var="enable_cloud_run_job=true"
# Should NOT create trigger (bootstrap without CI/CD makes no sense) ✓

# Test 3: Dev environment
terraform plan -var="environment=dev" -var="enable_cloud_build=true" -var="enable_cloud_run_job=true"
# Verify substitutions reference correct environment:
# - _BOOTSTRAP_SERVICE_ACCOUNT = "cs-bootstrap-dev@..."
# - _CLOUD_SQL_INSTANCE = "project:region:creative-studio-db-xxx"
# - _VPC_CONNECTOR_NAME = "cs-dev-cs-connector" ✓

# Test 4: Prod environment
terraform plan -var="environment=prod" -var="enable_cloud_build=true" -var="enable_cloud_run_job=true"
# Verify substitutions reference correct environment:
# - _BOOTSTRAP_SERVICE_ACCOUNT = "cs-bootstrap-prod@..."
# - _BOOTSTRAP_ENV_VARS contains "ENVIRONMENT=prod" ✓

# Test 5: Multiple environments
terraform apply -var="environment=dev"
terraform apply -var="environment=prod"
# Verify separate secrets exist:
gcloud secrets list
# Should show:
# - creative-studio-db-password-dev
# - creative-studio-db-password-prod ✓

# Test 6: VPC enabled
terraform plan -var="vpc_enable=true"
# Verify:
# - VPC module outputs vpc_connector_name ✓
# - Substitution includes VPC connector ✓
# - Bootstrap uses VPC in both create and update ✓
```

---

## References

- [Cloud Build Triggers Documentation](https://cloud.google.com/build/docs/automating-builds/build-repos-from-github)
- [Cloud Run Jobs Documentation](https://cloud.google.com/run/docs/quickstarts/jobs/build-create-python)
- [Secret Manager IAM Roles](https://cloud.google.com/secret-manager/docs/managing-secrets#iam)
- [Cloud SQL Connection Names](https://cloud.google.com/sql/docs/postgres/connect-overview#cloud-sql-connection-name)
- [Firebase Project Setup](https://firebase.google.com/docs/projects/terraform/get-started)

---

**Document Version:** 1.0
**Last Updated:** December 26, 2025
**Status:** Ready for Implementation
