# Frontend Service Module

## Overview

This module deploys and manages the Creative Studio frontend service on Google Cloud Run. It includes:
- Cloud Run service configuration
- Autonomous secret management
- Cloud Build trigger for CI/CD
- Firebase configuration injection
- Service account and IAM bindings
- Static file serving and caching

## Architecture

```
┌─────────────────────────────────────────────────────┐
│       Frontend Cloud Run Service                    │
├─────────────────────────────────────────────────────┤
│  • React/Vue.js web application                     │
│  • Firebase SDK configuration                       │
│  • Static assets (HTML, CSS, JS)                    │
│  • API calls to backend service                     │
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
      │                 │
      ▼                 ▼
┌────────────────┐  ┌────────────────┐
│  Firebase SDK  │  │  Backend API   │
│ Configuration  │  │  Reference     │
└────────────────┘  └────────────────┘
```

## Module Variables

### Required Variables

```hcl
gcp_project_id              # GCP project ID
gcp_region                  # GCP region for resources
firebase_project_id         # Firebase project ID
environment                 # Environment name (dev, prod, etc.)
service_name               # Firebase Hosting site ID
resource_prefix            # Resource naming prefix (e.g., "cs-fe")

# GitHub Configuration
github_branch_name         # Branch for Cloud Build trigger
cloudbuild_yaml_path       # Path to cloudbuild-deploy.yaml
included_files_glob        # File patterns that trigger the build

# Cloud Build Configuration
source_repository_id       # Cloud Build V2 repository ID
build_substitutions        # Build substitution variables (map)
frontend_secrets           # Frontend secret names (list)
```

### Optional Variables

```hcl
enable_cloud_build_trigger # Whether to create the Cloud Build trigger
custom_audiences           # OAuth custom audiences (list)
resource_timeout_seconds   # Request timeout (default: 3600)
vpc_connector_id          # VPC connector ID (if needed)
invoker_identities        # Service accounts/users who can invoke

# Resource Configuration
cpu                       # CPU allocation (default: "1000m")
memory                    # Memory allocation (default: "512Mi")
scaling_min_instances     # Minimum replicas (default: 1)
```

## Module Outputs

```hcl
service_name              # Cloud Run service name
url                       # HTTPS URL of the frontend
service_iam_done         # Signal for IAM binding dependencies
trigger_sa_member        # Cloud Build trigger SA (for cross-module access)
```

## Cloud Build Trigger Configuration

The frontend module automatically creates a Cloud Build trigger that:

### Trigger Mechanism
- **Source**: GitHub repository
- **Branch**: Specified branch (usually `main` or `develop`)
- **Included Files**: Only triggers on changes to `**/creative-studio/frontend/**`
- **Automatic Firebase Configuration Injection**

### Build Process

The trigger executes `examples/creative-studio/frontend/cloudbuild-deploy.yaml` which:

1. **Checkout**: Clones repository at specified branch
2. **Firebase Config Injection**: Injects Firebase SDK configuration
   - FIREBASE_API_KEY
   - FIREBASE_AUTH_DOMAIN
   - FIREBASE_PROJECT_ID
   - FIREBASE_STORAGE_BUCKET
   - FIREBASE_MESSAGING_SENDER_ID
   - FIREBASE_APP_ID
   - FIREBASE_MEASUREMENT_ID
3. **Build**: Builds static web app with:
   - Environment variables
   - Firebase configuration
   - Backend API URL
4. **Push**: Pushes Docker image to Artifact Registry
5. **Deploy**: Deploys to Cloud Run
6. **Health Check**: Verifies service is running

### Firebase Configuration Injection

This is a **critical** feature that automatically populates Firebase configuration:

```yaml
steps:
  - name: 'gcr.io/cloud-builders/gke-deploy'
    args:
      - run
      - -f=.
      - -l=app=frontend
      - -o=/workspace/output
    env:
      - 'CLOUDSDK_COMPUTE_REGION=$_REGION'
      - 'CLOUDSDK_CONTAINER_CLUSTER=$_CLUSTER_NAME'
      # Firebase configuration injected as substitutions
      - 'FIREBASE_API_KEY=$_FIREBASE_API_KEY'
      - 'FIREBASE_AUTH_DOMAIN=$_FIREBASE_AUTH_DOMAIN'
      - 'FIREBASE_PROJECT_ID=$_FIREBASE_PROJECT_ID'
      - 'FIREBASE_STORAGE_BUCKET=$_FIREBASE_STORAGE_BUCKET'
      - 'FIREBASE_MESSAGING_SENDER_ID=$_FIREBASE_MESSAGING_SENDER_ID'
      - 'FIREBASE_APP_ID=$_FIREBASE_APP_ID'
      - 'FIREBASE_MEASUREMENT_ID=$_FIREBASE_MEASUREMENT_ID'
      - 'BACKEND_URL=$_BACKEND_URL'
```

### Build Substitutions

The Cloud Build trigger automatically injects these substitutions:

```
_REGION                    # GCP region
_FE_SERVICE_NAME          # Frontend service name
_BACKEND_SERVICE_ID       # Backend service ID
_FIREBASE_PROJECT_ID      # Firebase project ID
_FIREBASE_API_KEY         # From Firebase web app config
_FIREBASE_AUTH_DOMAIN     # From Firebase web app config
_FIREBASE_PROJECT_ID      # From Firebase web app config
_FIREBASE_STORAGE_BUCKET  # From Firebase web app config
_FIREBASE_MESSAGING_SENDER_ID  # From Firebase web app config
_FIREBASE_APP_ID          # From Firebase web app config (NOT a secret!)
_FIREBASE_MEASUREMENT_ID  # From Firebase web app config
_BACKEND_URL              # Backend service URL
```

### Why FIREBASE_APP_ID is Public

The `FIREBASE_APP_ID` is **NOT** a secret - it's public configuration:
- It's included in frontend source code in git
- It's embedded in JavaScript bundles
- It's visible in browser network requests
- It's intentionally public for client-side Firebase SDK initialization

## Firebase Configuration Auto-Discovery

This module automatically discovers Firebase configuration from the Firebase module:

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

frontend_secrets = concat(
  module.firebase.frontend_secrets_auto,
  var.frontend_secrets_additional
)
```

This approach:
- Eliminates manual Firebase configuration entry
- Works with both auto-created and manually created Firebase web apps
- Updates automatically if Firebase configuration changes

## Environment Variables & Secrets

### Build-Time Variables (Substitutions)

These are injected during Cloud Build and embedded in the static app:

```
FIREBASE_API_KEY           # Firebase API key
FIREBASE_AUTH_DOMAIN       # Firebase auth domain
FIREBASE_PROJECT_ID        # Firebase project ID
FIREBASE_STORAGE_BUCKET    # Firebase storage bucket
FIREBASE_MESSAGING_SENDER_ID  # Firebase messaging ID
FIREBASE_APP_ID            # Firebase app ID (public)
FIREBASE_MEASUREMENT_ID    # Firebase analytics ID
BACKEND_URL                # Backend API URL
```

Example in `src/config/firebase.ts`:
```typescript
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

### Runtime Secrets (Cloud Run)

Runtime secrets from Google Secret Manager are available but typically not needed for frontend (they're public anyway):

```hcl
frontend_secrets = [
  "firebase-api-key",
  "firebase-auth-domain",
  # ... other Firebase config values
]
```

## Service Account & IAM

### Service Account
- Created automatically: `cs-frontend-{environment}`
- Used for Cloud Run service execution
- Limited permissions (read-only)

### Cloud Build Trigger Service Account
- Created automatically: `cs-fe-trigger-{environment}`
- Used for Cloud Build trigger execution
- Permissions to pull images and deploy to Cloud Run

### IAM Bindings
1. **Cloud Run Service Agent**: Minimal permissions for Cloud Run
2. **Secret Accessor**: Read-only access to frontend secrets
3. **Artifact Registry Reader**: Pull images

## Secret Management

**Application secrets are now managed centrally by the Platform module's `core/secrets` module.** This module creates its own Firebase SDK configuration secrets, but overall secret access is coordinated by the platform.

### How It Works

1. **Unified OAuth Secret**: Platform module creates and manages `OAUTH_CLIENT_ID` secret (shared with backend)
2. **Firebase SDK Config**: Frontend Cloud Build receives Firebase config via substitutions (not stored in Secret Manager)
3. **Permission Granting**: Platform module automatically grants this frontend service account access to `OAUTH_CLIENT_ID`

### Frontend Service Account

This module exports the frontend service account member reference that the platform module uses:

```hcl
# Frontend module outputs
output "trigger_sa_member" {
  description = "Frontend Cloud Build trigger service account member string (for IAM)"
}
```

This is used by the platform module to grant access to unified secrets:

```hcl
# In platform module
module "app_secrets" {
  secrets_config = {
    "OAUTH_CLIENT_ID" = {
      accessors = [
        module.frontend_service.trigger_sa_member,  # For Cloud Build injection
      ]
    }
  }
}
```

### Firebase Configuration

Firebase SDK configuration (API key, auth domain, etc.) is:
- **Auto-discovered** from Firebase module outputs
- **Injected** as Cloud Build substitutions (not stored in Secret Manager)
- **Embedded** in the frontend application at build time
- **Never passed** as runtime secrets (it's public configuration)

## Deployment Workflow

### 1. Push Code to Repository
```bash
git push origin main
# Changes in frontend/** detected
```

### 2. Cloud Build Trigger Activates
```
Cloud Build Start
├─ Source: GitHub repo @ main branch
├─ Checkout: specific commit
├─ Inject: Firebase configuration (from substitutions)
└─ Execute: cloudbuild-deploy.yaml
```

### 3. Build & Bundle
```
npm install (or yarn/pnpm)
npm run build
# Outputs: dist/
# Size: typically 100-500KB (gzipped)
```

### 4. Docker Build & Push
```dockerfile
FROM node:18-slim as builder
COPY . /app/
RUN npm install && npm run build

FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 8080
```

Image pushed to:
```
{region}-docker.pkg.dev/{project}/cloud-run-service/frontend:{commit-sha}
```

### 5. Cloud Run Deployment
```
gcloud run deploy {service-name}
├─ Image: artifact-registry-image
├─ Region: specified region
├─ Memory: 512Mi typical
├─ CPU: 1000m typical
├─ Port: 8080
├─ Env vars: Firebase config injected
└─ Timeout: 3600 seconds (for long file operations)
```

### 6. Service Ready
- Serves static assets
- Routes API calls to backend
- Handles Firebase authentication

## Backend Communication

### API Calls
Frontend makes API calls to backend:

```typescript
const response = await fetch(`${backendUrl}/api/endpoint`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${authToken}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify(data)
});
```

### Authentication Flow
1. User logs in via Firebase UI
2. Firebase generates ID token
3. Frontend includes token in API calls
4. Backend validates token with Firebase Admin SDK
5. Backend processes request

### Backend Service Reference
Frontend has read-only access to backend service details:
```hcl
google_cloud_run_v2_service_iam_member "fe_trigger_can_view_backend"
# Frontend's Cloud Build trigger gets run.viewer on backend
```

## CORS Configuration

Frontend and backend run on different origins, so CORS is configured:

**Backend (cloudbuild.yaml)**:
```yaml
env:
  - name: CORS_ORIGINS
    value: '["https://frontend-url"]'
```

**Backend Service**:
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## Caching Strategy

### Static Assets (HTML/CSS/JS)
Served with cache headers:
```
Cache-Control: public, max-age=3600, immutable
```

### API Responses
Configured by backend:
```
Cache-Control: no-cache, no-store, must-revalidate
```

## Monitoring & Logs

### Cloud Run Logs
```bash
gcloud run services logs read {service-name} --region {region}
```

### Cloud Build Logs
```bash
gcloud builds log {build-id}
```

### Metrics
- Request latency
- Error rates (4xx, 5xx)
- Traffic patterns
- Static asset delivery

Access via: Cloud Console > Cloud Run > Service > Metrics

## Scaling

### Frontend Scaling
Frontend is typically less demanding than backend:

```hcl
scaling_min_instances = 1  # Min replicas
cpu = "1000m"             # 1 CPU
memory = "512Mi"          # 512 MB
```

### Load Characteristics
- **Peak**: Login time, high traffic
- **Off-peak**: Low CPU usage
- **Auto-scaling**: Based on request rate and CPU

## Invoker Access Control

Control who can invoke the frontend:

```hcl
invoker_identities = [
  "allUsers"  # Public access (typical for web app)
]
```

Or restrict to specific identities:
```hcl
invoker_identities = [
  "group:company-employees@company.com"
]
```

## Troubleshooting

### Cloud Build Fails

1. **Check Cloud Build logs**
   ```bash
   gcloud builds log {build-id} --limit 100
   ```
   Common issues:
   - npm/yarn install fails (missing packages)
   - Build fails (TypeScript errors, missing imports)
   - Docker build fails (invalid Dockerfile)

2. **Verify Firebase substitutions**
   ```bash
   gcloud builds describe {build-id} \
     --format="value(substitutions)"
   ```
   Should show all _FIREBASE_* values

3. **Check secret access**
   ```bash
   gcloud secrets list
   gcloud secrets versions access latest --secret=firebase-api-key
   ```

### Service Won't Load

1. **Check Cloud Run logs**
   ```bash
   gcloud run services logs read {service-name} --region {region}
   ```
   Look for:
   - Nginx startup errors
   - Port binding issues
   - Memory/CPU limits hit

2. **Verify static files**
   - Check if `dist/` folder is properly created
   - Verify index.html exists
   - Check file permissions

3. **Test directly**
   ```bash
   curl https://{service-url}/
   curl https://{service-url}/index.html
   ```

### Firebase Configuration Not Loading

1. **Check browser console for errors**
   - Missing Firebase config
   - Invalid app ID
   - Network errors

2. **Verify substitutions in Cloud Build**
   - FIREBASE_API_KEY injected correctly
   - No null or empty values
   - All required Firebase values present

3. **Test Firebase SDK initialization**
   ```typescript
   console.log('Firebase Config:', firebaseConfig);
   firebase.initializeApp(firebaseConfig);
   ```

### Backend Communication Issues

1. **Check CORS errors in browser**
   - Verify backend CORS_ORIGINS includes frontend URL
   - Check preflight requests

2. **Verify backend URL**
   ```bash
   echo "Backend URL: $(terraform output backend_url)"
   curl $(terraform output backend_url)/health
   ```

3. **Check network policies**
   - Verify Cloud Run service can reach backend
   - Check VPC routing if VPC enabled

## Cost Optimization

### Memory & CPU
- Frontend: 512Mi / 250m (lower than backend)
- Static assets: minimal computation
- Primary cost: storage + bandwidth

### Scaling
- Min instances: 1 (avoid cold starts)
- Scale down aggressively during off-peak
- Use Cloud CDN for static assets (future)

### Cloud Build
- Triggered only on code changes
- Cleanup builds older than 30 days
- Cache Docker layers between builds

## Related Documentation

- [Cloud Build Trigger Details](./BUILD_TRIGGERS.md)
- [Frontend Architecture](../../../../frontend/README.md)
- [Firebase Configuration](../../core/firebase/README.md)
- [Platform Module](../platform/README.md)
- [Backend Service](./backend/README.md)
