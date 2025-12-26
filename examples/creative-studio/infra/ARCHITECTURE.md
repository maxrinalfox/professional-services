# Creative Studio Infrastructure Architecture

## Overview

This is a comprehensive, modular Terraform infrastructure for Google Cloud Platform that deploys the Creative Studio application with:
- Cloud Run services (backend & frontend)
- Cloud SQL PostgreSQL database
- Firebase (web app, Identity Platform, Hosting)
- Cloud Build CI/CD pipelines
- VPC networking
- Cloud Storage (GenMedia bucket)
- Bootstrap automation

The infrastructure is organized into a **hierarchical module structure** for clarity, reusability, and maintainability.

## Module Organization

```
infra/modules/
├── bootstrap/              Cloud Run Job automation (initialized data, migrations)
├── core/                   Shared core infrastructure
│   ├── firebase/          Firebase project, web app, Identity Platform
│   ├── project-setup/     Placeholder (APIs managed in platform)
│   └── storage/           GCS buckets and service accounts
├── data/
│   └── postgresql/        Cloud SQL database
├── networking/            VPC, subnets, VPC connectors
├── platform/              Service orchestration layer (main entry point)
└── services/
    ├── backend/           Backend Cloud Run service + Cloud Build trigger
    └── frontend/          Frontend Cloud Run service + Cloud Build trigger
```

## Key Design Principles

### 1. **Modular & Reusable**
- Each module is self-contained with clear inputs/outputs
- Services manage their own secrets and IAM bindings
- Can be deployed independently or composed together

### 2. **Service Autonomy**
- Backend service module creates and manages its own secrets
- Frontend service module creates and manages its own secrets
- Each service has its own Cloud Build trigger configuration
- Reduces tight coupling between components

### 3. **Clear Separation of Concerns**
- **Platform module**: Orchestration & cross-module coordination
- **Core modules**: Shared infrastructure (Firebase, storage)
- **Services**: Application deployment
- **Data**: Database management
- **Networking**: VPC infrastructure
- **Bootstrap**: Data initialization

### 4. **Predictable Resource Naming**
- Resources follow `cs-{environment}-{component}` pattern
- Makes debugging and monitoring easier
- Consistent across all deployments

## Module Dependency Graph

```
google_project_service (APIs) ─┐
time_sleep (API init)          │
                               ├─► firebase module
                               │
                               ├─► storage module
                               │
                               ├─► vpc_network module
                               │   │
                               │   └─► postgresql module
                               │       │
                               ├───────┤
                               │       │
bootstrap module ◄─────────────┴───────┘
backend_service ◄─────────────────────┐
frontend_service ◄──────────────────────┘
```

## Environment Configurations

### dev-infra-example
- Minimal resources for development/testing
- Public Cloud SQL access enabled
- Single region (us-central1)
- VPC optional (can be disabled)

### prod_ops_sandbox
- Production-like configuration
- Private Cloud SQL with VPC connector
- Multi-region capable
- All security features enabled

## Configuration Management

### Required Environment Variables
- `gcp_project_id`: GCP project ID
- `gcp_region`: GCP region (e.g., us-central1)
- `environment`: Environment name (dev, prod, etc.)

### GitHub Configuration
- `github_repo_owner`: GitHub organization
- `github_repo_name`: GitHub repository
- `github_branch_name`: Branch for Cloud Build triggers
- `github_conn_name`: Cloud Build GitHub connection name

### Service Configuration
- `backend_service_name`: Cloud Run service name for backend
- `frontend_service_name`: Cloud Run service name for frontend
- `backend_custom_audiences`: OAuth audiences for backend
- `frontend_custom_audiences`: OAuth audiences for frontend

### Optional Features
- `enable_cloud_build`: Enable Cloud Build CI/CD (default: true)
- `enable_identity_platform`: Enable Firebase Authentication (default: true)
- `enable_cloud_run_job`: Enable bootstrap Cloud Run Job (default: true)
- `vpc_enable`: Enable VPC networking (default: varies by environment)

## Deployment Flow

### 1. Infrastructure Deployment (Terraform)
```
terraform apply
  ├─ Enables GCP APIs
  ├─ Creates Firebase project
  ├─ Creates VPC (if enabled)
  ├─ Creates Cloud SQL database
  ├─ Creates service accounts & IAM bindings
  ├─ Creates backend Cloud Run service
  ├─ Creates frontend Cloud Run service
  └─ Creates bootstrap Cloud Run Job infrastructure
```

### 2. CI/CD Pipeline (Cloud Build)

**Backend Pipeline** (triggered on backend/** changes):
```
Cloud Build Trigger (backend)
  ├─ Clone repository
  ├─ Build Docker image
  ├─ Push to Artifact Registry
  ├─ Deploy to Cloud Run
  └─ Run health checks
```

**Frontend Pipeline** (triggered on frontend/** changes):
```
Cloud Build Trigger (frontend)
  ├─ Clone repository
  ├─ Inject Firebase config (FIREBASE_APP_ID, etc.)
  ├─ Build web app
  ├─ Push to Artifact Registry
  └─ Deploy to Cloud Run
```

**Bootstrap Pipeline** (triggered on bootstrap/** changes):
```
Cloud Build Trigger (bootstrap)
  ├─ Clone repository
  ├─ Build bootstrap Docker image
  ├─ Push to Artifact Registry
  ├─ Create/Update Cloud Run Job
  └─ Execute job (migrations, initialization)
```

### 3. Application Runtime
```
Frontend (Cloud Run)
  └─ Calls Backend API
      └─ Backend (Cloud Run)
          └─ Reads from Cloud SQL (via VPC or public IP)
          └─ Writes to Cloud Storage (GenMedia bucket)
```

## Cross-Module Dependencies & IAM Bindings

The platform module manages cross-module permissions:

### Frontend → Backend
- Frontend's Cloud Build trigger SA gets `run.viewer` on backend service
- Allows frontend to query backend health/version

### Backend → Storage
- Backend Cloud Run SA gets `storage.objectCreator` on GenMedia bucket
- Allows backend to write generated images

### Bootstrap → Database
- Bootstrap Cloud Run Job SA gets `cloudsql.client` role
- Allows bootstrap to connect to Cloud SQL

### All Services → Secrets
- Each service's SA gets access to its own secrets
- Secrets are managed autonomously within each service module

## Key Features

### Autonomous Secret Management
Each service module manages its own secrets:
- Backend: API keys, database credentials, custom secrets
- Frontend: Firebase SDK config, custom secrets

### Firebase Web App Auto-Discovery
- Firebase web app configuration is automatically discovered from Firebase project
- Eliminates manual secret entry for Firebase SDK values
- Works with both manually created and auto-created web apps

### Predictable URLs
- Backend: `https://{backend_service_name}-{project_number}.{region}.run.app`
- Frontend: `https://{gcp_project_id}.web.app` (Firebase Hosting)

### VPC Private Networking (Optional)
- Cloud SQL can be accessed via VPC connector (private)
- Or public IP (dev environments)
- VPC networking is optional and configurable

### Database Password Management
- Random 32-character password generated per deployment
- Stored securely in Google Secret Manager
- Automatically passed to Cloud SQL module
- Cloud Run services access via environment variables

## Getting Started

### 1. Initialize Terraform
```bash
cd infra/environments/dev-infra-example
terraform init
```

### 2. Review Plan
```bash
terraform plan -out=tfplan
```

### 3. Apply Configuration
```bash
terraform apply tfplan
```

### 4. Monitor Deployment
Cloud Build pipelines will automatically trigger on code changes:
- Push to backend/** triggers backend deployment
- Push to frontend/** triggers frontend deployment
- Push to bootstrap/** triggers bootstrap job

### 5. View Outputs
```bash
terraform output
```

## Monitoring & Debugging

### Cloud Run Logs
```bash
gcloud run services logs read {service-name} --region {region}
```

### Cloud Build Logs
```bash
gcloud builds log {build-id}
```

### Cloud SQL Logs
```bash
gcloud sql operations list --instance={db-instance}
```

### Service Accounts
All service accounts follow naming pattern: `cs-{component}-{environment}`
- `cs-backend-{env}`: Backend Cloud Run service account
- `cs-frontend-{env}`: Frontend Cloud Run service account
- `cs-bootstrap-{env}`: Bootstrap Cloud Run Job service account
- `cs-bootstrap-trigger-{env}`: Bootstrap Cloud Build trigger service account

## Security Considerations

### IAM Best Practices
- Each service has its own service account (principle of least privilege)
- Service accounts only have permissions they need
- Cross-module bindings managed centrally in platform module

### Secret Management
- All secrets stored in Google Secret Manager
- Automatically rotated per secret version
- Accessed via Cloud Run environment variables or mounted volumes

### VPC Security
- Optional private VPC for Cloud SQL
- VPC connectors for egress from Cloud Run
- Network policies can be added as needed

### Firebase Authentication
- Identity Platform enables user authentication
- Firebase SDK handles client-side auth
- Backend validates tokens for all API calls

## Next Steps

See individual module READMEs for detailed information:
- Core modules (Firebase, storage)
- Services (backend, frontend)
- Bootstrap automation
- Database and networking setup
