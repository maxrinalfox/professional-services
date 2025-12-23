# Cloud Run Job Bootstrap - Database Initialization Guide

This guide explains how to deploy and execute the Creative Studio bootstrap job for database initialization, migrations, and seeding.

## Overview

The bootstrap job is a specialized Cloud Run Job that:
- Runs Alembic database migrations
- Seeds initial data
- Creates admin users
- Initializes assets

It runs in a VPC-connected environment with private access to Cloud SQL.

## Architecture

### Container Images

- **`Dockerfile.backend`** - Backend API service (main application)
- **`Dockerfile.bootstrap`** - Bootstrap job (database initialization only)

Both Dockerfiles are in the `backend/` directory and must be maintained separately.

### Key Components

1. **alembic/env.py** - Handles Cloud SQL connections with dynamic IP type selection
2. **config_service.py** - Centralized configuration management
3. **Dockerfile.bootstrap** - Minimal image for bootstrap execution

## Prerequisites

Before deploying the bootstrap job, ensure:

1. **Cloud SQL Instance** exists with:
   - Database user (e.g., `studio_user`)
   - Database created (e.g., `creative_studio`)
   - Private IP configured (if using VPC connector)

2. **Secret Manager** has:
   - Database password secret (e.g., `creative-studio-db-password`)

3. **Service Account** exists with permissions:
   - `roles/cloudsql.client` - Access to Cloud SQL
   - `roles/secretmanager.secretAccessor` - Read secrets

4. **VPC Connector** configured for private Cloud SQL access

## Local Development & Testing

### Deploy Bootstrap Job Locally

To test the bootstrap job before integrating into the pipeline:

```bash
cd examples/creative-studio

# Step 1: Unset any local credentials to avoid conflicts
# This ensures the service account is used instead of local credentials
export GOOGLE_APPLICATION_CREDENTIALS=

# Step 2: Deploy and execute the bootstrap job
gcloud run jobs deploy cstudio-bootstrap-sandbox \
    --source=backend \
    --format json \
    --region=us-central1 \
    --project=YOUR_PROJECT_ID \
    --vpc-connector=projects/YOUR_PROJECT_ID/locations/us-central1/connectors/YOUR_CONNECTOR \
    --vpc-egress=private-ranges-only \
    --service-account=YOUR_BOOTSTRAP_SA@YOUR_PROJECT_ID.iam.gserviceaccount.com \
    --set-cloudsql-instances=YOUR_PROJECT_ID:us-central1:YOUR_INSTANCE \
    --set-env-vars="\
USE_CLOUD_SQL=true,\
INSTANCE_CONNECTION_NAME=YOUR_PROJECT_ID:us-central1:YOUR_INSTANCE,\
USE_CLOUD_SQL_PRIVATE_IP=true,\
DB_NAME=creative_studio,\
DB_USER=studio_user,\
PROJECT_ID=YOUR_PROJECT_ID" \
    --set-secrets="DB_PASS=creative-studio-db-password:latest" \
    --parallelism=1 \
    --max-retries=1 \
    --tasks=1 \
    --execute-now
```

### Environment Variables

#### Regular Environment Variables (--set-env-vars)

| Variable | Description | Example |
|----------|-------------|---------|
| `USE_CLOUD_SQL` | Enable Cloud SQL connector | `true` |
| `INSTANCE_CONNECTION_NAME` | Cloud SQL connection string | `project:region:instance` |
| `USE_CLOUD_SQL_PRIVATE_IP` | Use private IP for connection | `true` |
| `DB_NAME` | Database name | `creative_studio` |
| `DB_USER` | Database username | `studio_user` |
| `PROJECT_ID` | GCP project ID | Your GCP project |

#### Secret Environment Variables (--set-secrets)

Secrets are mounted from Secret Manager as environment variables:

| Variable | Secret Name | Description |
|----------|-------------|-------------|
| `DB_PASS` | `creative-studio-db-password` | Database user password |

**Important:** The `DB_PASS` secret is mounted directly as an environment variable (not as a file). This is handled by Cloud Run's `--set-secrets` flag.

## Cloud Build Integration

### Backend Build Pipeline

**File:** `cloudbuild.yaml`

```yaml
build:
  - Uses: Dockerfile.backend
  - Builds the API service container
  - Deploys to Cloud Run service
```

**Key Configuration:**
```yaml
- '-f'
- 'Dockerfile.backend'
```

### Bootstrap Build Pipeline

**File:** `cloudbuild-bootstrap.yaml`

```yaml
build:
  - Uses: Dockerfile.bootstrap
  - Builds the bootstrap container
  - Deploys to Cloud Run Job
  - Executes the job immediately
```

**Trigger Condition:** Runs when `backend/bootstrap/**` files change

**Key Configuration:**
```yaml
- '-f'
- 'Dockerfile.bootstrap'
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Fails

**Error:** `InvalidPasswordError: password authentication failed`

**Causes:**
- Wrong username in `DB_USER`
- Wrong secret name in `--set-secrets`
- Password mismatch

**Solution:**
```bash
# Verify the actual database users
gcloud sql users list --instance=YOUR_INSTANCE --project=YOUR_PROJECT

# Verify the secret exists
gcloud secrets versions access latest --secret=creative-studio-db-password --project=YOUR_PROJECT
```

#### 2. VPC Connectivity Issues

**Error:** `Network error` or `Connection timeout`

**Causes:**
- VPC Connector not configured
- Cloud SQL instance doesn't have private IP
- Firewall rules blocking connection

**Solution:**
```bash
# Check VPC connector status
gcloud compute networks vpc-access connectors describe YOUR_CONNECTOR \
    --region=us-central1 --project=YOUR_PROJECT

# Verify Cloud SQL private IP
gcloud sql instances describe YOUR_INSTANCE --project=YOUR_PROJECT
```

#### 3. Build Fails with Dockerfile Issues

**Error:** `build failed` during Docker build

**Causes:**
- Wrong Dockerfile referenced
- Missing BuildKit support for `--mount` directives
- Dependencies not installed

**Solution:**
- Ensure `Dockerfile.bootstrap` doesn't use BuildKit-only features
- Check that all dependencies are in `pyproject.toml`

### Checking Job Execution Logs

After deployment, view the execution status:

```bash
# List recent executions
gcloud run jobs list --region=us-central1 --project=YOUR_PROJECT

# View specific execution details
gcloud run jobs executions describe EXECUTION_NAME \
    --region=us-central1 --project=YOUR_PROJECT
```

## Dockerfile Maintenance

### Critical Notes

1. **Dockerfile.bootstrap** is optimized for:
   - Minimal size (no API server)
   - Cloud SQL connectivity
   - Alembic migrations
   - Secret mounting

2. **Do NOT combine** the backend and bootstrap Dockerfiles:
   - They have different purposes
   - Different base images may be optimal
   - Bootstrap needs only migration tools

3. **BuildKit Compatibility**:
   - Cloud Run `--source` deployment doesn't use BuildKit by default
   - Don't use `RUN --mount=type=cache` directives
   - Use simple COPY/RUN commands instead

## Configuration Management

### alembic/env.py

The Alembic configuration dynamically selects the Cloud SQL IP type:

```python
# Uses the config_service.USE_CLOUD_SQL_PRIVATE_IP flag
ip_type = IPTypes.PRIVATE if config_service.USE_CLOUD_SQL_PRIVATE_IP else IPTypes.PUBLIC
```

This allows the same Dockerfile to work with both public and private IP connections.

### config_service.py

All configuration comes from environment variables:

```python
INSTANCE_CONNECTION_NAME: str = ""  # Set by --set-env-vars
DB_USER: str = "postgres"           # Set by --set-env-vars
DB_PASS: str = "password"           # Set by --set-secrets
DB_NAME: str = "creative_studio"    # Set by --set-env-vars
USE_CLOUD_SQL_PRIVATE_IP: bool = False  # Set by --set-env-vars
```

## Security Best Practices

1. **Never pass secrets on command line**
   - ❌ `--set-env-vars="DB_PASS=abc123"`
   - ✅ `--set-secrets="DB_PASS=secret-name:latest"`

2. **Unset local credentials**
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=
   ```
   This ensures the service account is used instead of local credentials.

3. **Service Account Permissions**
   - Use minimal required roles
   - Don't use owner/editor roles
   - Regularly audit permissions

4. **Secret Rotation**
   - Rotate database passwords regularly
   - Update Secret Manager versions
   - Test new passwords before rotating

## Example Workflow

### 1. Prepare Environment

```bash
cd examples/creative-studio

# Verify prerequisites exist
gcloud sql users list --instance=creative-studio-db-c3353262
gcloud secrets list | grep creative-studio
gcloud compute networks vpc-access connectors list --region=us-central1
```

### 2. Deploy and Test Bootstrap Job

```bash
# Unset credentials for service account usage
export GOOGLE_APPLICATION_CREDENTIALS=

# Deploy and execute
gcloud run jobs deploy cstudio-bootstrap-sandbox \
    --source=backend \
    --region=us-central1 \
    --project=YOUR_PROJECT \
    --vpc-connector=projects/YOUR_PROJECT/locations/us-central1/connectors/YOUR_CONNECTOR \
    --service-account=YOUR_SA@YOUR_PROJECT.iam.gserviceaccount.com \
    --set-cloudsql-instances=YOUR_PROJECT:us-central1:YOUR_INSTANCE \
    --set-env-vars="USE_CLOUD_SQL=true,INSTANCE_CONNECTION_NAME=YOUR_PROJECT:us-central1:YOUR_INSTANCE,USE_CLOUD_SQL_PRIVATE_IP=true,DB_NAME=creative_studio,DB_USER=studio_user,PROJECT_ID=YOUR_PROJECT" \
    --set-secrets="DB_PASS=creative-studio-db-password:latest" \
    --parallelism=1 --max-retries=1 --tasks=1 \
    --execute-now
```

### 3. Verify Success

```bash
# Check execution status
gcloud run jobs list --region=us-central1

# View output
gcloud run jobs executions list cstudio-bootstrap-sandbox --region=us-central1
```

### 4. Integrate into Pipeline

Once tested and verified:
- Enable the Cloud Build trigger for `cloudbuild-bootstrap.yaml`
- Trigger runs automatically on `backend/bootstrap/**` changes
- Monitor via Cloud Build console

## References

- [Cloud Run Jobs Documentation](https://cloud.google.com/run/docs/quickstarts/jobs)
- [Cloud SQL Connector Python](https://github.com/GoogleCloudPlatform/cloud-sql-python-connector)
- [Alembic Documentation](https://alembic.sqlalchemy.org/)
- [Cloud Build Documentation](https://cloud.google.com/build/docs)
