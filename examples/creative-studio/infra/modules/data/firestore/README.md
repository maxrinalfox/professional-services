# Firestore Database Module

This module creates and manages a Firestore database for the Creative Studio application.

## Overview

The Firestore module automates the creation of a Firestore native database with configurable deletion protection and region settings. Firestore is Google Cloud's NoSQL document database, used for storing application data in the Creative Studio platform.

## Resources Created

- **Google Firestore Database** - Native Firestore database with specified location and deletion protection

## Usage

```hcl
module "firestore" {
  source = "../data/firestore"

  project_id                    = var.gcp_project_id
  gcp_region                    = var.gcp_region
  database_name                 = "cstudio-production"
  allow_destroy                 = false
  deletion_protection_enabled   = true
}
```

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_id` | `string` | Required | The GCP project ID |
| `gcp_region` | `string` | Required | The GCP region for Firestore location (e.g., 'us-central1') |
| `database_name` | `string` | Required | The name of the Firestore database (e.g., 'cstudio-production') |
| `allow_destroy` | `bool` | `false` | Allow Terraform to destroy the Firestore database. Set to true for development/test environments only. |
| `deletion_protection_enabled` | `bool` | `false` | Enable deletion protection for Firestore database (strongly recommended for production) |

## Outputs

| Output | Description |
|--------|-------------|
| `database_name` | The name of the Firestore database |
| `database_id` | The UID of the Firestore database |
| `database_location` | The location of the Firestore database |
| `database_type` | The type of the Firestore database (FIRESTORE_NATIVE) |
| `database_create_time` | The creation time of the Firestore database |

## Deletion Protection

- **Development environments**: Set `deletion_protection_enabled = false` to allow easy cleanup with `terraform destroy`
- **Production environments**: Set `deletion_protection_enabled = true` to prevent accidental deletion

The `allow_destroy` variable is currently informational but can be used in future enhancements for unified destruction control.

## Database Name Conventions

Use environment-specific naming for clarity:
- Development: `cstudio-development`
- Production: `cstudio-production`
- Staging: `cstudio-staging`

## Integration with Platform Module

The platform module automatically manages Firestore database creation with **single source of truth** for the database name:

```hcl
# In platform module
firestore_database_name = "cstudio-${var.environment}"  # Auto-computed from environment

# In environment configuration
firestore_deletion_protection_enabled = true  # Prod: true, Dev: false
```

**Key Design**:
- The Firestore database name is **always computed** from the environment variable (e.g., "cstudio-development", "cstudio-production")
- Users **cannot override** the database name - it's determined entirely by the environment value
- The `FIREBASE_DB` environment variable is set to this same value automatically
- This ensures perfect consistency between the actual database and the application configuration

### Why This Matters

The Firestore module is **always created** (no longer conditional). This eliminates:
- Manual configuration of database names
- Risk of mismatched database names between Terraform and environment variables
- User confusion about which database the application uses
- Inconsistencies between development and production environments

## Important Notes

1. **Database Naming**: This module creates named Firestore databases (e.g., "cstudio-development", "cstudio-production"). The special "(default)" database is created automatically by GCP when Firestore is first enabled - this module doesn't create that.

2. **Provider**: This module uses the `google-beta` provider, which is required for full Firestore database management.

3. **Region Selection**: The region specified should match your application's deployment region for optimal latency.

4. **No Data Loss on Destroy**: When `allow_destroy = true`, the Firestore database can be destroyed via `terraform destroy`. Ensure you have backups if needed.

## Security Considerations

- Use deletion protection in production environments
- Restrict IAM access to Firestore databases using GCP IAM roles
- Consider enabling backups for critical data
- Monitor Firestore usage and costs

## Cost Optimization

Firestore charges are based on:
- Read operations
- Write operations
- Delete operations
- Stored data

Consider implementing:
- Data archival policies
- TTL (time-to-live) for temporary data
- Index optimization
- Composite index cleanup

## Related Modules

- **PostgreSQL Module** (`../postgresql`) - Cloud SQL database for relational data
- **Secrets Module** (`../../core/secrets`) - Secret management for database credentials
- **Platform Module** (`../../platform`) - Orchestrates all modules including Firestore
