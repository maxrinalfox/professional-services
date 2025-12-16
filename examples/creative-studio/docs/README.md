# Creative Studio Documentation

Complete documentation for the **Creative Studio** - A comprehensive Generative AI platform built on Google Cloud Platform with Vertex AI integration.

> 🚀 This documentation covers the current state of the application including Cloud SQL PostgreSQL, SQLAlchemy ORM, and all GCP resources.

## 📚 Quick Navigation

### 🎯 Getting Started (Start Here!)
- **[01-getting-started/](01-getting-started/)** - Quick setup and configuration
  - `01_QUICK_START.md` - Local development setup
  - `02_ENVIRONMENTS_SETUP.md` - Environment variables and configuration
  - `03_DOCKER_LOCAL_SETUP.md` - Docker Compose local development

### 🏗️ Architecture & Design
- **[02-architecture/](02-architecture/)** - System design and architecture
  - `01_SYSTEM_DESIGN.md` - Overall system architecture
  - `02_DATA_FLOW_PATTERNS.md` - Request flows and data interactions
  - `03_SYSTEM_COMPONENTS.md` - Visual component relationships

### 🔧 Backend Development
- **[03-backend/](03-backend/)** - Backend implementation guides
  - `01_SERVICES_ARCHITECTURE.md` - FastAPI services and SQLAlchemy ORM
  - `02_API_ENDPOINTS_REFERENCE.md` - Complete API reference
  - `03_AUTHENTICATION_FLOW.md` - Auth implementation and JWT

### 🎨 Frontend Development
- **[04-frontend/](04-frontend/)** - Frontend implementation
  - `01_COMPONENTS_ARCHITECTURE.md` - Angular component architecture
  - `02_UI_PATTERNS_GUIDE.md` - UI/UX patterns and component usage

### 🔐 Security
- **[05-security/](05-security/)** - Security and access control
  - `03_AUTHENTICATION_FLOW.md` - Firebase/OAuth implementation (in `03-backend/`)
  - `03_FIRESTORE_SECURITY_RULES.md` - Firestore security rules
  - `01_ACCESS_CONTROL_AND_RBAC.md` - RBAC and workspace isolation
  - `02_USER_ROLES_AND_PERMISSIONS.md` - Complete role guide and permissions

### ☁️ Infrastructure & Deployment
- **[06-infrastructure/](06-infrastructure/)** - GCP setup and deployment
  - `01_GCP_PROJECT_SETUP.md` - GCP services and provisioning
  - `02_TERRAFORM_INFRASTRUCTURE.md` - Infrastructure as Code
  - `04_CLOUD_RUN_BACKEND.md` - Backend deployment
  - `03_CLOUD_SQL_DATABASE.md` - PostgreSQL database setup
  - `05_FIREBASE_FRONTEND_HOSTING.md` - Frontend hosting

### 📊 Operations & Monitoring
- **[07-operations/](07-operations/)** - Operational guidance
  - `01_LOGGING_AND_DEBUGGING.md` - Logging setup and strategies
  - `02_MONITORING_AND_ALERTS.md` - Monitoring and alerts
  - `03_TROUBLESHOOTING_GUIDE.md` - Common issues and solutions

### ✅ Testing
- **[08-testing/](08-testing/)** - Testing strategies and guides
  - `01_TESTING_STRATEGY_AND_PYRAMID.md` - Overall testing approach
  - `02_UNIT_TESTS_GUIDE.md` - Unit testing guide
  - `03_INTEGRATION_TESTS_GUIDE.md` - Integration testing

### ✨ Features
- **[09-features/](09-features/)** - Feature-specific documentation
  - `01_ADMIN_FEATURES_GUIDE.md` - Admin panel and management
  - `02_WORKSPACE_MANAGEMENT_GUIDE.md` - Workspace collaboration
  - `03_VIDEO_PROCESSING_WORKFLOW.md` - Video generation with Veo

### 🛣️ Roadmap & Future Work
- **[roadmap/](roadmap/)** - Future enhancements, research, and planned work

#### 🔐 Auto-Provisioning Research & Implementation
- **[roadmap/auto_provisioning/](roadmap/auto_provisioning/)** - Complete research for disabling auto-provisioning (9 documents, 5,800+ lines)
  - **[README.md](roadmap/auto_provisioning/README.md)** ← **START HERE** - Master index for all documents
  - `01_RESEARCH_OVERVIEW.md` - Main navigation guide
  - `02_QUICK_REFERENCE_DECISION_GUIDE.md` - Fast 10-min decision reference
  - `03_SECURITY_AND_COST_ANALYSIS.md` - Cost/security analysis ($50k+ risk identified)
  - `04_IMPLEMENTATION_OPTIONS.md` - 4 implementation options with code examples
  - `05_EDGE_CASES_AND_EFFORT_ESTIMATION.md` - Edge cases, effort breakdown, risk assessment
  - `07_IMPLEMENTATION_GUIDE.md` - Phase 1 step-by-step implementation guide
  - `06_PRE_IMPLEMENTATION_CHECKLIST.md` - SQL queries, code audit tasks, verification steps
  - `08_DECISION_SUMMARY_AND_NEXT_STEPS.md` - Summary, decision framework, next steps

**Status**: ✅ Research Complete | **ROI**: < 1 month | **Effort**: 1-3 weeks depending on option chosen

#### 🔮 Okta Authentication Integration (Future Work)
- **[roadmap/okta_auth/](roadmap/okta_auth/)** - Complete Okta authentication integration research and roadmap (3 documents)
  - **[README.md](roadmap/okta_auth/README.md)** ← **START HERE** - Master index for Okta documentation
  - `01_INTEGRATION_OVERVIEW.md` - Comprehensive integration roadmap
  - `02_QUICK_REFERENCE_GUIDE.md` - Quick reference guide
  - **🔴 [03_CURRENT_AUTHENTICATION_ISSUES.md](roadmap/okta_auth/03_CURRENT_AUTHENTICATION_ISSUES.md) - CRITICAL** - Technical analysis of why Okta cannot be integrated without first refactoring authentication system

---

## 📖 Reading Paths by Role

### For **New Developers** (Getting Started)
1. Read: [01-getting-started/01_QUICK_START.md](01-getting-started/01_QUICK_START.md)
2. Setup: [01-getting-started/02_ENVIRONMENTS_SETUP.md](01-getting-started/02_ENVIRONMENTS_SETUP.md)
3. Run: [01-getting-started/03_DOCKER_LOCAL_SETUP.md](01-getting-started/03_DOCKER_LOCAL_SETUP.md)
4. Learn: [02-architecture/01_SYSTEM_DESIGN.md](02-architecture/01_SYSTEM_DESIGN.md)

### For **Backend Developers**
1. Architecture: [02-architecture/01_SYSTEM_DESIGN.md](02-architecture/01_SYSTEM_DESIGN.md)
2. Services: [03-backend/01_SERVICES_ARCHITECTURE.md](03-backend/01_SERVICES_ARCHITECTURE.md)
3. API: [03-backend/02_API_ENDPOINTS_REFERENCE.md](03-backend/02_API_ENDPOINTS_REFERENCE.md)
4. Auth: [03-backend/03_AUTHENTICATION_FLOW.md](03-backend/03_AUTHENTICATION_FLOW.md)
5. Database: [06-infrastructure/03_CLOUD_SQL_DATABASE.md](06-infrastructure/03_CLOUD_SQL_DATABASE.md)

### For **Frontend Developers**
1. Architecture: [02-architecture/01_SYSTEM_DESIGN.md](02-architecture/01_SYSTEM_DESIGN.md)
2. Components: [04-frontend/01_COMPONENTS_ARCHITECTURE.md](04-frontend/01_COMPONENTS_ARCHITECTURE.md)
3. Patterns: [04-frontend/02_UI_PATTERNS_GUIDE.md](04-frontend/02_UI_PATTERNS_GUIDE.md)
4. API: [03-backend/02_API_ENDPOINTS_REFERENCE.md](03-backend/02_API_ENDPOINTS_REFERENCE.md)
5. Auth: [03-backend/03_AUTHENTICATION_FLOW.md](03-backend/03_AUTHENTICATION_FLOW.md)

### For **DevOps / Infrastructure Engineers**
1. Setup: [06-infrastructure/01_GCP_PROJECT_SETUP.md](06-infrastructure/01_GCP_PROJECT_SETUP.md)
2. Terraform: [06-infrastructure/02_TERRAFORM_INFRASTRUCTURE.md](06-infrastructure/02_TERRAFORM_INFRASTRUCTURE.md)
3. Database: [06-infrastructure/03_CLOUD_SQL_DATABASE.md](06-infrastructure/03_CLOUD_SQL_DATABASE.md)
4. Backend: [06-infrastructure/04_CLOUD_RUN_BACKEND.md](06-infrastructure/04_CLOUD_RUN_BACKEND.md)
5. Frontend: [06-infrastructure/05_FIREBASE_FRONTEND_HOSTING.md](06-infrastructure/05_FIREBASE_FRONTEND_HOSTING.md)
6. Operations: [07-operations/](07-operations/)

### For **Security / Architects**
1. System Design: [02-architecture/01_SYSTEM_DESIGN.md](02-architecture/01_SYSTEM_DESIGN.md)
2. Authentication: [03-backend/03_AUTHENTICATION_FLOW.md](03-backend/03_AUTHENTICATION_FLOW.md)
3. Data Security: [05-security/03_FIRESTORE_SECURITY_RULES.md](05-security/03_FIRESTORE_SECURITY_RULES.md)
4. Access Control: [05-security/01_ACCESS_CONTROL_AND_RBAC.md](05-security/01_ACCESS_CONTROL_AND_RBAC.md)
5. GCP Setup: [06-infrastructure/01_GCP_PROJECT_SETUP.md](06-infrastructure/01_GCP_PROJECT_SETUP.md)

---

## 🗄️ Technology Stack

**Frontend:**
- Angular 18 + TypeScript
- Material Design + Tailwind CSS
- Firebase Authentication
- RxJS for state management

**Backend:**
- FastAPI (Python 3.12+)
- SQLAlchemy AsyncORM
- Cloud SQL PostgreSQL 18
- Firestore NoSQL database
- Vertex AI APIs (Imagen, Veo, Gemini, Chirp)

**Infrastructure:**
- Google Cloud Platform (GCP)
- Cloud Run (backend API)
- Firebase Hosting (frontend)
- Cloud SQL (PostgreSQL)
- Terraform (Infrastructure as Code)
- Cloud Build (CI/CD)

**Databases:**
- **Cloud SQL PostgreSQL 18** - Structured relational data (users, workspaces, media history, brand guidelines, source assets, media templates)
- **Cloud Storage** - Binary media files (images, videos, audio)

---

## ✅ Current Features

### Core Capabilities
- 🎨 **Image Generation** - Imagen 3.0 with style customization
- 🎬 **Video Generation** - Veo 2.0 for high-quality videos
- 🎵 **Audio Generation** - Chirp API for voice synthesis
- 🔄 **Multimodal Analysis** - Gemini for image understanding and prompt enhancement
- 📝 **Brand Guidelines** - PDF upload and automatic summarization
- 👥 **Workspace Collaboration** - Multi-user workspaces with role-based access
- 🎬 **Media Management** - Gallery with filtering, search, and metadata
- 📋 **Templates** - Prompt templates with variable substitution

### Advanced Features
- 🔐 Workspace-level isolation and permissions
- 👤 Role-based access control (Admin, Editor, Viewer)
- 📊 Generation history and analytics
- 🔗 Source asset management
- 🎯 Virtual Try-On (VTO) capability
- 🎨 Brand consistency enforcement

---

## 📋 Quick Facts

| Aspect | Details |
|--------|---------|
| **Total Docs** | 22 files, ~21KB content |
| **Documentation Coverage** | 100% of core features |
| **Database** | Cloud SQL PostgreSQL 18 + Firestore |
| **Backend** | FastAPI + SQLAlchemy AsyncORM |
| **Frontend** | Angular 18 + Material Design |
| **Infrastructure** | GCP with Terraform |
| **CI/CD** | Cloud Build + GitHub integration |
| **Last Updated** | December 2025 |

---

## 🔄 Documentation Status

### ✅ Updated for Current Architecture
- [x] Cloud SQL PostgreSQL implementation
- [x] SQLAlchemy AsyncORM patterns
- [x] Cloud SQL Python Connector
- [x] Database migrations (Alembic)
- [x] All GCP resources documented
- [x] Environment variables (including DB vars)
- [x] Data flow diagrams (with PostgreSQL)
- [x] Backend services (with ORM section)

### 🏗️ Reorganized Structure
- [x] Hierarchical folder organization
- [x] Clear separation by role/topic
- [x] Navigation README files
- [x] Consolidated overlapping content
- [x] Future work separated to roadmap folder

### 📊 Consistency
- [x] All files reference current architecture
- [x] Database documentation consolidated
- [x] GCP resources accurately documented
- [x] No dead links or references
- [x] Consistent terminology throughout

---

## 🚀 Getting Started Quickly

### 1. Local Development
```bash
# Clone and setup
git clone <repo>
cd creative-studio

# Setup environment
cd backend
cp .env.template .env
# Edit .env with your GCP project ID

# Run with Docker Compose
docker-compose up
```

👉 **See:** [01-getting-started/01_QUICK_START.md](01-getting-started/01_QUICK_START.md)

### 2. Configure GCP
```bash
# Enable required APIs
gcloud services enable \
  firestore.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com
```

👉 **See:** [06-infrastructure/01_GCP_PROJECT_SETUP.md](06-infrastructure/01_GCP_PROJECT_SETUP.md)

### 3. Deploy with Terraform
```bash
cd infra/environments/dev-infra-example
terraform init
terraform plan
terraform apply
```

👉 **See:** [06-infrastructure/02_TERRAFORM_INFRASTRUCTURE.md](06-infrastructure/02_TERRAFORM_INFRASTRUCTURE.md)

---

## 📞 Need Help?

1. **Can't find something?** Use the [quick navigation](#-quick-navigation) above
2. **New to the project?** Start with [Getting Started](#for-new-developers-getting-started)
3. **Specific role?** Find your path in [Reading Paths by Role](#-reading-paths-by-role)
4. **Troubleshooting?** Check [07-operations/03_TROUBLESHOOTING_GUIDE.md](07-operations/03_TROUBLESHOOTING_GUIDE.md)

---

## 📝 Contributing to Documentation

When updating the application, please update the corresponding documentation:

- **Added a new API endpoint?** → Update `03-backend/02_API_ENDPOINTS_REFERENCE.md`
- **Changed database schema?** → Update `06-infrastructure/03_CLOUD_SQL_DATABASE.md` and backend code
- **Added a new GCP service?** → Update `06-infrastructure/01_GCP_PROJECT_SETUP.md`
- **Modified environment setup?** → Update `01-getting-started/02_ENVIRONMENTS_SETUP.md`
- **Updated deployment process?** → Update `06-infrastructure/02_TERRAFORM_INFRASTRUCTURE.md`

See the guide in each section's README for specific conventions.

---

## 📄 License

Apache License 2.0

---

**Last Updated:** December 15, 2025
**Documentation Version:** 2.0
**Application Status:** ✅ Production Ready
