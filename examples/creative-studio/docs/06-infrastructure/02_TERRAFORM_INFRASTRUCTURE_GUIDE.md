# Terraform Infrastructure Configuration Guide

This guide covers Terraform configuration, variable naming conventions, edge cases, and best practices for deploying Creative Studio infrastructure.

## 📋 Quick Reference

- **Infrastructure Code Location:** `/infra/`
- **Configuration Per Environment:** `/infra/environments/{environment}/main.tf`
- **Modules:** `/infra/modules/`
- **Architecture & Variable Naming:** See [`/infra/ARCHITECTURE.md`](/infra/ARCHITECTURE.md)

## 📚 Table of Contents

1. [Variable Naming Convention](#variable-naming-convention)
2. [Destruction Control](#destruction-control-critical-configuration)
3. [Edge Cases & Inconsistencies (Resolved)](#edge-cases--inconsistencies-resolved)
4. [Cloud Run Access Control](#cloud-run-access-control-rolesruninvoker)
5. [Configuration Examples](#configuration-examples)
6. [Protected Variables Reference](#protected-variables-reference)
7. [Verification Checklist](#verification-checklist-before-terraform-apply)
8. [Deployment Commands](#deployment-commands)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

---

## Variable Naming Convention

### Overview

All Terraform variables follow a strict naming convention to prevent configuration mistakes and ensure consistency.

### Naming Patterns

**1. Project-Level Variables**
- Prefix: `gcp_` for all Google Cloud references
- Examples: `gcp_project_id`, `gcp_region`
- **Required in every environment configuration**

**2. Service-Specific Variables**
- Prefix: `<service>_` (lowercase service name)
- Examples:
  - `storage_allow_destroy` (Cloud Storage)
  - `storage_cors_allowed_origins` (Cloud Storage)
  - `cloud_sql_public_ip_enabled` (Cloud SQL)
  - `cloud_sql_deletion_protection_enabled` (Cloud SQL)
  - `firestore_deletion_protection_enabled` (Firestore)

**3. Destruction Control Variables**
- Single source of truth: `allow_destroy` at platform level
- Set once in your environment, applies to all resources
- **Development:** `allow_destroy = true` (allows cleanup)
- **Production:** `allow_destroy = false` (prevents accidents)

**4. Database Protection**
- Pattern: `<service>_deletion_protection_enabled`
- Separate from `allow_destroy` (see below)
- Recommended: `false` for dev, `true` for prod

---

## Destruction Control: Critical Configuration

### The `allow_destroy` Variable

**Purpose:** Controls whether Terraform can destroy resources like storage buckets and databases.

**Behavior:**
| Setting | Development | Production |
|---------|-------------|-----------|
| `allow_destroy = true` | ✅ Resources can be destroyed | ❌ **NEVER USE** |
| `allow_destroy = false` | ❌ Prevents accidental cleanup | ✅ Required |

**Implementation:**
```hcl
# In your environment's main.tf
locals {
  allow_destroy = true  # Dev environment
}

# Platform module receives this once and applies to:
# - Cloud Storage bucket
# - Cloud SQL instance
# - Firestore database
```

**Why Unified Variable?**

Previously, three different variables controlled destruction:
- `storage_force_destroy` (platform) ❌ DEPRECATED
- `allow_destroy` (platform) ✅ CURRENT
- `force_destroy` (storage module) ❌ RENAMED

**This created confusion:**
```hcl
# Bad: User sets allow_destroy = false
allow_destroy = false

# But storage module received force_destroy = true
# Result: Bucket could be deleted despite allow_destroy = false ❌
```

**Fixed in v1.1:**
```hcl
# Good: Single source of truth
allow_destroy = false

# ALL resources (storage, SQL, Firestore) respect this setting ✅
```

### Deletion Protection vs Allow Destroy

**Important:** These are separate mechanisms:

| Variable | Purpose | Behavior |
|----------|---------|----------|
| `allow_destroy` | Terraform can destroy resource | Controls `terraform destroy` execution |
| `<service>_deletion_protection_enabled` | GCP prevents deletion | Prevents deletion even in GCP Console |

**Recommended Setup:**

Development:
```hcl
allow_destroy = true
cloud_sql_deletion_protection_enabled = false
firestore_deletion_protection_enabled = false
```

Production:
```hcl
allow_destroy = false
cloud_sql_deletion_protection_enabled = true
firestore_deletion_protection_enabled = true
```

---

## Edge Cases & Inconsistencies (Resolved)

### Issue #1: Destruction Control Variable Consolidation ✅

**Problem Identified:**
Three variables controlled bucket destruction with conflicting names and behaviors.

**Root Cause:**
Legacy code had: `storage_force_destroy`, `allow_destroy`, and storage module's `force_destroy`.

**Resolution (v1.1):**
- ✅ Removed deprecated `storage_force_destroy` from platform variables
- ✅ Renamed storage module variables to use `storage_` prefix
- ✅ Single source of truth: `allow_destroy` at platform level

**Migration:**
If upgrading from older version:
```hcl
# OLD (Remove these):
storage_force_destroy = true  # DEPRECATED

# NEW (Use this):
allow_destroy = true  # Single variable for all destruction control
```

### Issue #2: Variable Naming Inconsistency ✅

**Problem Identified:**
Storage module variables didn't follow naming patterns:
- `allow_destroy` ✅ Good
- `force_destroy` ❌ Confusing (removed)
- `cors_allowed_origins` ❌ Missing `storage_` prefix

**Resolution (v1.1):**
- ✅ Storage variables now use `storage_` prefix
- ✅ Consistent with Cloud SQL pattern (`cloud_sql_*`)
- ✅ Consistent with Firestore pattern (`firestore_*`)

**Variables Changed:**
```hcl
# OLD:
cors_allowed_origins = ["*"]

# NEW:
storage_cors_allowed_origins = ["*"]
```

### Issue #3: Firestore Database Name Not Visible ✅

**Problem Identified:**
Database name auto-computed as `cstudio-{environment}` but users couldn't see it before applying.

**Resolution (v1.1):**
Added `firestore_database_name` output to environment layer.

**How to Verify:**
```bash
cd infra/environments/dev-infra-example

# Before applying
terraform plan
terraform output firestore_database_name

# After applying
terraform output infrastructure_ready
```

**Output Example:**
```json
{
  "firestore_database_name": "cstudio-development",
  "environment": "development",
  "project_id": "my-gcp-project",
  ...
}
```

### Issue #4: Bootstrap Environment Variable Protection (Pending)

**Status:** Identified for refinement in upcoming release

**Current Limitation:**
Bootstrap job environment variables lack the same protection mechanism as backend service.

**What's Protected (Backend Service):**
```hcl
# These are auto-computed and cannot be overridden:
ENVIRONMENT = "development"
FIREBASE_DB = "cstudio-development"
```

**What's Not Yet Protected (Bootstrap):**
```hcl
# Users can override these (not protected):
be_env_vars = {
  DB_NAME = "wrong_db"  # Could be set incorrectly
}
```

**Workaround (For Now):**
- Use exact variable names from documentation
- Verify before applying: `terraform plan`
- Review `BOOTSTRAP.md` for required variables

**Future Plan:**
Bootstrap will implement protected variables pattern:
```hcl
# Planned protection:
bootstrap_env_vars_protected = {
  "DB_NAME" = "creative_studio"
  "DB_USER" = "studio_user"
}
```

---

## Configuration Examples

### Development Environment

```hcl
# infra/environments/dev-infra-example/main.tf
locals {
  # === PROJECT ===
  gcp_project_id = "my-dev-project"
  gcp_region     = "us-central1"
  environment    = "development"

  # === DESTRUCTION CONTROL ===
  allow_destroy = true  # Dev: allow cleanup

  # === DATABASE PROTECTION ===
  cloud_sql_deletion_protection_enabled    = false
  firestore_deletion_protection_enabled    = false

  # === VPC (Optional for Dev) ===
  vpc_enable                   = false
  cloud_sql_public_ip_enabled  = true  # Dev: public access OK

  # === STORAGE ===
  storage_cors_allowed_origins = ["*"]  # Dev: allow all

  # === ENVIRONMENT VARIABLES ===
  be_env_vars = {
    LOG_LEVEL                      = "DEBUG"
    IDENTITY_PLATFORM_ALLOWED_ORGS = ""
  }

  # ... rest of config
}
```

### Production Environment

```hcl
# infra/environments/prod/main.tf
locals {
  # === PROJECT ===
  gcp_project_id = "my-prod-project"
  gcp_region     = "us-central1"
  environment    = "production"

  # === DESTRUCTION CONTROL ===
  allow_destroy = false  # Prod: NEVER allow destruction

  # === DATABASE PROTECTION ===
  cloud_sql_deletion_protection_enabled    = true
  firestore_deletion_protection_enabled    = true

  # === VPC (Recommended for Prod) ===
  vpc_enable                   = true
  cloud_sql_public_ip_enabled  = false  # Prod: private only

  # === STORAGE ===
  storage_cors_allowed_origins = [
    "https://myapp.com",
    "https://www.myapp.com"
  ]

  # === ENVIRONMENT VARIABLES ===
  be_env_vars = {
    LOG_LEVEL                      = "INFO"
    IDENTITY_PLATFORM_ALLOWED_ORGS = "example.com"
  }

  # ... rest of config
}
```

---

## Cloud Run Access Control (roles/run.invoker)

### Overview

The Creative Studio backend API runs on Google Cloud Run and uses IAM-based access control to restrict **who can invoke (call) the backend service** at the network level. This is separate from and complements application-level authentication (Identity Platform).

### Configuration Variable: `backend_invoker_identities`

**Type:** `list(string)`
**Location:** `infra/environments/{environment}/main.tf`
**Default:** `[]` (empty list = public access)

### How It Works

The `backend_invoker_identities` variable controls the `roles/run.invoker` IAM role on the Cloud Run backend service:

```
User Configuration (environment/main.tf)
         ↓
backend_invoker_identities = ["group:developers@company.com"]
         ↓
Platform Module (platform/main.tf)
         ↓
Backend Service Module (modules/services/backend/main.tf)
         ↓
Google Cloud IAM
Grant roles/run.invoker to specified identities
```

**Code Implementation:**

File: `infra/modules/services/backend/main.tf` (Lines 270-283)

```hcl
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = length(var.invoker_identities) > 0 ?
            toset(var.invoker_identities) :
            toset(["allUsers"])

  name     = google_cloud_run_v2_service.this.name
  location = google_cloud_run_v2_service.this.location
  role     = "roles/run.invoker"
  member   = each.value
}
```

**Logic:**
- If `invoker_identities` is **NOT empty**: Grant `roles/run.invoker` ONLY to those identities
- If `invoker_identities` **IS empty**: Grant `roles/run.invoker` to `allUsers` (public access)

### Configuration Examples

#### Example 1: Public Access (Development)

```hcl
# infra/environments/dev-infra-example/main.tf
backend_invoker_identities = []  # Empty = allUsers

# Result: Anyone can call the API
# Use case: Development, testing, public APIs
```

#### Example 2: Restrict to Development Team

```hcl
# infra/environments/dev-infra-example/main.tf
backend_invoker_identities = ["group:dev-team@company.com"]

# Result: Only members of dev-team@company.com Google Group can access
# Use case: Team-only development environment
```

#### Example 3: Production with Multiple Teams + CI/CD

```hcl
# infra/environments/prod/main.tf
backend_invoker_identities = [
  "group:developers@company.com",
  "group:qa-team@company.com",
  "serviceAccount:cloud-build@project.iam.gserviceaccount.com"
]

# Result:
# - All developers and QA can access
# - CI/CD pipeline can deploy and test
```

#### Example 4: Restrict to Admin Only

```hcl
# infra/environments/prod/main.tf
backend_invoker_identities = ["user:cto@company.com"]

# Result: Only the CTO can call the API
# Use case: Highly restricted API
```

### Identity Format Reference

| Format | Example | Purpose |
|--------|---------|---------|
| `user:` | `user:john@example.com` | Specific person |
| `group:` | `group:developers@example.com` | Google Group members |
| `serviceAccount:` | `serviceAccount:ci-cd@project.iam.gserviceaccount.com` | Service account (for automation) |

### Two-Layer Security Model

**Important:** Cloud Run access control works alongside Identity Platform authentication:

| Layer | What It Controls | When It Applies | Response if Denied |
|-------|------------------|-----------------|-------------------|
| **Layer 1: Cloud Run IAM** | Who can invoke the service | Before request reaches backend | 403 Forbidden |
| **Layer 2: Identity Platform** | Who is authenticated | Inside backend application | 401 Unauthorized |

**Example Security Flow:**

```
User makes request to backend API
         ↓
Cloud Run: Check roles/run.invoker
  - If no restrictions: ✅ Allow to proceed
  - If restricted: Check if user in list
         ↓ (Request passed Cloud Run)
Backend Application: Check Identity Platform
  - If disabled: ✅ Allow all requests
  - If enabled: Validate ID token
         ↓ (Request passed authentication)
Execute Business Logic
```

**Recommended Production Setup:**
```hcl
# Layer 1: Restrict at Cloud Run level
backend_invoker_identities = ["group:internal-team@company.com"]

# Layer 2: Enable Identity Platform at application level
enable_identity_platform = true

# Result: Defense in depth - two security boundaries
```

### How to Configure

**Step 1:** Open your environment configuration
```bash
vim infra/environments/prod/main.tf
```

**Step 2:** Locate the CLOUD RUN ACCESS CONTROL section
```hcl
# === CLOUD RUN ACCESS CONTROL ===
backend_invoker_identities = []  # Change this!
```

**Step 3:** Set who should have access
```hcl
# Development: Public
backend_invoker_identities = []

# Production: Specific group
backend_invoker_identities = ["group:developers@company.com"]

# Production: Multiple groups + CI/CD
backend_invoker_identities = [
  "group:developers@company.com",
  "serviceAccount:cloud-build@project.iam.gserviceaccount.com"
]
```

**Step 4:** Deploy
```bash
cd infra/environments/prod
terraform plan
terraform apply
```

### Verification & Monitoring

#### Check Current Access Control

```bash
gcloud run services get-iam-policy creative-studio-backend-prod \
  --region=us-central1 \
  --format=json
```

Expected output (if restricted):
```json
{
  "bindings": [
    {
      "role": "roles/run.invoker",
      "members": ["group:developers@company.com"]
    }
  ]
}
```

#### Test Access (Authorized User)

```bash
gcloud run invoke creative-studio-backend-prod \
  --region us-central1
```

Expected: Request succeeds and returns backend response

#### Test Access (Unauthorized User)

```bash
curl https://creative-studio-backend-prod-us-central1.run.app/health
```

Expected (if restricted):
```
403 Forbidden
"The caller does not have permission [run.routes.invoke] on the provided resource"
```

#### Monitor Failed Access Attempts

```bash
gcloud logging read \
  "resource.type=cloud_run_service AND severity=ERROR" \
  --filter="resource.labels.service_name=creative-studio-backend-prod" \
  --format=json
```

### Common Mistakes

| Mistake | Impact | Solution |
|---------|--------|----------|
| Using email instead of `user:email` format | IAM rule doesn't work | Use `user:john@example.com` not `john@example.com` |
| Forgetting to include CI/CD service account | Automated deployments fail | Add `serviceAccount:cloud-build@project.iam.gserviceaccount.com` |
| Setting empty list unintentionally | API becomes public when it shouldn't be | Explicitly set `[]` for public or list identities for restricted |
| Misspelling group name | Authorization always fails | Verify group exists in Google Workspace admin console |

---

## Protected Variables Reference

### Backend Service (Auto-Computed)

These variables are **automatically set** and cannot be overridden:

| Variable | Value | How It's Set |
|----------|-------|--------------|
| `ENVIRONMENT` | "development" or "production" | From `var.environment` (protected) |
| `CORS_ORIGINS` | Backend service URL | From computed frontend URL (protected) |
| `GENMEDIA_BUCKET` | "creative-studio-{project-id}-assets" | From Cloud Storage module (protected) |
| `SIGNING_SA_EMAIL` | Service account email | From storage module (protected) |

### Backend Service (Defaults + Terraform Override)

These variables have sensible defaults but can be overridden by Terraform env vars:

| Variable | Default | Can Be Overridden | How |
|----------|---------|------------------|-----|
| `FIREBASE_DB` | "cstudio-development" | Yes | Terraform sets `FIREBASE_DB` env var per environment |

**Why This Works:**
- `FIREBASE_DB` has a safe default for local development
- Terraform passes the environment-specific value via env var (e.g., `cstudio-production`)
- Backend uses whatever is in the env var, or defaults to `cstudio-development` if missing
- Application doesn't care where the value came from - it just uses it

**Example:**
```hcl
# Development - Terraform passes FIREBASE_DB = "cstudio-development"
# Backend receives it, uses it ✅

# Production - Terraform passes FIREBASE_DB = "cstudio-production"
# Backend receives it, uses it ✅

# Local dev without Terraform - no FIREBASE_DB env var
# Backend uses default: "cstudio-development" ✅
```

**If User Attempts Override (Protected Values):**
The platform module merges with protected values taking precedence:
```hcl
# User sets:
be_env_vars = {
  ENVIRONMENT = "custom"
  LOG_LEVEL = "DEBUG"
}

# Platform computes (protected):
backend_env_vars_protected = {
  ENVIRONMENT = "development"
  CORS_ORIGINS = "https://backend-dev..."
}

# Result after merge (last-wins semantics):
ENVIRONMENT = "development"    # ✅ Protected value wins
CORS_ORIGINS = "https://..."   # ✅ Protected value wins
LOG_LEVEL = "DEBUG"            # ✅ User value (not protected)
```

---

## Verification Checklist Before `terraform apply`

### 1. Variable Values
- [ ] `gcp_project_id` is correct
- [ ] `gcp_region` is correct
- [ ] `environment` is "development" or "production"
- [ ] `allow_destroy` is correct for environment (true for dev, false for prod)

### 2. Computed Resources
- [ ] Run `terraform plan` and review
- [ ] Run `terraform output firestore_database_name` to verify database name
- [ ] Database name follows pattern: `cstudio-{environment}`

### 3. Protection Settings
- [ ] Dev: `cloud_sql_deletion_protection_enabled = false`
- [ ] Prod: `cloud_sql_deletion_protection_enabled = true`
- [ ] Same for Firestore deletion protection

### 4. Network Settings
- [ ] Dev: Can use `vpc_enable = false` with `cloud_sql_public_ip_enabled = true`
- [ ] Prod: Should use `vpc_enable = true` with `cloud_sql_public_ip_enabled = false`
- [ ] Never use both VPC and public IP simultaneously

### 5. Storage/CORS
- [ ] Dev: `storage_cors_allowed_origins = ["*"]` is OK
- [ ] Prod: `storage_cors_allowed_origins` lists specific domains only

---

## Deployment Commands

### Plan Changes
```bash
cd infra/environments/{environment}
terraform init
terraform plan
terraform output firestore_database_name  # Verify computed names
```

### Apply Changes
```bash
terraform apply
terraform output infrastructure_ready  # Review endpoints and next steps
```

### Destroy (Development Only!)
```bash
# Only valid if allow_destroy = true
terraform destroy

# WARNING: This will delete:
# - Cloud Storage bucket (if empty or allow_destroy=true)
# - Cloud SQL database
# - Firestore database
# NEVER RUN on production with allow_destroy=false
```

---

## Troubleshooting

### Issue: "Invalid configuration: vpc_enable = true but cloud_sql_public_ip_enabled = true"

**Cause:** Cannot use both VPC and public IP simultaneously.

**Solution:**
```hcl
# Choose one:

# Option 1: VPC (Recommended for Prod)
vpc_enable                   = true
cloud_sql_public_ip_enabled  = false

# Option 2: Public IP (Only for Dev)
vpc_enable                   = false
cloud_sql_public_ip_enabled  = true
```

### Issue: Firestore Database Name Doesn't Match Environment

**Cause:** Variable naming confusion or misconfiguration.

**Solution:**
```bash
# Verify computed name
terraform output firestore_database_name

# Should show: cstudio-{your-environment}
# If not, check:
# 1. Is environment = "development" or "production"?
# 2. Did you set firebase_db_name manually? (don't)
```

### Issue: Storage Bucket Won't Delete

**Cause:** `allow_destroy = false` or `cloud_sql_deletion_protection_enabled = true`

**Solution:**
```hcl
# Only if you're sure (dev environment ONLY):
allow_destroy = true
cloud_sql_deletion_protection_enabled = false

terraform apply
terraform destroy
```

---

## Best Practices

1. **Always run `terraform plan` before apply**
   ```bash
   terraform plan
   # Review all changes carefully
   ```

2. **Verify computed outputs**
   ```bash
   terraform output firestore_database_name
   terraform output infrastructure_ready
   ```

3. **Never manually override protected variables**
   - If you try, the platform module will override your values (expected)
   - This is a safety feature, not a bug

4. **Use consistent naming across environments**
   - Dev: `allow_destroy = true`
   - Prod: `allow_destroy = false`
   - Never mix these up

5. **Reference ARCHITECTURE.md for questions**
   - Contains detailed variable naming guide
   - Lists all protected vs customizable variables
   - Includes data flow diagrams

6. **Keep environment configs DRY**
   - Only override values that differ from defaults
   - Use comments to explain non-obvious settings

---

## Further Reading

- **[Infrastructure Variable Naming Convention](/infra/ARCHITECTURE.md#infrastructure-variable-naming-convention)** - Complete reference
- **[Protected Variables Design](/infra/ARCHITECTURE.md#single-source-of-truth-protected-variables-design)** - Why certain vars are protected
- **[QUICK_START.md](/infra/QUICK_START.md)** - Step-by-step deployment
- **[README.md](/infra/README.md)** - Infrastructure overview
