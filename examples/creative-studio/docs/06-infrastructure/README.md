# Deployment & Infrastructure

Google Cloud Platform setup, Terraform configuration, and deployment guides.

## 📖 Guides in This Section

### [GCP_SETUP.md](GCP_SETUP.md)
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

### [TERRAFORM.md](TERRAFORM.md) - *To be created*
**Infrastructure as Code with Terraform**

- Terraform project structure
- Module organization (platform, cloud-run-service, firebase, etc.)
- Variable configuration and tfvars
- State management and backend
- Deploying with Terraform
- Debugging Terraform issues
- Production best practices

**For:** DevOps engineers, infrastructure automation

---

### [CLOUD_SQL.md](CLOUD_SQL.md) - *To be created*
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

### [CLOUD_RUN.md](CLOUD_RUN.md) - *To be created*
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

### [FIREBASE_HOSTING.md](FIREBASE_HOSTING.md) - *To be created*
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

See [GCP_SETUP.md](GCP_SETUP.md) for detailed IAM roles.

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

1. **Setup GCP:** Read [GCP_SETUP.md](GCP_SETUP.md)
2. **Plan infrastructure:** Create Terraform files (TERRAFORM.md)
3. **Deploy backend:** See CLOUD_RUN.md (to create)
4. **Deploy database:** See CLOUD_SQL.md (to create)
5. **Deploy frontend:** See FIREBASE_HOSTING.md (to create)
6. **Monitor:** [07-operations/](../07-operations/)

---

## 📚 Learn More

- **Environment config:** [01-getting-started/ENVIRONMENTS.md](../01-getting-started/ENVIRONMENTS.md)
- **Architecture:** [02-architecture/SYSTEM_DESIGN.md](../02-architecture/SYSTEM_DESIGN.md)
- **Database:** [03-backend/](../03-backend/) (create CLOUD_SQL.md)
- **Operations:** [07-operations/LOGGING.md](../07-operations/LOGGING.md)
