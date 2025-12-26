# Cloud Build Triggers Documentation

## Overview

Cloud Build automates the entire CI/CD pipeline for Creative Studio. Three separate Cloud Build triggers manage:
1. **Backend Service**: API deployment
2. **Frontend Service**: Web app deployment
3. **Bootstrap Job**: Database initialization and migrations

Each trigger has its own configuration, secrets, and execution flow.

## Trigger Architecture

```
GitHub Push Event
  │
  ├─────────────────────────────────────────────┐
  │                                             │
  ▼ Match: backend/**                           ▼ Match: frontend/**                ▼ Match: bootstrap/**
┌──────────────────────────┐           ┌──────────────────────────┐    ┌──────────────────────────┐
│ Backend Cloud Build      │           │ Frontend Cloud Build     │    │ Bootstrap Cloud Build    │
│ Trigger                  │           │ Trigger                  │    │ Trigger                  │
├──────────────────────────┤           ├──────────────────────────┤    ├──────────────────────────┤
│ cloudbuild.yaml (backend)│           │ cloudbuild-deploy.yaml   │    │ cloudbuild-bootstrap.yaml│
│ ├─ Build Docker image    │           │ ├─ Inject Firebase config│    │ ├─ Build Docker image    │
│ ├─ Push to registry      │           │ ├─ Build React app       │    │ ├─ Push to registry      │
│ ├─ Deploy to Cloud Run   │           │ ├─ Push to registry      │    │ ├─ Create Cloud Run Job  │
│ └─ Health check          │           │ └─ Deploy to Cloud Run   │    │ └─ Execute job           │
└──────────────────────────┘           └──────────────────────────┘    └──────────────────────────┘
  │                                      │                              │
  ▼                                      ▼                              ▼
┌──────────────────────┐        ┌──────────────────────┐       ┌──────────────────────┐
│ Backend Service      │        │ Frontend Service     │       │ Cloud Run Job        │
│ (Cloud Run)          │        │ (Cloud Run)          │       │ (Bootstrap)          │
│ ├─ /health           │        │ ├─ /index.html       │       │ ├─ Migrations        │
│ ├─ /api/**           │        │ ├─ /api/** (via BE)  │       │ ├─ Seed data         │
│ └─ Database access   │        │ └─ Firebase config   │       │ └─ Initialization    │
└──────────────────────┘        └──────────────────────┘       └──────────────────────┘
```

## Backend Cloud Build Trigger

### Trigger Configuration

**File**: `examples/creative-studio/backend/cloudbuild.yaml`

```yaml
steps:
  # Step 1: Build Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_BACKEND_REGISTRY}/backend:${SHORT_SHA}'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_BACKEND_REGISTRY}/backend:latest'
      - '-f'
      - 'examples/creative-studio/backend/Dockerfile'
      - '.'

  # Step 2: Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_BACKEND_REGISTRY}/backend:${SHORT_SHA}'

  # Step 3: Deploy to Cloud Run
  - name: 'gcr.io/cloud-builders/gke-deploy'
    args:
      - 'run'
      - '-f=examples/creative-studio/backend/k8s/'

  # Step 4: Health check
  - name: 'gcr.io/cloud-builders/kubectl'
    args:
      - 'rollout'
      - 'status'
      - 'deployment/backend'
```

### Automatic Substitutions

The platform module automatically injects:

```hcl
build_substitutions = merge(var.be_build_substitutions, {
  _REGION       = var.gcp_region
  _SERVICE_NAME = var.backend_service_name
})
```

Available in `cloudbuild.yaml`:
```yaml
env:
  - name: REGION
    value: '${_REGION}'  # e.g., "us-central1"
  - name: SERVICE_NAME
    value: '${_SERVICE_NAME}'  # e.g., "backend-api"
```

### Service Account

The Cloud Build trigger uses service account: `cs-be-trigger-{environment}`

Permissions:
- `roles/artifactregistry.writer` - Push Docker images
- `roles/run.admin` - Deploy to Cloud Run
- `roles/secretmanager.secretAccessor` - Access database password
- `roles/iam.serviceAccountUser` - Impersonate backend service account

### Secrets

Accessible in `cloudbuild.yaml`:

```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    secretEnv:
      - 'DB_PASSWORD'
    args:
      - 'build'
      - '--build-arg'
      - 'DB_PASSWORD=$$DB_PASSWORD'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_BACKEND_REGISTRY}/backend:${SHORT_SHA}'
      - '.'

availableSecrets:
  secretManager:
    - versionName: projects/$PROJECT_ID/secrets/db-password/versions/latest
      env: DB_PASSWORD
```

### Trigger Configuration Details

**Branch Filter**: `^main$` (or configured branch)

**Included Files**:
```
**/creative-studio/backend/**
```

Only triggers when files matching this pattern change.

**Excluded Files**:
```
**/*.md
**/.gitignore
```

Optional: Exclude files that shouldn't trigger builds.

### Backend Deployment Steps

1. **Checkout**: Repository cloned at commit
2. **Docker Build**: Image built with:
   - Application code
   - Dependencies (requirements.txt)
   - Database password injected
3. **Push**: Image pushed to Artifact Registry with:
   - Commit SHA tag: `backend:abc123`
   - Latest tag: `backend:latest`
4. **Cloud Run Deploy**: Service updated with:
   - New image
   - Environment variables
   - Database connection string
   - Service account
5. **Verify**: Service started and healthy

## Frontend Cloud Build Trigger

### Trigger Configuration

**File**: `examples/creative-studio/frontend/cloudbuild-deploy.yaml`

```yaml
steps:
  # Step 1: Install dependencies
  - name: 'node:18'
    entrypoint: npm
    args:
      - 'install'

  # Step 2: Build application with Firebase config injected
  - name: 'node:18'
    entrypoint: npm
    secretEnv:
      - 'FIREBASE_API_KEY'
      - 'FIREBASE_AUTH_DOMAIN'
      - 'FIREBASE_PROJECT_ID'
      - 'FIREBASE_STORAGE_BUCKET'
      - 'FIREBASE_MESSAGING_SENDER_ID'
      - 'FIREBASE_APP_ID'
      - 'FIREBASE_MEASUREMENT_ID'
      - 'BACKEND_URL'
    args:
      - 'run'
      - 'build'
    env:
      - 'REACT_APP_FIREBASE_API_KEY=$$FIREBASE_API_KEY'
      - 'REACT_APP_FIREBASE_AUTH_DOMAIN=$$FIREBASE_AUTH_DOMAIN'
      - 'REACT_APP_FIREBASE_PROJECT_ID=$$FIREBASE_PROJECT_ID'
      - 'REACT_APP_FIREBASE_STORAGE_BUCKET=$$FIREBASE_STORAGE_BUCKET'
      - 'REACT_APP_FIREBASE_MESSAGING_SENDER_ID=$$FIREBASE_MESSAGING_SENDER_ID'
      - 'REACT_APP_FIREBASE_APP_ID=$$FIREBASE_APP_ID'
      - 'REACT_APP_FIREBASE_MEASUREMENT_ID=$$FIREBASE_MEASUREMENT_ID'
      - 'REACT_APP_BACKEND_URL=$$BACKEND_URL'

  # Step 3: Build Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_FRONTEND_REGISTRY}/frontend:${SHORT_SHA}'
      - '-f'
      - 'examples/creative-studio/frontend/Dockerfile'
      - '.'

  # Step 4: Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_FRONTEND_REGISTRY}/frontend:${SHORT_SHA}'

  # Step 5: Deploy to Cloud Run
  - name: 'gcr.io/cloud-builders/gke-deploy'
    args:
      - 'run'
      - '-f=examples/creative-studio/frontend/k8s/'
```

### Firebase Configuration Injection

This is the **critical** difference for frontend:

```yaml
secretEnv:
  - 'FIREBASE_API_KEY'
  - 'FIREBASE_AUTH_DOMAIN'
  - 'FIREBASE_PROJECT_ID'
  - 'FIREBASE_STORAGE_BUCKET'
  - 'FIREBASE_MESSAGING_SENDER_ID'
  - 'FIREBASE_APP_ID'
  - 'FIREBASE_MEASUREMENT_ID'

availableSecrets:
  secretManager:
    - versionName: projects/$PROJECT_ID/secrets/firebase-api-key/versions/latest
      env: FIREBASE_API_KEY
    - versionName: projects/$PROJECT_ID/secrets/firebase-auth-domain/versions/latest
      env: FIREBASE_AUTH_DOMAIN
    # ... etc
```

These are injected as environment variables during build:
```typescript
// src/config/firebase.ts
export const firebaseConfig = {
  apiKey: process.env.REACT_APP_FIREBASE_API_KEY,
  authDomain: process.env.REACT_APP_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.REACT_APP_FIREBASE_PROJECT_ID,
  storageBucket: process.env.REACT_APP_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.REACT_APP_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.REACT_APP_FIREBASE_APP_ID,
  measurementId: process.env.REACT_APP_FIREBASE_MEASUREMENT_ID,
};

export const backendUrl = process.env.REACT_APP_BACKEND_URL;
```

### Automatic Substitutions

The platform module injects:

```hcl
build_substitutions = merge(
  var.fe_build_substitutions,
  {
    _BACKEND_URL         = local.backend_url
    _FE_SERVICE_NAME     = var.frontend_service_name
    _BACKEND_SERVICE_ID  = var.backend_service_name
    _FIREBASE_PROJECT_ID = var.gcp_project_id
    _FIREBASE_APP_ID     = var.firebase_web_app_id != null ? 
                           var.firebase_web_app_id : 
                           module.firebase.firebase_web_app_id
  }
)
```

### Frontend Deployment Steps

1. **Checkout**: Repository cloned
2. **Dependencies**: `npm install` (caches dependencies)
3. **Build**: `npm run build`
   - Firebase config injected as env vars
   - Backend URL injected
   - Output: `dist/` folder
4. **Docker Build**: Creates Nginx + app image
5. **Push**: Image to Artifact Registry
6. **Deploy**: Service updated

## Bootstrap Cloud Build Trigger

### Trigger Configuration

**File**: `examples/creative-studio/backend/cloudbuild-bootstrap.yaml`

```yaml
steps:
  # Step 1: Build bootstrap Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_BOOTSTRAP_REGISTRY}/bootstrap:${SHORT_SHA}'
      - '-f'
      - 'examples/creative-studio/backend/Dockerfile.bootstrap'
      - '.'

  # Step 2: Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_BOOTSTRAP_REGISTRY}/bootstrap:${SHORT_SHA}'

  # Step 3: Create/Update Cloud Run Job
  - name: 'gcr.io/cloud-builders/gke-deploy'
    secretEnv:
      - 'DB_PASSWORD'
    args:
      - 'run'
      - '-f='
      - '-l=app=bootstrap'
    env:
      - 'CLOUDSDK_COMPUTE_REGION=${_REGION}'

  # Step 4: Execute the job
  - name: 'gcr.io/cloud-builders/gcloud'
    secretEnv:
      - 'DB_PASSWORD'
    args:
      - 'run'
      - 'jobs'
      - 'execute'
      - '${_BOOTSTRAP_JOB_NAME}'
      - '--region=${_REGION}'
      - '--wait'
```

### Trigger Conditions

**Branch**: `^main$`

**Included Files**:
```
**/creative-studio/backend/bootstrap/**
**/creative-studio/backend/Dockerfile.bootstrap
**/creative-studio/backend/cloudbuild-bootstrap.yaml
```

Only triggers on bootstrap code changes.

### Bootstrap Execution Steps

1. **Checkout**: Repository cloned
2. **Docker Build**: Builds bootstrap image
   - Python with database tools
   - Migration scripts
   - Seed data scripts
3. **Push**: Image to Artifact Registry
4. **Job Creation**: Cloud Run Job updated with:
   - New image
   - Database connection details
   - Secrets mounted
5. **Job Execution**: Job runs with:
   - Database migrations
   - Seed data loading
   - Initialization scripts

## Cross-Module Trigger Dependencies

### Frontend Trigger Access to Backend Info

Frontend Cloud Build trigger needs backend details:

```hcl
# Platform module grants access
resource "google_cloud_run_v2_service_iam_member" "fe_trigger_can_view_backend" {
  name     = module.backend_service.service_name
  location = module.backend_service.location
  role     = "roles/run.viewer"
  member   = module.frontend_service.trigger_sa_member
}
```

This allows:
- Reading backend service details
- Getting backend URL
- Checking backend status

### Bootstrap Trigger Access to Database

Bootstrap trigger uses bootstrap service account:

```hcl
# Permissions granted to bootstrap SA
roles/cloudsql.client    # Connect to database
roles/secretmanager.secretAccessor  # Read secrets
```

## Monitoring & Debugging Cloud Build

### View Active Builds

```bash
# List recent builds
gcloud builds list --limit 10

# Get specific build details
gcloud builds describe {BUILD_ID}

# Get build logs
gcloud builds log {BUILD_ID} --limit 100
```

### Real-time Monitoring

```bash
# Stream logs as build executes
gcloud builds log {BUILD_ID} --stream
```

### Cloud Build Dashboard

Cloud Console > Cloud Build > Dashboard shows:
- Active builds
- Build history
- Success/failure rates
- Build duration trends
- Service account activity

## Troubleshooting Cloud Build Triggers

### Trigger Not Activating

1. **Verify GitHub connection**
   ```bash
   gcloud builds connections list
   ```

2. **Check branch filter**
   ```bash
   gcloud builds triggers describe {TRIGGER_ID}
   # Verify "branch" matches your push
   ```

3. **Check included files**
   - Verify files match the glob pattern
   - Test pattern: `**/creative-studio/backend/**`

### Build Fails

1. **Check logs**
   ```bash
   gcloud builds log {BUILD_ID} --limit 200
   ```

2. **Common issues**:
   - Docker build syntax error
   - Missing dependencies
   - Credential/secret issues
   - Network connectivity

3. **Verify secrets**
   ```bash
   gcloud secrets list
   gcloud secrets versions access latest --secret=db-password
   ```

### Service Account Permissions

```bash
# Check SA permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:cs-*-trigger-*"
```

## Cost Optimization

### Build Frequency
- Minimize trigger frequency
- Exclude unnecessary files
- Use branch filters

### Build Duration
- Cache Docker layers
- Cache npm/pip dependencies
- Parallelize steps where possible

### Storage
- Clean old images: `gcloud container images delete`
- Set retention policies
- Archive logs to Cloud Storage

## Related Documentation

- [Backend Service Module](./modules/services/backend/README.md)
- [Frontend Service Module](./modules/services/frontend/README.md)
- [Bootstrap Module](./modules/bootstrap/README.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [GCP Cloud Build Docs](https://cloud.google.com/build/docs)
