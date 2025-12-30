# Data Layer Modules

This directory contains Terraform modules for managing the Creative Studio application's data layer infrastructure.

## Modules Overview

### PostgreSQL (Cloud SQL)

**Path:** `./postgresql`

Manages the Cloud SQL PostgreSQL database instance for the Creative Studio backend.

**Key Features:**
- PostgreSQL 18+ support
- IAM-based authentication
- Public or private IP options (with VPC)
- Deletion protection and allow_destroy controls
- Auto-generated secure passwords

**Usage:**
```hcl
module "postgresql" {
  source = "../data/postgresql"
  project_id = var.gcp_project_id
  gcp_region = var.gcp_region
  db_password = random_password.db_password.result
  public_ip_enabled = true
  allow_destroy = true  # Dev only
  deletion_protection_enabled = false  # Dev only
}
```

**When to Use:**
- Relational data (users, sessions, configuration)
- Structured queries and transactions
- Complex relationships between data entities
- ACID guarantees required

---

### Firestore (NoSQL)

**Path:** `./firestore`

Manages the Firestore native database for document-oriented data storage.

**Key Features:**
- Firestore native database type
- Deletion protection for production safety
- Region-specific deployment
- Optional creation (only if database_name provided)

**Usage:**
```hcl
module "firestore" {
  count = var.firestore_database_name != null ? 1 : 0

  source = "../data/firestore"
  project_id = var.gcp_project_id
  gcp_region = var.gcp_region
  database_name = "cstudio-production"
  deletion_protection_enabled = true
}
```

**When to Use:**
- Document storage (projects, assets, metadata)
- Real-time data synchronization
- Flexible schema requirements
- Mobile and web app backend
- Scalable hierarchical data

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Platform Module                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────┐      ┌──────────────────────┐   │
│  │   PostgreSQL Module  │      │   Firestore Module   │   │
│  ├──────────────────────┤      ├──────────────────────┤   │
│  │ • Cloud SQL Instance │      │ • Firestore Database │   │
│  │ • Database User      │      │ • Region Config      │   │
│  │ • IAM Auth           │      │ • Deletion Protect   │   │
│  └──────────────────────┘      └──────────────────────┘   │
│           ▲                               ▲                 │
│           │                               │                 │
│           └───────────────┬───────────────┘                 │
│                           │                                 │
│                  Accessed by Services:                      │
│                  • Backend (Cloud Run)                      │
│                  • Bootstrap Job                            │
│                  • Cloud Functions (if used)                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Data Layer Design Decisions

### PostgreSQL vs Firestore

The Creative Studio platform uses both databases for different purposes:

| Aspect | PostgreSQL | Firestore |
|--------|-----------|-----------|
| **Data Type** | Relational | Document-oriented |
| **Use Case** | Structured data, transactions | Flexible schema, real-time |
| **Scalability** | Vertical scaling | Horizontal scaling |
| **Querying** | SQL, complex joins | Firestore queries |
| **Consistency** | Strong ACID | Eventual consistency option |
| **Cost Model** | Instance-based | Operations-based |

### Choosing Which Database

**Use PostgreSQL (Cloud SQL) for:**
- User authentication and sessions
- Application configuration
- Transaction-heavy operations
- Complex data relationships
- Historical audit logs

**Use Firestore for:**
- Project metadata and documents
- Real-time synchronization
- Asset information and tags
- User preferences
- Application state

## Deletion Protection

Both modules support deletion protection:

- **Development**: `deletion_protection_enabled = false` - allows quick cleanup
- **Production**: `deletion_protection_enabled = true` - prevents accidental data loss

Combined with the unified `allow_destroy` variable, this provides layered protection:
- Layer 1: GCP-level deletion protection
- Layer 2: Terraform `allow_destroy` flag in environment config

## Common Operations

### Creating a New Environment

1. **Copy environment template:**
   ```bash
   cp -r environments/dev-infra-example environments/my-env
   ```

2. **Update `main.tf` locals:**
   ```hcl
   # Database names
   FIREBASE_DB                     = "cstudio-my-env"
   firestore_database_name         = "cstudio-my-env"

   # Protection settings
   cloud_sql_deletion_protection_enabled    = true   # Prod
   firestore_deletion_protection_enabled    = true   # Prod
   allow_destroy                            = false  # Prod
   ```

3. **Deploy:**
   ```bash
   cd environments/my-env
   terraform init
   terraform apply
   ```

### Destroying Databases

With deletion protection enabled, destruction requires explicit permission:

```hcl
# In your environment's main.tf
allow_destroy = true  # Explicitly allow destruction
cloud_sql_deletion_protection_enabled = false
firestore_deletion_protection_enabled = false
```

Then run:
```bash
terraform destroy
```

**⚠️ WARNING:** This will permanently delete all data. Ensure you have backups before destroying production databases.

## Monitoring and Maintenance

### PostgreSQL (Cloud SQL)

Monitor in GCP Console:
- **Metrics:** CPU, memory, disk, connections
- **Logs:** Query logs, error logs
- **Backups:** Automated daily backups available
- **Replicas:** HA configuration available for production

### Firestore

Monitor in GCP Console:
- **Metrics:** Read/write operations, stored data, latency
- **Indexes:** Monitor index creation and composite indexes
- **Quotas:** Monitor per-database and per-project quotas
- **Backups:** Enable scheduled exports to Cloud Storage

## Related Documentation

- [PostgreSQL Module README](./postgresql/README.md)
- [Firestore Module README](./firestore/README.md)
- [Platform Module Documentation](../platform/README.md)
- [Architecture Overview](../../ARCHITECTURE.md)
