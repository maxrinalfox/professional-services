# Backend Service Module

## Overview

This module deploys and manages the Creative Studio backend service on Google Cloud Run. It includes:
- Cloud Run service configuration
- Autonomous secret management
- Cloud Build trigger for CI/CD
- Service account and IAM bindings
- Health checks and monitoring
- Database connectivity (Cloud SQL)

## Architecture

```
┌─────────────────────────────────────────────────────┐
│         Backend Cloud Run Service                   │
├─────────────────────────────────────────────────────┤
│  • Python/FastAPI application                       │
│  • RESTful API for creative operations              │
│  • Database connectivity (Cloud SQL)                │
│  • Storage integration (Cloud Storage)              │
└──────────────┬──────────────────────────────────────┘
               │
      ┌────────┴────────┐
      │                 │
      ▼                 ▼
┌──────────────┐  ┌─────────────────┐
│ Cloud Build  │  │ Service Account │
│ CI/CD Trigger│  │  (Least Priv)   │
└──────────────┘  └─────────────────┘
      │                 │
      └────────┬────────┘
               │
      ┌────────┴────────┐
      │                 │
      ▼                 ▼
┌──────────────┐  ┌──────────────┐
│ Secrets      │  │ Cloud SQL    │
│ (API keys)   │  │ (Database)   │
└──────────────┘  └──────────────┘
```

## Module Variables

### Required Variables

```hcl
gcp_project_id              # GCP project ID
gcp_region                  # GCP region for resources
environment                 # Environment name (dev, prod, etc.)
service_name                # Cloud Run service name
resource_prefix             # Resource naming prefix (e.g., "cs-be")

# GitHub Configuration
github_conn_name            # Cloud Build GitHub connection name
github_repo_owner           # GitHub organization/owner
github_repo_name            # GitHub repository name
github_branch_name          # Branch for Cloud Build trigger

# Cloud Build Configuration
cloudbuild_yaml_path        # Path to cloudbuild.yaml
included_files_glob         # File patterns that trigger the build

# Database Configuration
cloud_sql_connection_name   # Cloud SQL instance connection string
db_name                     # Database name
db_user                     # Database user
db_secret_id                # Secret Manager secret ID for DB password
```

### Optional Variables

```hcl
environment_variables       # Container environment variables (map)
runtime_secrets            # Runtime secret names (list)
custom_audiences           # OAuth custom audiences (list)
source_repository_id       # Cloud Build V2 repository ID (from backend module)
vpc_connector_id          # VPC connector ID (for private networking)
invoker_identities        # Service accounts/users who can invoke the service
enable_cloud_build_trigger # Whether to create the Cloud Build trigger
backend_secrets           # Backend-specific secrets to create
build_substitutions       # Cloud Build substitution variables

# Resource Configuration
cpu                       # CPU allocation (default: "1000m")
memory                    # Memory allocation (default: "512Mi")
scaling_min_instances     # Minimum replicas (default: 1)
timeout_seconds          # Request timeout (default: 300)
```

## Module Outputs

```hcl
service_name              # Cloud Run service name
service_url               # HTTPS URL of the service
service_iam_done         # Signal for IAM binding dependencies
run_sa_member            # Service account member string (for IAM)
location                 # Cloud Run service location
```

## Cloud Build Trigger Configuration

The backend module automatically creates a Cloud Build trigger that:

### Trigger Mechanism
- **Source**: GitHub repository (via Cloud Build GitHub connection)
- **Branch**: Specified branch (usually `main` or `develop`)
- **Included Files**: Only triggers on changes to `**/creative-studio/backend/**`

### Build Process

The trigger executes the `examples/creative-studio/backend/cloudbuild.yaml` which:

1. **Checkout**: Clones the repository at the specified branch
2. **Build**: Builds Docker image with:
   - Application code
   - Dependencies
   - Configuration
3. **Push**: Pushes image to Artifact Registry
4. **Deploy**: Deploys to Cloud Run with:
   - Environment variables
   - Database credentials (via Secret Manager)
   - VPC connector (if enabled)
   - Service account (least privilege)
5. **Health Check**: Verifies service is running

### Build Substitutions

The Cloud Build trigger automatically injects these substitutions (from Terraform):

```
_REGION              # GCP region
_SERVICE_NAME        # Backend service name
_REPO_NAME           # Artifact Registry repository name
_ARTIFACT_REGISTRY   # Artifact Registry location

# NEW: Environment variables and secrets (set by platform module)
_BACKEND_ENV_VARS    # Comma-separated KEY=VALUE pairs for container env vars
_BACKEND_SECRETS     # Comma-separated ENV_VAR=SECRET_NAME:VERSION pairs
```

Example values passed by Terraform:
```
_BACKEND_ENV_VARS = "LOG_LEVEL=INFO,ENVIRONMENT=development,CORS_ORIGINS=[\"https://example.com\"]"
_BACKEND_SECRETS = "GOOGLE_TOKEN_AUDIENCE=OAUTH_CLIENT_ID:latest"
```

These are used in `cloudbuild.yaml` deploy step:
```yaml
gcloud run deploy $SERVICE_NAME \
  --set-env-vars=$_BACKEND_ENV_VARS \
  --set-secrets=$_BACKEND_SECRETS \
  --image=$IMAGE \
  ...
```

### Secrets in Cloud Build

The backend Cloud Build trigger has access to:
- `db-password`: Database password (managed by platform module)
- Custom backend secrets (managed by backend module)

Accessed in `cloudbuild.yaml`:
```yaml
env:
  - versionName: projects/$PROJECT_ID/secrets/db-password/versions/latest
    variable: DB_PASSWORD
```

## Environment Variables & Secrets

### Key Design: Infrastructure (Terraform) vs. Application Configuration (Cloud Build)

**Important**: Environment variables and secrets are **NOT set by Terraform**. Instead:

- **Terraform** creates the Cloud Run service infrastructure without env vars/secrets
- **Cloud Build** sets all environment variables and secrets when deploying the application

**Why this approach?**
1. Service can be created before Secret Manager secrets have values
2. Service can be created before IAM bindings exist (they're created separately by platform module)
3. Cloud Run doesn't try to validate secrets during service creation
4. Application configuration is managed by CI/CD pipeline, not infrastructure code
5. Prevents "Permission denied on secret" errors during `terraform apply`

### Container Environment Variables

Environment variables are built in the platform module with both **user-customizable** and **protected** values:

#### User-Customizable Variables
Users provide these in their environment configuration (e.g., `be_env_vars`):
```hcl
{
  "LOG_LEVEL"                      = "INFO"
  "IDENTITY_PLATFORM_ALLOWED_ORGS" = ""
  # Add any custom app-level variables here
}
```

#### Protected (Auto-Computed) Variables
The platform module automatically computes these and they **cannot be overridden**:
```hcl
backend_env_vars_protected = {
  "ENVIRONMENT"  = var.environment              # e.g., "development" or "production"
  "FIREBASE_DB"  = "cstudio-${environment}"   # e.g., "cstudio-development"
}
```

#### Final Environment Variables (Merged)
The platform module merges all sources with **protected values taking precedence**:
```hcl
backend_env_vars = merge(
  var.be_env_vars,        # User variables (lowest priority)
  {                        # Computed infrastructure vars (medium priority)
    "CORS_ORIGINS"         = "[\"${frontend_url}\"]"
    "GENMEDIA_BUCKET"      = bucket_name
    "SIGNING_SA_EMAIL"     = service_account_email
    "USE_CLOUD_SQL_PRIVATE_IP" = ...
  },
  backend_env_vars_protected  # Protected vars (highest priority - always win)
)
```

**Result Example**: For environment="development":
```hcl
{
  "LOG_LEVEL"                      = "INFO"
  "IDENTITY_PLATFORM_ALLOWED_ORGS" = ""
  "CORS_ORIGINS"                   = "[\"https://project.web.app\"]"
  "GENMEDIA_BUCKET"                = "cs-genmedia-development-bucket"
  "SIGNING_SA_EMAIL"               = "cs-be-development-run@project.iam.gserviceaccount.com"
  "USE_CLOUD_SQL_PRIVATE_IP"       = "true"
  "ENVIRONMENT"                    = "development"        # Protected
  "FIREBASE_DB"                    = "cstudio-development" # Protected
}
```

#### Passing to Cloud Build
These environment variables are passed to Cloud Build as `_BACKEND_ENV_VARS` substitution (comma-separated KEY=VALUE pairs):

```hcl
_BACKEND_ENV_VARS = join(",", [for k, v in var.container_env_vars : "${k}=${v}"])
# Result: "LOG_LEVEL=INFO,ENVIRONMENT=development,FIREBASE_DB=cstudio-development,..."
```

**Cloud Build then sets them** when deploying:
```bash
gcloud run deploy $SERVICE_NAME \
  --set-env-vars=${_BACKEND_ENV_VARS} \
  --image=$IMAGE \
  ...
```

The `gcloud run deploy` command receives all variables including protected ones:
```bash
--set-env-vars=LOG_LEVEL=INFO,ENVIRONMENT=development,FIREBASE_DB=cstudio-development,...
```

### Runtime Secrets

Secrets from Google Secret Manager are mapped to environment variables:

```hcl
runtime_secrets = {
  "GOOGLE_TOKEN_AUDIENCE" = "OAUTH_CLIENT_ID"  # Maps env var to secret name
}
```

These are passed to Cloud Build as `_BACKEND_SECRETS` substitution (comma-separated ENV_VAR=SECRET_NAME:VERSION pairs).

**Cloud Build then sets them** when deploying:
```bash
gcloud run deploy $SERVICE_NAME \
  --set-secrets=GOOGLE_TOKEN_AUDIENCE=OAUTH_CLIENT_ID:latest \
  ...
```

### Why Secrets Are Set by Cloud Build (Not Terraform)

1. **Timing**: Terraform creates the service, then the platform module creates IAM bindings
2. **Ordering**: Cloud Build runs AFTER IAM bindings exist
3. **Decoupling**: Secrets don't need to exist or have values when service is created
4. **Redeployment**: Cloud Build can update secrets and redeploy without Terraform changes

### Database Credentials

Database password is automatically injected:
1. Generated randomly (32 characters with special chars)
2. Stored in Google Secret Manager
3. Passed to Cloud SQL module
4. Available to Cloud Run service as environment variable

```hcl
env {
  name = "DATABASE_PASSWORD"
  valueFrom {
    secretKeyRef {
      name = "db-password"
      key  = "latest"
    }
  }
}
```

## Custom Audiences (OAuth)

Custom audiences are used for OAuth 2.0 validation:

```hcl
custom_audiences = [
  "project-123456",           # GCP Project ID (auto-added)
  "123456789.apps.googleusercontent.com"  # OAuth Client ID
]
```

These audiences are passed to:
- Firebase Admin SDK for token validation
- Custom middleware for OAuth checks

## VPC & Private Networking

If VPC is enabled, the service is configured for private networking:

```hcl
vpc_connector_id = "projects/PROJECT_ID/locations/REGION/connectors/CONNECTOR_NAME"
```

This:
- Routes all egress through VPC connector
- Allows private Cloud SQL connections
- Requires VPC connector to be running

## Service Account & IAM

### Service Account
- Created automatically: `cs-backend-{environment}`
- Used for Cloud Run service execution
- Has minimal required permissions

### IAM Bindings (Principle of Least Privilege)
1. **Cloud SQL Client**: Access to Cloud SQL instance
2. **Secret Accessor**: Read access to own secrets
3. **Storage Object Creator**: Write to GenMedia bucket
4. **Artifact Registry**: Read access to pull images

## Secret Management

**Secrets are now managed centrally by the Platform module's `core/secrets` module.** This module no longer creates its own secrets.

### How It Works

1. **Secret Creation**: Platform module creates all application secrets (e.g., `OAUTH_CLIENT_ID`)
2. **Permission Granting**: Platform module automatically grants this backend service account access via IAM bindings
3. **Runtime Access**: Backend Cloud Run reads the secret using the mapped environment variable name (e.g., `GOOGLE_TOKEN_AUDIENCE`)

### Backend Service Account

This module exports the backend service account member references that the platform module uses:

```hcl
# Backend module outputs
output "run_sa_member" {
  description = "Backend Cloud Run service account member string (for IAM)"
}

output "trigger_sa_member" {
  description = "Backend Cloud Build trigger service account member string (for IAM)"
}
```

These are used by the platform module to grant secret access:

```hcl
# In platform module
module "app_secrets" {
  secrets_config = {
    "OAUTH_CLIENT_ID" = {
      accessors = [
        module.backend_service.trigger_sa_member,  # For Cloud Build
        module.backend_service.run_sa_member,      # For Cloud Run runtime
      ]
    }
  }
}
```

## Deployment Workflow

### 1. Push Code to Repository
```bash
git push origin main
# Changes in backend/** detected
```

### 2. Cloud Build Trigger Activates
```
Cloud Build Start
├─ Source: GitHub repo @ main branch
├─ Checkout: specific commit
└─ Execute: cloudbuild.yaml
```

### 3. Docker Build & Push
```dockerfile
FROM python:3.11-slim
COPY backend/ /app/
RUN pip install -r requirements.txt
CMD ["uvicorn", "main:app"]
```

Image pushed to:
```
{region}-docker.pkg.dev/{project}/cloud-run-service/backend:{commit-sha}
```

### 4. Cloud Run Deployment
```
gcloud run deploy {service-name}
├─ Image: artifact-registry-image
├─ Region: specified region
├─ Memory: specified memory
├─ CPU: specified CPU
├─ Timeout: 300 seconds
├─ Port: 8080 (default)
├─ Env vars: injected
└─ Secrets: mounted
```

### 5. Service Starts
- Replicas: min_instances to handle load
- Health checks: /health endpoint
- Ready: receives traffic

## Database Connectivity

### Public IP (Development)
```hcl
cloud_sql_public_ip_enabled = true
# Connection: {project}:{region}:{instance}
# Access: via public IP (firewall rules apply)
```

### Private IP (Production)
```hcl
cloud_sql_public_ip_enabled = false
vpc_connector_id = "connector-id"
# Connection: via VPC connector (private)
# Access: internal only
```

## Monitoring & Logs

### Cloud Run Logs
```bash
gcloud run services logs read {service-name} --region {region} --limit 50
```

### Cloud Build Logs
```bash
gcloud builds log {build-id}
```

### Metrics
- Request latency
- Error rates
- Concurrent requests
- CPU utilization
- Memory usage

Access via:
- Cloud Console > Cloud Run > Service > Metrics
- Cloud Monitoring dashboard

## Health Checks

The Cloud Run service should expose:
```python
@app.get("/health")
async def health():
    return {"status": "ok", "timestamp": datetime.now()}
```

Cloud Run automatically checks this endpoint:
- Interval: 5 seconds
- Timeout: 1 second
- Unhealthy threshold: 2 failures
- Healthy threshold: 2 successes

## Scaling

### Minimum Replicas
```hcl
scaling_min_instances = 1  # Min 0 (cold start), typical 1-2
```

### Maximum Replicas
Determined by Cloud Run limits and CPU/memory allocation

### Concurrency
Max concurrent requests per replica:
```hcl
concurrency = 80  # Typical for REST APIs
```

## Invoker Access Control

Control who can invoke the service:

```hcl
invoker_identities = [
  "serviceAccount:frontend-sa@project.iam.gserviceaccount.com",
  "user:admin@company.com"
]
```

Grants `run.invoker` role to specified identities

## Cost Optimization

### Memory & CPU
- **Development**: 512Mi / 250m (1 vCPU)
- **Production**: 2048Mi / 1000m (1 vCPU)
- Cost scales with allocation and requests

### Scaling Strategy
- Min instances: 1 (avoid cold starts)
- Auto-scale on CPU usage (80% threshold)
- Max instances: based on projected load

### Cloud Build
- Triggered only on code changes
- Cleanup old builds after 30 days
- Archive logs to Cloud Storage

## Troubleshooting

### Deployment Fails

1. **Check Cloud Build logs**
   ```bash
   gcloud builds log {build-id} --limit 100
   ```
   Common issues:
   - Docker build fails (syntax error, missing dependency)
   - Image push fails (permission denied)
   - Deployment fails (invalid configuration)

2. **Verify service account permissions**
   ```bash
   gcloud projects get-iam-policy PROJECT_ID \
     --flatten="bindings[].members" \
     --filter="bindings.members:cs-backend-*"
   ```

3. **Check secrets exist**
   ```bash
   gcloud secrets list
   gcloud secrets versions access latest --secret=db-password
   ```

### Service Won't Start

1. **Check Cloud Run logs**
   ```bash
   gcloud run services logs read {service-name} --region {region}
   ```
   Look for:
   - Port binding errors (must use 8080)
   - Missing environment variables
   - Database connection timeouts
   - Secret access denied

2. **Verify database connectivity**
   ```bash
   gcloud sql operations list --instance={db-instance}
   ```

3. **Check VPC connector status**
   ```bash
   gcloud compute networks vpc-access connectors describe {connector-name} \
     --region {region}
   ```

### High Latency or Errors

1. **Check metrics**
   - Cloud Run > Service > Metrics
   - Look for error rate spikes
   - Check CPU/memory utilization

2. **Scale service**
   - Increase min_instances
   - Increase memory/CPU
   - Adjust scaling parameters

3. **Check database**
   - Cloud SQL > Instances > Operations
   - Look for slow queries
   - Monitor connections

## Related Documentation

- [Cloud Build Trigger Details](./BUILD_TRIGGERS.md)
- [Backend Architecture](../../../../backend/README.md)
- [Platform Module](../platform/README.md)
- [Database Module](../../data/postgresql/README.md)
- [Firebase Setup](../../core/firebase/README.md)
