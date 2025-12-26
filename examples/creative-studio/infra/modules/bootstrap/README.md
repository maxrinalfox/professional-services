# Bootstrap Module

## Overview

This module manages the bootstrap infrastructure for Creative Studio:
- Cloud Run Job for data initialization
- Database migrations
- Seed data loading
- Cloud Build trigger for bootstrap automation
- Service accounts and IAM bindings
- Artifact Registry for bootstrap images

## Architecture

```
┌──────────────────────────────────────────────────────┐
│   Cloud Build Bootstrap Trigger (Manual)             │
│   Listens on bootstrap/** changes                    │
└──────────────┬───────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────┐
│   Cloud Run Job: Bootstrap                           │
│   - Initialization scripts                           │
│   - Database migrations                             │
│   - Seed data loading                               │
│   - Environment setup                               │
└──────────────┬───────────────────────────────────────┘
               │
      ┌────────┴────────┐
      │                 │
      ▼                 ▼
┌──────────────┐  ┌──────────────────┐
│ Cloud SQL    │  │ Cloud Storage    │
│ (Database)   │  │ (GenMedia bucket)│
└──────────────┘  └──────────────────┘
```

## Module Variables

### Required Variables

```hcl
gcp_project_id              # GCP project ID
gcp_region                  # GCP region
environment                 # Environment name (dev, prod, etc.)
enable_cloud_build          # Enable Cloud Build trigger
enable_cloud_run_job        # Enable Cloud Run Job
genmedia_bucket_name        # Storage bucket name
bootstrap_job_secrets       # Secrets for bootstrap job
source_repository_id        # Cloud Build V2 repository ID
github_branch_name          # GitHub branch for triggers
bootstrap_image_name        # Docker image name
cloud_sql_connection_name   # Cloud SQL connection string
initial_admin_user_email    # Admin user email for initialization
```

### Optional Variables

```hcl
bootstrap_job_cpu              # CPU allocation (default: "2000m")
bootstrap_job_memory           # Memory allocation (default: "2048Mi")
bootstrap_job_timeout          # Timeout in seconds (default: 3600)
bootstrap_job_log_level        # Log level (default: "INFO")
bootstrap_job_environment_variables  # Custom env vars
bootstrap_job_name             # Job name (auto-generated if null)
vpc_connector_name             # VPC connector for private networking
```

## Module Outputs

```hcl
bootstrap_sa_email             # Bootstrap job service account email
bootstrap_trigger_sa_email     # Cloud Build trigger service account email
bootstrap_repo_name            # Artifact Registry repository name
```

## Cloud Run Job vs Service

Bootstrap uses **Cloud Run Job**, not Cloud Run Service:

| Aspect | Service | Job |
|--------|---------|-----|
| **Runtime** | Long-running | One-time or scheduled |
| **Scaling** | Auto-scales to 0+ replicas | Single execution per task |
| **Use case** | Web APIs, continuous apps | Batch jobs, migrations |
| **Pricing** | Per request + memory/CPU time | Per execution time |
| **Health checks** | Continuous | N/A |

## Cloud Build Trigger Configuration

The bootstrap module creates a Cloud Build trigger that:

### Trigger Details
- **Source**: GitHub repository
- **Branch**: Specified branch (usually `main`)
- **Included Files**: Changes to `backend/bootstrap/**` or `backend/cloudbuild-bootstrap.yaml`
- **Condition**: Only triggers when bootstrap code changes

### Build Process

Executes `examples/creative-studio/backend/cloudbuild-bootstrap.yaml`:

```yaml
steps:
  # Step 1: Build Docker image with bootstrap code
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/bootstrap:${SHORT_SHA}'
      - '-f'
      - 'examples/creative-studio/backend/Dockerfile.bootstrap'
      - '.'

  # Step 2: Push image to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/bootstrap:${SHORT_SHA}'

  # Step 3: Create/Update Cloud Run Job
  - name: 'gcr.io/cloud-builders/gke-deploy'
    args:
      - 'run'
      - '-f=.'
      - '-l=app=bootstrap'

  # Step 4: Execute the job
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'run'
      - 'jobs'
      - 'execute'
      - '${_BOOTSTRAP_JOB_NAME}'
      - '--region=${_REGION}'
```

### Build Substitutions

```
_REGION                    # GCP region
_REPO_NAME                 # Artifact Registry repository name
_BOOTSTRAP_JOB_NAME        # Cloud Run Job name
_BOOTSTRAP_SERVICE_ACCOUNT # Service account email
_CLOUD_SQL_CONNECTION_NAME # Cloud SQL connection string
_GENMEDIA_BUCKET           # Cloud Storage bucket name
_BOOTSTRAP_SECRETS         # Comma-separated secret references
_VPC_CONNECTOR_NAME        # VPC connector name (if applicable)
```

## Service Accounts

### Bootstrap Job Service Account
- Name: `cs-bootstrap-{environment}`
- Used to run the Cloud Run Job
- Permissions:
  - **Cloud SQL Client**: Connect to database
  - **Secret Accessor**: Read job secrets
  - **Storage Object Creator**: Write to GenMedia bucket

### Bootstrap Trigger Service Account
- Name: `cs-bootstrap-trigger-{environment}`
- Used for Cloud Build trigger execution
- Permissions:
  - **Cloud Build Editor**: Manage builds
  - **Cloud Run Job Operator**: Create/update jobs
  - **Artifact Registry Writer**: Push images
  - **Service Account User**: Impersonate bootstrap job SA

## Bootstrap Job Configuration

### Docker Image

The bootstrap Docker image is built from `Dockerfile.bootstrap`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Copy bootstrap code
COPY backend/bootstrap/ /app/bootstrap/
COPY backend/requirements.txt /app/

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Set environment
ENV PYTHONUNBUFFERED=1

# Run bootstrap entry point
ENTRYPOINT ["python", "-m", "bootstrap.main"]
```

### Environment Variables

Bootstrap job receives environment variables:

```hcl
env {
  name = "DATABASE_URL"
  value = "postgresql://user:password@host:5432/dbname"
}
env {
  name = "CLOUD_SQL_CONNECTION_NAME"
  value = "project:region:instance"
}
env {
  name = "GENMEDIA_BUCKET"
  value = "bucket-name"
}
env {
  name = "INITIAL_ADMIN_EMAIL"
  value = "admin@company.com"
}
```

### Secrets

Bootstrap job accesses secrets from Google Secret Manager:

```hcl
secretVolume {
  name = "db-password"
  secretVersion = "projects/PROJECT_ID/secrets/db-password/versions/latest"
  path = "/secrets/db-password"
}
```

Mounted secrets are available at:
```
/secrets/{secret-name}
```

### Resource Limits

```hcl
cpu = "2000m"    # 2 vCPU
memory = "2048Mi" # 2 GB
timeout = 3600   # 1 hour
```

For longer operations (bulk migrations):
```hcl
timeout = 7200  # 2 hours
```

## Execution Models

### Manual Trigger

Cloud Build trigger on code changes:

```bash
# Push code to trigger build
git push origin main
# Changes in backend/bootstrap/** detected
# Cloud Build starts automatically
# Job executes on successful build
```

### Scheduled Execution

Can be extended to run on schedule:

```hcl
resource "google_cloud_scheduler_job" "bootstrap_schedule" {
  name     = "cs-bootstrap-daily"
  schedule = "0 2 * * *"  # 2 AM daily
  
  http_target {
    uri = "https://...googleapis.com/..."
  }
}
```

### Manual Execution

Run job manually:

```bash
gcloud run jobs execute cs-bootstrap-{environment} \
  --region {region} \
  --wait
```

## Bootstrap Execution Flow

### 1. Cloud Build Trigger Activated
```
Trigger Condition Met:
├─ Push to main branch detected
├─ Changes in backend/bootstrap/**
└─ cloudbuild-bootstrap.yaml executed
```

### 2. Docker Build
```
Build Steps:
├─ Build Docker image
├─ Tag with commit SHA
└─ Push to Artifact Registry
```

### 3. Job Creation/Update
```
Cloud Run Job:
├─ Create or update job definition
├─ Set environment variables
├─ Set resource limits
└─ Ready for execution
```

### 4. Job Execution
```
Execution:
├─ Start container
├─ Mount secrets
├─ Run bootstrap code
│  ├─ Database migrations
│  ├─ Seed data
│  └─ Initialization
├─ Write logs
└─ Exit with status
```

### 5. Completion Handling
```
Post-Execution:
├─ Logs written to Cloud Logging
├─ Status recorded
└─ Success/Failure notification (optional)
```

## Bootstrap Code Example

### Python Bootstrap Entry Point

`backend/bootstrap/main.py`:

```python
#!/usr/bin/env python3
"""Bootstrap application initialization."""

import asyncio
import logging
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from bootstrap.database import init_db
from bootstrap.seed import load_seed_data
from bootstrap.migrations import run_migrations

logger = logging.getLogger(__name__)

async def main():
    """Execute bootstrap tasks."""
    
    # Database setup
    engine = create_engine(os.environ["DATABASE_URL"])
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()
    
    try:
        # Run migrations
        logger.info("Running database migrations...")
        await run_migrations(session)
        
        # Initialize database
        logger.info("Initializing database...")
        await init_db(session)
        
        # Load seed data
        logger.info("Loading seed data...")
        await load_seed_data(session)
        
        # Create admin user
        logger.info("Creating admin user...")
        admin_email = os.environ["INITIAL_ADMIN_EMAIL"]
        await create_admin_user(session, admin_email)
        
        logger.info("Bootstrap completed successfully")
        return 0
        
    except Exception as e:
        logger.error(f"Bootstrap failed: {e}")
        return 1
    finally:
        session.close()

if __name__ == "__main__":
    exit(asyncio.run(main()))
```

## Monitoring & Logs

### View Job Execution

```bash
# List recent job executions
gcloud run jobs executions list \
  --job=cs-bootstrap-{environment} \
  --region {region}

# Get job execution details
gcloud run jobs executions describe {execution-id} \
  --job=cs-bootstrap-{environment} \
  --region {region}
```

### Cloud Logging

```bash
# View job logs
gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=cs-bootstrap-{environment}" \
  --limit 100

# View build logs
gcloud builds log {build-id}
```

### Job Status

```bash
gcloud run jobs describe cs-bootstrap-{environment} --region {region}
# Shows:
# - Last execution status
# - Last execution timestamp
# - Image URI
# - Environment variables
# - Service account
```

## Troubleshooting

### Job Fails to Start

1. **Check service account permissions**
   ```bash
   gcloud projects get-iam-policy PROJECT_ID \
     --flatten="bindings[].members" \
     --filter="bindings.members:cs-bootstrap-trigger-*"
   ```

2. **Check Cloud SQL connection**
   ```bash
   gcloud sql instances describe {instance-id}
   ```

3. **Verify secrets exist**
   ```bash
   gcloud secrets list
   ```

### Job Times Out

1. **Check execution logs**
   ```bash
   gcloud logging read "resource.type=cloud_run_job" --limit 20
   ```

2. **Increase timeout**
   ```hcl
   bootstrap_job_timeout = 7200  # Increase to 2 hours
   ```

3. **Optimize bootstrap code**
   - Batch database operations
   - Use bulk insert instead of individual inserts
   - Optimize queries

### Database Connection Issues

1. **For private IP (VPC)**
   ```bash
   # Verify VPC connector
   gcloud compute networks vpc-access connectors describe {connector-name} \
     --region {region}
   ```

2. **For public IP**
   ```bash
   # Check firewall rules
   gcloud sql instances describe {instance-id} \
     --format="value(ipAddresses[])"
   ```

3. **Test connection manually**
   ```bash
   psql postgresql://user:pass@host/dbname
   ```

### Secret Access Issues

1. **Check IAM permissions**
   ```bash
   gcloud secrets get-iam-policy db-password
   ```

2. **Verify service account has access**
   ```bash
   gcloud secrets add-iam-policy-binding db-password \
     --member=serviceAccount:cs-bootstrap-{env}@project.iam.gserviceaccount.com \
     --role=roles/secretmanager.secretAccessor
   ```

## Cost Optimization

### Resource Allocation
- **Small jobs** (< 5 minutes): 500m CPU, 512Mi memory
- **Medium jobs** (5-20 minutes): 1000m CPU, 1024Mi memory
- **Large jobs** (> 20 minutes): 2000m CPU, 2048Mi memory

### Execution Frequency
- Run only when code changes (triggered by Cloud Build)
- Don't run unnecessarily
- Use scheduled jobs only for recurring tasks

### Logging
- Keep logs to essential information
- Archive old logs to Cloud Storage
- Set retention policies

## Related Documentation

- [Cloud Build Trigger Details](./BUILD_TRIGGERS.md)
- [Database Module](../../data/postgresql/README.md)
- [Cloud Storage Setup](../../core/storage/README.md)
- [Platform Module](../platform/README.md)
- [Backend Service](../services/backend/README.md)
