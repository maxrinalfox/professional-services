# Deployment & Infrastructure

Google Cloud Platform setup, Terraform configuration, and deployment guides.

## 📖 Guides in This Section

### [01_GCP_PROJECT_SETUP.md](01_GCP_PROJECT_SETUP.md)
**Google Cloud Platform services and provisioning**

- GCP project creation and configuration
- Service accounts and IAM roles
- Required APIs and enablement
- Cloud Run service setup
- Firebase project configuration
- Firestore database creation
- Cloud Storage bucket setup
- Cloud SQL instance provisioning
- Secret Manager configuration
- Artifact Registry setup
- Cloud Build CI/CD pipeline
- Monitoring and logging setup

**For:** DevOps engineers, infrastructure architects, system administrators

---

### [02_TERRAFORM_INFRASTRUCTURE_GUIDE.md](02_TERRAFORM_INFRASTRUCTURE_GUIDE.md)
**Terraform Variable Configuration, Security & Edge Cases (v1.1)**

- Variable naming convention and patterns
- Destruction control configuration (`allow_destroy`)
- Protected vs customizable variables
- **Cloud Run Access Control (roles/run.invoker):**
  - Configuring `backend_invoker_identities` for API access
  - Public vs restricted access strategies
  - User, group, and service account access control
  - Two-layer security with Identity Platform
  - Verification and monitoring commands
- Infrastructure edge cases (RESOLVED in v1.1):
  - Destruction control consolidation
  - Variable naming consistency
  - Firestore database name visibility
  - Bootstrap environment variable protection
- Configuration examples (development & production)
- Verification checklist
- Troubleshooting guide

**For:** DevOps engineers, infrastructure automation, security teams, anyone configuring environments

**⭐ IMPORTANT:** Read this BEFORE configuring your environment to avoid `allow_destroy`, variable naming, or access control mistakes.

---

### [03_CLOUD_SQL_DATABASE.md](03_CLOUD_SQL_DATABASE.md)
**Cloud SQL PostgreSQL setup and management**

- Cloud SQL instance configuration
- PostgreSQL 18 setup
- Database and user creation
- Connection configuration (Python Connector, Auth Proxy)
- Alembic migrations
- Backup and recovery procedures
- Performance tuning
- Monitoring and maintenance
- Security best practices

**For:** Backend developers, DevOps engineers, DBAs

---

### [04_CLOUD_RUN_BACKEND.md](04_CLOUD_RUN_BACKEND.md)
**Cloud Run backend deployment**

- Cloud Run service configuration
- Environment variables and secrets
- Docker image building and pushing
- Deployment procedures
- Traffic splitting and gradual rollouts
- Scaling configuration
- Monitoring and logging
- Cold start optimization
- Service accounts and permissions

**For:** DevOps engineers, backend developers

---

### [05_FIREBASE_FRONTEND_HOSTING.md](05_FIREBASE_FRONTEND_HOSTING.md)
**Firebase Hosting frontend deployment**

- Firebase project setup
- Build configuration (firebase.json)
- Deployment process
- Environment-specific deployments
- Custom domain configuration
- SSL/TLS certificates
- Redirects and rewrites
- Performance optimization
- Analytics and monitoring

**For:** DevOps engineers, frontend developers

---

### [06_FIREBASE_HOSTING_PROXY_CONFIGURATION.md](06_FIREBASE_HOSTING_PROXY_CONFIGURATION.md)
**Firebase Hosting as API proxy (CORS resolution)**

- Firebase Hosting proxy architecture
- Routing backend requests through Firebase
- Eliminating cross-origin request issues
- Configuration with firebase.json rewrites
- Cloud Build variable injection
- Request flow diagrams
- Best practices for proxy vs direct calls

**For:** Frontend developers, DevOps engineers, security architects

**When to Use:** When frontend and backend are deployed on different domains

---

### [07_CLOUD_BUILD_TRIGGERS.md](07_CLOUD_BUILD_TRIGGERS.md)
**Cloud Build CI/CD pipeline configuration**

- Cloud Build trigger setup and prerequisites
- Backend trigger (code → Docker → Cloud Run)
- Frontend trigger (code → build → Firebase Hosting)
- Bootstrap trigger (database initialization)
- Environment variables and secrets configuration
- Cloud Build GitHub connection setup
- Troubleshooting and verification

**For:** DevOps engineers, backend/frontend developers

**Important:** Requires manual Cloud Build GitHub connection setup in GCP Console first

---

## 🏗️ Infrastructure Architecture

```
┌──────────────────────────────────────────────────┐
│         Google Cloud Platform (GCP)              │
├──────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │        Cloud Run                         │  │
│  │  Creative Studio Backend (FastAPI)       │  │
│  │  - Auto-scaling                          │  │
│  │  - Load balancing                        │  │
│  │  - Managed service                       │  │
│  └──────────┬───────────────────────────────┘  │
│             │                                   │
│    ┌────────┼──────────┬──────────┐            │
│    │        │          │          │            │
│    ▼        ▼          ▼          ▼            │
│  ┌────┐  ┌────┐  ┌──────────┐  ┌──────┐      │
│  │FS* │  │GCS │  │Cloud SQL │  │Secrets   │  │
│  │    │  │    │  │PostgreSQL│  │Manager   │  │
│  └────┘  └────┘  └──────────┘  └──────┘      │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │    Firebase Hosting                      │  │
│  │  Creative Studio Frontend (Angular)      │  │
│  │  - Global CDN                            │  │
│  │  - Automatic SSL                         │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │      Cloud Build                         │  │
│  │  Automated CI/CD Pipeline                │  │
│  │  - GitHub integration                    │  │
│  │  - Automated testing                     │  │
│  │  - Docker builds                         │  │
│  │  - Automated deployment                  │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │      Monitoring & Logging                │  │
│  │  - Cloud Logging                         │  │
│  │  - Cloud Monitoring                      │  │
│  │  - Traces and profiling                  │  │
│  └──────────────────────────────────────────┘  │
│                                                │
└──────────────────────────────────────────────────┘
     * Firestore
```

---

## 🚀 Quick Deployment

### 1. Prepare Environment
```bash
# Set project ID
export PROJECT_ID=your-gcp-project-id
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable \
  firestore.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  sqladmin.googleapis.com \
  compute.googleapis.com
```

### 2. Deploy with Terraform
```bash
cd infra/environments/dev-infra-example

# Initialize Terraform
terraform init \
  -backend-config="bucket=${PROJECT_ID}-terraform-state" \
  -backend-config="prefix=creative-studio/dev"

# Plan deployment
terraform plan -out=tfplan

# Apply configuration
terraform apply tfplan
```

### 3. Deploy Backend
```bash
# Build and push Docker image
gcloud builds submit backend \
  --config backend/cloudbuild.yaml

# Or manual deployment
gcloud run deploy creative-studio-backend \
  --image us-central1-docker.pkg.dev/${PROJECT_ID}/cs-repo/backend:latest \
  --region us-central1 \
  --service-account cs-prod-run@${PROJECT_ID}.iam.gserviceaccount.com
```

### 4. Deploy Frontend
```bash
# Build and deploy
cd frontend
npm run build-prd
firebase deploy --project=$PROJECT_ID
```

---

## 📊 Service Accounts

| Account | Purpose | Key Permissions |
|---------|---------|-----------------|
| `cs-prod-run` | Cloud Run runtime | Vertex AI, Storage, Firestore, Secrets |
| `cs-prod-trig` | Cloud Build CI/CD | Artifact Registry, Cloud Run, IAM |
| `cs-prod-read` | Signed URLs | Cloud Storage object viewer |

See [01_GCP_PROJECT_SETUP.md](01_GCP_PROJECT_SETUP.md) for detailed IAM roles.

---

## 🔐 Security

- All API calls use service account credentials
- Secrets stored in Secret Manager (never in code)
- Service accounts follow least privilege principle
- Network traffic encrypted with TLS/SSL
- Firestore security rules enforce access control
- Cloud Run services are HTTPS-only
- Database passwords rotated regularly

---

## 📈 Scaling

- **Cloud Run:** Automatically scales from 0 to 100+ instances
- **Cloud SQL:** Vertical scaling, read replicas for horizontal
- **Firestore:** Automatically scales transparently
- **Cloud Storage:** Unlimited capacity, built-in redundancy

---

## 💰 Cost Management

- Use Cloud Run's pay-per-use model
- Enable Cloud SQL automatic backups (low cost)
- Set Firestore deletion policies for old data
- Use Cloud Storage lifecycle policies for media
- Set up budget alerts in GCP Console

---

## 🚀 Next Steps

1. **Setup GCP:** Read [01_GCP_PROJECT_SETUP.md](01_GCP_PROJECT_SETUP.md)
2. **Plan infrastructure:** Read [02_TERRAFORM_INFRASTRUCTURE.md](02_TERRAFORM_INFRASTRUCTURE.md)
3. **Deploy backend:** Read [04_CLOUD_RUN_BACKEND.md](04_CLOUD_RUN_BACKEND.md)
4. **Deploy database:** Read [03_CLOUD_SQL_DATABASE.md](03_CLOUD_SQL_DATABASE.md)
5. **Deploy frontend:** Read [05_FIREBASE_FRONTEND_HOSTING.md](05_FIREBASE_FRONTEND_HOSTING.md)
6. **Monitor:** [07-operations/](../07-operations/)

---

## 📚 Learn More

- **Environment config:** [01-getting-started/02_ENVIRONMENTS_SETUP.md](../01-getting-started/02_ENVIRONMENTS_SETUP.md)
- **Architecture:** [02-architecture/01_SYSTEM_DESIGN.md](../02-architecture/01_SYSTEM_DESIGN.md)
- **Database:** [03_CLOUD_SQL_DATABASE.md](03_CLOUD_SQL_DATABASE.md)
- **Operations:** [07-operations/01_LOGGING_AND_DEBUGGING.md](../07-operations/01_LOGGING_AND_DEBUGGING.md)
