# Core Secrets Module

## Overview

This module provides **centralized secret management** for the Creative Studio infrastructure. It creates secrets in Google Secret Manager and grants access to multiple service accounts in a single, unified configuration.

**Key Design Principle**: Secrets are created once and their permissions are granted to all service accounts that need access, eliminating scattered secret creation across modules.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Platform Module                             │
│      (Centralized Orchestration)                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │  app_secrets Module (core/secrets)               │  │
│  │                                                  │  │
│  │  Secrets Configuration:                          │  │
│  │  ┌────────────────────────────────────────────┐ │  │
│  │  │ OAUTH_CLIENT_ID                            │ │  │
│  │  │  ├─ Accessor: frontend-trigger-SA          │ │  │
│  │  │  ├─ Accessor: backend-trigger-SA           │ │  │
│  │  │  └─ Accessor: backend-run-SA               │ │  │
│  │  └────────────────────────────────────────────┘ │  │
│  │                                                  │  │
│  │  Creates Secrets:                                │  │
│  │  ✓ OAUTH_CLIENT_ID in Secret Manager             │  │
│  │                                                  │  │
│  │  Grants Permissions:                             │  │
│  │  ✓ frontend-trigger-SA → OAUTH_CLIENT_ID       │  │
│  │  ✓ backend-trigger-SA → OAUTH_CLIENT_ID        │  │
│  │  ✓ backend-run-SA → OAUTH_CLIENT_ID            │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Module Inputs

### `secrets_config` (Required)

Type: `map(object({...}))`

Defines all secrets to create and their accessors:

```hcl
secrets_config = {
  "OAUTH_CLIENT_ID" = {
    description = "OAuth 2.0 Client ID for frontend and backend"
    accessors = [
      "serviceAccount:cs-fe-trigger-dev@project.iam.gserviceaccount.com",
      "serviceAccount:cs-be-trigger-dev@project.iam.gserviceaccount.com",
      "serviceAccount:cs-be-run-dev@project.iam.gserviceaccount.com",
    ]
  }
  # Add more secrets as needed
}
```

**Structure:**
- **Key**: Secret name (e.g., `OAUTH_CLIENT_ID`)
- **description**: Human-readable description (optional, max 63 chars after sanitization)
- **accessors**: List of service account member strings that can access this secret

### `gcp_project_id` (Required)

Type: `string`

The GCP project ID where secrets will be created.

## How It Works

### 1. Secret Creation

For each secret in `secrets_config`, the module creates:

```hcl
resource "google_secret_manager_secret" "this" {
  for_each = var.secrets_config

  secret_id = each.key  # e.g., "OAUTH_CLIENT_ID"

  labels {
    description = substr(
      replace(lower(each.value.description), "/[^a-z0-9_-]/", "-"),
      0,
      63
    )
  }

  replication {
    auto {}  # Auto-replication across Google Cloud regions
  }
}
```

**Features:**
- **Auto-replication**: Secrets automatically replicated across GCP regions
- **Label sanitization**: Descriptions sanitized to meet GCP label constraints
  - Converted to lowercase
  - Invalid characters replaced with hyphens
  - Truncated to 63 characters
- **No placeholder versions**: Terraform does NOT create placeholder secret versions
  - Prevents false confidence in deployments
  - Forces explicit secret population via CLI or manual process
  - Build pipelines fail fast if secret is missing

### 2. Permission Granting

For each secret-accessor pair, the module creates IAM bindings:

```hcl
resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = local.secret_accessor_map

  secret_id = google_secret_manager_secret.this[each.value.secret_name].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.accessor
}
```

**Processing:**
1. Flattens all secret:accessor pairs into a map
2. Grants `secretmanager.secretAccessor` role to each accessor
3. Single loop handles multiple accessors per secret automatically

## Usage Example

### In Platform Module

```hcl
module "app_secrets" {
  source = "../core/secrets"

  gcp_project_id = var.gcp_project_id

  secrets_config = {
    "OAUTH_CLIENT_ID" = {
      description = "OAuth 2.0 Client ID for frontend and backend"
      accessors = [
        module.frontend_service.trigger_sa_member,
        module.backend_service.trigger_sa_member,
        module.backend_service.run_sa_member,
      ]
    }
  }

  depends_on = [
    google_project_service.apis,
    module.frontend_service,
    module.backend_service
  ]
}
```

## Service Account Outputs

Services export member strings for use by this module:

```hcl
# Backend Service Module
output "trigger_sa_member" {
  value = "serviceAccount:${google_service_account.trigger.email}"
}

output "run_sa_member" {
  value = "serviceAccount:${google_service_account.run.email}"
}

# Frontend Service Module
output "trigger_sa_member" {
  value = "serviceAccount:${google_service_account.trigger.email}"
}
```

## Secret Population

**IMPORTANT**: Terraform does NOT populate secret values. You must populate them manually after `terraform apply`:

```bash
# Set the OAUTH_CLIENT_ID secret
gcloud secrets versions add OAUTH_CLIENT_ID \
  --data-file=- \
  --project=YOUR_PROJECT_ID \
  <<< "YOUR_CLIENT_ID.apps.googleusercontent.com"

# Verify the secret was created
gcloud secrets versions list OAUTH_CLIENT_ID --project=YOUR_PROJECT_ID
```

**Why?**
- Prevents hardcoding secrets in Terraform state
- Keeps secrets out of version control
- Forces explicit, intentional secret setup
- Build pipelines validate secret existence at build time

## Environment Variable Mapping

Cloud Run automatically maps Secret Manager secrets to environment variables via `secret_key_ref`:

```hcl
# In backend service Cloud Run configuration
env {
  name = "GOOGLE_TOKEN_AUDIENCE"
  valueFrom {
    secretKeyRef {
      name = "OAUTH_CLIENT_ID"  # Secret Manager secret name
      key  = "latest"           # Latest version
    }
  }
}
```

**In application code:**
```python
import os
oauth_client_id = os.getenv("GOOGLE_TOKEN_AUDIENCE")
# This value comes from the OAUTH_CLIENT_ID secret
```

## Multi-Accessor Pattern

This module supports granting the same secret to multiple service accounts:

```hcl
secrets_config = {
  "SHARED_SECRET" = {
    description = "Shared by multiple services"
    accessors = [
      "serviceAccount:service-1@project.iam.gserviceaccount.com",
      "serviceAccount:service-2@project.iam.gserviceaccount.com",
      "serviceAccount:service-3@project.iam.gserviceaccount.com",
    ]
  }
}
```

Implementation uses nested `for_each` with flattening:

```hcl
locals {
  secret_accessor_pairs = flatten([
    for secret_name, config in var.secrets_config : [
      for accessor in config.accessors : {
        secret_name = secret_name
        accessor    = accessor
        pair_key    = "${secret_name}:${accessor}"
      }
    ]
  ])
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = { for pair in local.secret_accessor_pairs : pair.pair_key => pair }
  # Grants each accessor access to their corresponding secret
}
```

## GCP Label Constraints

Secret descriptions are automatically sanitized to meet GCP label requirements:

**Constraints:**
- Lowercase only
- Maximum 63 characters
- Only `[a-z0-9_-]` characters allowed

**Example transformation:**
```
Input:  "OAuth 2.0 Client ID for Frontend & Backend (Auto-Discovered)"
Output: "oauth-2-0-client-id-for-frontend-backend-au"  (truncated to 63 chars)
```

## Outputs

This module exports:

```hcl
output "secrets" {
  description = "Created secret resources"
  value       = google_secret_manager_secret.this
}

output "iam_bindings" {
  description = "Created IAM bindings"
  value       = google_secret_manager_secret_iam_member.accessor
}
```

## Best Practices

### 1. **Centralize Secret Configuration**

Define all secrets in platform module:
```hcl
# Good: Single location for all secret definitions
module "app_secrets" {
  source = "../core/secrets"
  secrets_config = { ... }
}
```

```hcl
# Bad: Scattered secret creation across modules
# (Don't do this - violates single responsibility principle)
```

### 2. **Group Related Accessors**

Keep secrets focused and accessors grouped logically:
```hcl
# Good: Single secret, multiple related accessors
"OAUTH_CLIENT_ID" = {
  accessors = [
    frontend_trigger_sa,
    backend_trigger_sa,
    backend_run_sa,
  ]
}

# Bad: Mixing unrelated services
"API_KEY" = {
  accessors = [
    frontend_trigger_sa,
    bootstrap_job_sa,
    random_other_service,
  ]
}
```

### 3. **Use Descriptive Names**

Secret names should clearly indicate their purpose:
```hcl
# Good names
"OAUTH_CLIENT_ID"
"DATABASE_PASSWORD"
"API_KEY_EXTERNAL_SERVICE"

# Bad names
"SECRET_1"
"TEMP_SECRET"
"DATA"
```

### 4. **Document Accessor Purposes**

Add comments explaining why each accessor needs the secret:
```hcl
accessors = [
  module.frontend_service.trigger_sa_member,        # Inject at build time
  module.backend_service.trigger_sa_member,         # Validate at build time
  module.backend_service.run_sa_member,             # Access at runtime
]
```

### 5. **Explicit Dependencies**

Always depend on service modules so SAs are created first:
```hcl
depends_on = [
  module.frontend_service,
  module.backend_service,
]
```

## Troubleshooting

### Error: "Service account not found"

**Cause**: Service account member string is malformed

**Solution**: Verify the format is exactly:
```
"serviceAccount:ACCOUNT_EMAIL@PROJECT.iam.gserviceaccount.com"
```

**Check**:
```bash
gcloud iam service-accounts list --filter="email:*cs-be-*"
```

### Error: "Permission denied: Secret already exists"

**Cause**: Secret name already exists in the project (from a previous deployment)

**Solution**:
1. Delete the old secret:
   ```bash
   gcloud secrets delete OAUTH_CLIENT_ID
   ```
2. Re-apply Terraform:
   ```bash
   terraform destroy
   terraform apply
   ```

### Secret not accessible to service account

**Cause**: IAM binding wasn't created or is incorrect

**Solution**: Verify IAM bindings:
```bash
gcloud secrets get-iam-policy OAUTH_CLIENT_ID

# Check the bindings
bindings:
- members:
  - serviceAccount:cs-be-run-dev@project.iam.gserviceaccount.com
  role: roles/secretmanager.secretAccessor
```

## Related Documentation

- [Platform Module](../platform/README.md) - Uses this module for centralized secrets
- [Backend Service Module](../services/backend/README.md) - Exports service account members
- [Frontend Service Module](../services/frontend/README.md) - Exports service account members
- [GCP Secret Manager Documentation](https://cloud.google.com/secret-manager/docs)
- [Terraform google_secret_manager_secret Resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret)
