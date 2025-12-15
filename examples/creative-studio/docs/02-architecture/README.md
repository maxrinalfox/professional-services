# Architecture & Design

System design, data flow, and component architecture documentation.

## 📖 Guides in This Section

### [01_SYSTEM_DESIGN.md](01_SYSTEM_DESIGN.md)
**Complete system architecture and design**

- System overview diagram (frontend, backend, databases, AI services)
- Frontend architecture (Angular 18, Material, Tailwind)
- Backend architecture (FastAPI, services, ORM)
- Data layer design (Cloud SQL PostgreSQL + Firestore + Cloud Storage)
- GCP services and components
- Service accounts and IAM roles
- Terraform module structure
- CI/CD pipeline overview
- Authentication & security flow
- Technology stack and rationale

**For:** Architects, new developers, technical leads

---

### [02_DATA_FLOW_PATTERNS.md](02_DATA_FLOW_PATTERNS.md)
**End-to-end data flows and interactions**

- Image generation flow (with PostgreSQL)
- Video generation flow (async with DB)
- Brand guidelines processing
- Workspace management flow
- API request/response patterns
- Database query patterns (SQLAlchemy ORM examples)
- Firestore real-time sync
- File upload/download flows
- Search and filtering implementation
- Caching strategies
- Error handling and retry logic

**For:** Full-stack developers, backend developers, integrators

---

### [03_SYSTEM_COMPONENTS.md](03_SYSTEM_COMPONENTS.md)
**Component diagrams and relationships**

- System overview with all components
- Frontend architecture breakdown
- Backend service layer
- Data model relationships (ERD)
- Service account permissions map
- Deployment pipeline visualization
- Request/response lifecycle
- Network communication map
- Security boundaries
- Monitoring and observability architecture
- Scaling architecture

**For:** Visual learners, architects, system designers

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                  Client Layer                        │
│  Angular 18 (TypeScript, Material, Tailwind)        │
│  Firebase Authentication                             │
└──────────────────┬──────────────────────────────────┘
                   │ REST API (HTTPS)
┌──────────────────▼──────────────────────────────────┐
│               Backend Layer (Cloud Run)              │
│  FastAPI + Python 3.12                              │
│  Service Layer (Images, Videos, Auth, etc.)         │
│  SQLAlchemy AsyncORM + Cloud SQL Python Connector   │
└──┬──────────────────────────────┬────────────┬──────┘
   │                              │            │
   │                              │            │
   ▼                              ▼            ▼
┌─────────────────┐  ┌──────────────────┐  ┌──────────┐
│  Cloud SQL      │  │   Firestore      │  │  Cloud   │
│  PostgreSQL 18  │  │   (NoSQL)        │  │ Storage  │
│  - Users        │  │  - Real-time     │  │ (Media)  │
│  - Workspaces   │  │  - Sync          │  │          │
│  - Media Items  │  │                  │  │          │
│  - Assets       │  │                  │  │          │
└─────────────────┘  └──────────────────┘  └──────────┘
                            │
                            ▼
              ┌──────────────────────────┐
              │   Vertex AI Services     │
              │ - Imagen (Images)        │
              │ - Veo (Videos)           │
              │ - Gemini (Multimodal)    │
              │ - Chirp (Audio)          │
              └──────────────────────────┘
```

---

## 💾 Data Storage Strategy

### **Cloud SQL PostgreSQL 18** (Relational)
- **Structured data** with strong consistency guarantees
- **User management** (profiles, roles, metadata)
- **Workspace data** (configurations, memberships)
- **Media history** (generation records, prompts, parameters)
- **Templates & Assets** (source files, metadata)
- **Access control** (role assignments, permissions)

**Why PostgreSQL?**
- Strong consistency for user data
- ACID transactions for workspace modifications
- Complex queries with joins
- Full-text search capabilities
- Foreign key constraints

### **Firestore** (NoSQL Document Store)
- **Real-time synchronization** with clients
- **Mobile-friendly** queries
- **Automatic indexing** for common queries
- **Offline support** for web/mobile
- **Presence and activity** tracking

**Why Firestore?**
- Real-time updates without polling
- Mobile SDK support
- Automatic scaling
- Managed service (no ops)

### **Cloud Storage** (Binary Files)
- **Generated media** (images, videos, audio)
- **Uploaded assets** (source images, PDFs)
- **Signed URLs** for secure access
- **CDN-enabled** for fast downloads

---

## 🔄 Request Flow Example

```
User Action (Frontend)
    │
    ▼
Angular Event Handler
    │
    ▼
API Service (HTTP POST)
    │
    ▼
FastAPI Endpoint
    │
    ├─▶ Validate Request & Auth Token
    │
    ├─▶ Check Workspace Access (PostgreSQL)
    │
    ├─▶ Call AI Service (Vertex AI)
    │
    ├─▶ Store Result (PostgreSQL + Firestore)
    │
    └─▶ Return Response
         │
         ▼
    Angular Receives Response
         │
         ▼
    Update UI with Result
         │
         ▼
    Firestore Listener Updates Real-time
```

---

## 📊 Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Frontend Framework** | Angular 18 | Enterprise features, strong typing, CLI tooling |
| **Backend Framework** | FastAPI | Async/await support, automatic API docs, type hints |
| **Auth** | Firebase + OAuth2 | JIT provisioning, no password management, scalable |
| **Relational DB** | Cloud SQL PostgreSQL | Strong consistency, complex queries, ACID |
| **NoSQL DB** | Firestore | Real-time sync, mobile support, managed service |
| **File Storage** | Cloud Storage | Large files, CDN, cost-effective |
| **Infrastructure** | Terraform | IaC, repeatable deployments, version control |
| **ORM** | SQLAlchemy Async | Type-safe, async support, mature ecosystem |

---

## 🔐 Security Boundaries

1. **Frontend to Backend**: HTTPS only, Firebase tokens
2. **Backend to Databases**: Service accounts, private IPs
3. **Backend to AI APIs**: Service account keys (Secret Manager)
4. **Database to Storage**: Service account permissions
5. **User Workspaces**: Firestore rules + PostgreSQL checks

---

## 📈 Scalability Considerations

- **Cloud Run** auto-scales horizontally
- **Cloud SQL** scales vertically, read replicas available
- **Firestore** auto-scales transparently
- **Cloud Storage** unlimited capacity
- **Vertex AI APIs** auto-scale via Google

---

## 🚀 Next Steps

1. **Understand data flow:** Read [02_DATA_FLOW_PATTERNS.md](02_DATA_FLOW_PATTERNS.md)
2. **See components:** Check [03_SYSTEM_COMPONENTS.md](03_SYSTEM_COMPONENTS.md)
3. **Backend details:** [03-backend/01_SERVICES_ARCHITECTURE.md](../03-backend/01_SERVICES_ARCHITECTURE.md)
4. **Frontend details:** [04-frontend/03_SYSTEM_COMPONENTS.md](../04-frontend/03_SYSTEM_COMPONENTS.md)
5. **Infrastructure:** [06-infrastructure/01_GCP_PROJECT_SETUP.md](../06-infrastructure/01_GCP_PROJECT_SETUP.md)
