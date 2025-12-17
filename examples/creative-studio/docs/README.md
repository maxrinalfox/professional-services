# Creative Studio Documentation

Complete documentation for the **Creative Studio** - A comprehensive Generative AI platform built on Google Cloud Platform with Vertex AI integration.

> 🚀 This documentation covers the current state of the application including Cloud SQL PostgreSQL, SQLAlchemy ORM, and all GCP resources.

---

## 🚨 **IMPORTANT: Known Issues & Roadmap**

**Before reading other docs, review these critical documents:**

1. **[00-KNOWN_ISSUES.md](00-KNOWN_ISSUES.md)** ⭐ **START HERE** - List of current blockers and issues
   - Authentication system is hybrid/broken (Phase 1 required)
   - Data consistency across user storage
   - API and performance issues

2. **[roadmap/IMPLEMENTATION_STRATEGY_MASTER_INDEX.md](roadmap/IMPLEMENTATION_STRATEGY_MASTER_INDEX.md)** - 3-Phase plan to fix issues
   - Phase 1: Choose authentication architecture (Firebase OR Pure OIDC)
   - Phase 2: Add OIDC + groups support
   - Phase 3: Enterprise auto-provisioning

3. **[roadmap/okta_auth/06_PHASE1_TWO_ALTERNATIVES.md](roadmap/okta_auth/06_PHASE1_TWO_ALTERNATIVES.md)** - Detailed alternatives for Phase 1

---

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
  - `04_E2E_TESTS_GUIDE.md` - End-to-End testing

### ✨ Features
- **[09-features/](09-features/)** - Feature-specific documentation
  - `01_ADMIN_FEATURES_GUIDE.md` - Admin panel and management
  - `02_WORKSPACE_MANAGEMENT_GUIDE.md` - Workspace collaboration
  - `03_VIDEO_PROCESSING_WORKFLOW.md` - Video generation with Veo

### 🛣️ Roadmap & Future Work
- **[roadmap/](roadmap/)** - Future enhancements, research, and planned work
- **📌 [IMPLEMENTATION_STRATEGY_MASTER_INDEX.md](roadmap/IMPLEMENTATION_STRATEGY_MASTER_INDEX.md)** ← **MASTER INDEX - START HERE**

#### 🔐 3-Phase Authentication Evolution

**Status**: Phase 1 is BLOCKING (must complete first). Phases 2 & 3 are dependent.

**Phase 1: Fix Authentication Architecture** (1-2 weeks) - REQUIRED
- **[roadmap/okta_auth/](roadmap/okta_auth/)** - Architecture refactoring (blocks all other auth work)
  - ⭐ **[03_CURRENT_AUTHENTICATION_ISSUES.md](roadmap/okta_auth/03_CURRENT_AUTHENTICATION_ISSUES.md)** - Technical problem analysis
  - ⭐ **[04_DEMO_APP_COMPARISON.md](roadmap/okta_auth/04_DEMO_APP_COMPARISON.md)** - Proven solution pattern
  - **[README.md](roadmap/okta_auth/README.md)** - Phase 1 overview

**Phase 2: Add OIDC + Groups Support** (1-2 weeks) - After Phase 1
- **[roadmap/authentication_options/](roadmap/authentication_options/)** - OIDC provider integration
  - **[README.md](roadmap/authentication_options/README.md)** - Phase 2 overview
  - **[01_AUTHENTICATION_COMPARISON.md](roadmap/authentication_options/01_AUTHENTICATION_COMPARISON.md)** - 3 approaches compared
  - **[02_FIREBASE_OIDC_IMPLEMENTATION_GUIDE.md](roadmap/authentication_options/02_FIREBASE_OIDC_IMPLEMENTATION_GUIDE.md)** - Implementation guide

**Phase 3: Enterprise Auto-Provisioning** (1-3 weeks) - After Phases 1 & 2 (Optional)
- **[roadmap/auto_provisioning/](roadmap/auto_provisioning/)** - Automatic user/workspace provisioning
  - **[README.md](roadmap/auto_provisioning/README.md)** - Phase 3 overview
  - **[02_QUICK_REFERENCE_DECISION_GUIDE.md](roadmap/auto_provisioning/02_QUICK_REFERENCE_DECISION_GUIDE.md)** - 10-min decision guide
  - **[04_IMPLEMENTATION_OPTIONS.md](roadmap/auto_provisioning/04_IMPLEMENTATION_OPTIONS.md)** - 4 implementation options
  - **[03_SECURITY_AND_COST_ANALYSIS.md](roadmap/auto_provisioning/03_SECURITY_AND_COST_ANALYSIS.md)** - Cost analysis ($50k+ risk)

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
- Google Sign-In only (via deprecated `google.accounts.id` API in production)
  - ⚠️ **Status**: Hardcoded to Google, no multi-provider support (see roadmap)
- RxJS for state management

**Backend:**
- FastAPI (Python 3.12+)
- SQLAlchemy AsyncORM + PostgreSQL (primary user database)
- Cloud SQL PostgreSQL 18 (structured data)
- Firestore NoSQL database (metadata + real-time sync)
- Firebase Admin SDK (token validation only, not user creation)
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

### ✅ December 2025 Updates
- [x] **CRITICAL**: Known Issues document created
- [x] **CRITICAL**: Authentication reality corrected (hybrid system documented)
- [x] **CRITICAL**: Phase 1 Two Alternatives document (Firebase vs Pure OIDC)
- [x] Backend authentication flow diagram (actual current state)
- [x] Roadmap navigation structure fixed
- [x] Cross-references validated (no orphaned files)

### ✅ Current Architecture Documented
- [x] Cloud SQL PostgreSQL implementation
- [x] SQLAlchemy AsyncORM patterns
- [x] Cloud SQL Python Connector
- [x] Database migrations (Alembic)
- [x] All GCP resources documented
- [x] Environment variables (including DB vars)
- [x] Data flow diagrams (with PostgreSQL)
- [x] Backend services (with ORM section)
- [x] **Authentication (actual current state)**
- [x] User data split across PostgreSQL/Firestore/Firebase noted

### 🏗️ Reorganized Structure
- [x] Hierarchical folder organization
- [x] Clear separation by role/topic
- [x] Navigation README files
- [x] Consolidated overlapping content
- [x] Future work separated to roadmap folder
- [x] **Known Issues at top level**
- [x] **Roadmap clearly organized with Phase 1 decision point**

### ❌ KNOWN ISSUES (Require Phase 1 Implementation)
- [ ] Authentication system (hybrid, deprecated API) → Phase 1 required
- [ ] Data consistency across user storage → Phase 1/Phase 2
- [ ] API error handling inconsistent → Medium priority
- [ ] Component performance optimization → Medium priority
- [ ] Query performance tuning → Medium priority
- [ ] Video processing error handling → Medium priority

See [00-KNOWN_ISSUES.md](00-KNOWN_ISSUES.md) for complete details

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
