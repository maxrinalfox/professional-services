# Creative Studio Architecture

## Overview

Creative Studio is a comprehensive Generative AI platform built on Google Cloud Platform, featuring a modern Angular frontend, FastAPI backend, and full infrastructure-as-code with Terraform. It integrates with Vertex AI for advanced generative capabilities including image generation (Imagen), video generation (Veo), and multimodal analysis with Gemini.

---

## System Architecture Diagram

```mermaid
graph TB
    User["👤 User/Browser"]

    subgraph Frontend["🌐 Frontend Layer - Firebase Hosting"]
        FE["Angular 18 SPA<br/>(TypeScript/Material/Tailwind)"]
        Auth["🔐 Firebase Auth"]
        FECache["Cache & Storage"]
    end

    subgraph Backend["⚙️ Backend Layer - Cloud Run"]
        API["FastAPI Application<br/>(Python)"]
        AuthInterceptor["Auth Interceptor"]
        Routers["API Routers"]
        Services["Services Layer"]
    end

    subgraph Database["💾 Data Layer"]
        Firestore["Firestore Database<br/>(NoSQL - Real-time)"]
        GCS["Google Cloud Storage<br/>(Media Files)"]
        SQL["Cloud SQL<br/>(PostgreSQL 18 - Relational)"]
    end

    subgraph AI["🤖 AI/ML Services"]
        VertexAI["Vertex AI Platform"]
        Imagen["Imagen API<br/>(Image Generation)"]
        Veo["Veo API<br/>(Video Generation)"]
        Gemini["Gemini API<br/>(Multimodal Analysis)"]
    end

    subgraph Infrastructure["🏗️ Infrastructure - Terraform"]
        TF["Terraform Modules"]
        CloudBuild["Cloud Build<br/>(CI/CD)"]
    end

    User -->|HTTPS| FE
    FE -->|Firebase Auth Token| Auth
    FE -->|REST API| API
    API -->|Validates Token| AuthInterceptor
    API --> Routers
    Routers --> Services
    Services -->|Read/Write| Firestore
    Services -->|Upload/Download| GCS
    Services -->|SQLAlchemy ORM| SQL
    Services -->|Requests| VertexAI
    VertexAI --> Imagen
    VertexAI --> Veo
    VertexAI --> Gemini
    TF -->|Provisions| Backend
    TF -->|Provisions| Database
    TF -->|Provisions| Frontend
    CloudBuild -->|Deploys| Backend
    CloudBuild -->|Deploys| Frontend
```

---

## Frontend Architecture

### Technology Stack
- **Framework**: Angular 18
- **Language**: TypeScript
- **Styling**: Tailwind CSS + Angular Material
- **Authentication**: Firebase Authentication
- **Build Tool**: Angular CLI
- **Linting**: GTS (Google TypeScript Style Guide)
- **Package Manager**: npm

### Component Structure

```mermaid
graph LR
    subgraph Components["Core Components"]
        AppComp["App Component<br/>(Root)"]
        Home["Home Component"]
        Header["Header Component"]
        Footer["Footer Component"]
    end

    subgraph Features["Feature Modules"]
        Gallery["Gallery Module"]
        VTO["VTO Module<br/>(Virtual Try-On)"]
        Audio["Audio Component"]
        Video["Video Component"]
        FunTemplates["Fun Templates"]
        Admin["Admin Module"]
    end

    subgraph Services["Services Layer"]
        AuthSvc["Auth Service"]
        GallerySvc["Gallery Service"]
        API["HTTP API Service"]
        Loading["Loading Service"]
    end

    subgraph Interceptors["HTTP Interceptors"]
        AuthInt["Auth Interceptor<br/>(Adds Bearer Token)"]
    end

    Backend["Backend API"]

    AppComp --> Components
    Components --> Features
    Features --> Services
    Services --> Interceptors
    Interceptors -->|REST Calls| Backend
```

### Key Components

| Component | Purpose |
|-----------|---------|
| **app-root** | Root component with route animations |
| **home** | Landing page and dashboard |
| **gallery** | Media library viewer with metadata |
| **media-detail** | Detailed view of generated media |
| **vto** | Virtual try-on interface |
| **audio** | Audio generation interface |
| **fun-templates** | Predefined prompt templates |
| **admin** | Admin dashboard for configuration |

### Project Structure
```
frontend/
├── src/
│   ├── app/
│   │   ├── admin/              # Admin panel
│   │   ├── arena/              # Workspace/arena interface
│   │   ├── audio/              # Audio generation UI
│   │   ├── common/             # Shared utilities & services
│   │   │   ├── services/       # HTTP, auth, loading services
│   │   │   └── interceptors/   # Auth interceptor
│   │   ├── gallery/            # Media gallery & management
│   │   ├── home/               # Homepage
│   │   ├── login/              # Login/auth page
│   │   ├── services/           # API communication services
│   │   ├── video/              # Video generation UI
│   │   └── vto/                # Virtual try-on module
│   ├── environments/           # Environment configs
│   └── main.ts                 # Bootstrap
├── angular.json                # Angular build config
├── firebase.json               # Firebase config
├── cloudbuild.yaml             # CI/CD pipeline
└── Dockerfile                  # Container image
```

---

## Backend Architecture

### Technology Stack
- **Framework**: FastAPI (Python 3.10+)
- **Server**: Uvicorn
- **Code Style**: Google Python Style Guide + Black + Pylint
- **Package Manager**: uv (with pyproject.toml)

### API Endpoint Structure

```mermaid
graph LR
    Request["Incoming Request"]
    CORS["CORS Middleware"]
    Auth["Firebase Auth<br/>Verification"]

    Request --> CORS
    CORS --> Auth

    Auth --> Image["🖼️ Image Router<br/>/api/images"]
    Auth --> Video["🎬 Video Router<br/>/api/videos"]
    Auth --> Audio["🔊 Audio Router<br/>/api/audios"]
    Auth --> Gallery["📷 Gallery Router<br/>/api/galleries"]
    Auth --> User["👤 User Router<br/>/api/users"]
    Auth --> Workspace["🏢 Workspace Router<br/>/api/workspaces"]
    Auth --> SourceAsset["📁 Source Assets Router<br/>/api/source-assets"]
    Auth --> BrandGuideline["🎨 Brand Guidelines Router<br/>/api/brand-guidelines"]
    Auth --> MediaTemplate["📋 Media Templates Router<br/>/api/templates"]
    Auth --> GenOptions["⚙️ Generation Options Router<br/>/api/generation-options"]
    Auth --> Gemini["✨ Gemini Router<br/>/api/gemini"]

    Image --> ImageService["Image Service<br/>Imagen API Integration"]
    Video --> VideoService["Video Service<br/>Veo API Integration"]
    Audio --> AudioService["Audio Service<br/>Chirp/Lyria API"]
    Gallery --> GalleryService["Gallery Service<br/>Firestore Queries"]
    User --> UserService["User Service<br/>User Management"]
    Workspace --> WorkspaceService["Workspace Service<br/>Collaboration"]
    SourceAsset --> AssetService["Asset Service<br/>GCS Uploads"]
    BrandGuideline --> BrandService["Brand Service<br/>PDF Processing"]
    MediaTemplate --> TemplateService["Template Service<br/>Prompt Caching"]
    Gemini --> GeminiService["Gemini Service<br/>Multimodal Analysis"]

    ImageService --> VertexAI["Vertex AI API"]
    VideoService --> VertexAI
    AudioService --> VertexAI
    GeminiService --> VertexAI

    GalleryService --> DB["Firestore"]
    UserService --> DB
    WorkspaceService --> DB
    AssetService --> GCS["Google Cloud Storage"]
    BrandService --> GCS
```

### Backend Project Structure

```
backend/
├── src/
│   ├── audios/                 # Audio generation service
│   │   ├── audio_controller.py
│   │   └── audio_service.py
│   ├── auth/                   # Firebase authentication
│   │   └── firebase_client_service.py
│   ├── brand_guidelines/       # Brand guideline handling
│   │   ├── brand_guideline_controller.py
│   │   ├── brand_guideline_service.py
│   │   ├── dto/
│   │   ├── repository/
│   │   └── schema/
│   ├── galleries/              # Media library management
│   │   ├── gallery_controller.py
│   │   ├── gallery_service.py
│   │   ├── repository/
│   │   └── schema/
│   ├── generation_options/     # Generation parameters
│   │   ├── generation_options_controller.py
│   │   └── dto/
│   ├── images/                 # Imagen integration
│   │   ├── imagen_controller.py
│   │   ├── imagen_service.py
│   │   ├── dto/
│   │   ├── repository/
│   │   └── schema/
│   ├── media_templates/        # Prompt templates
│   │   ├── media_templates_controller.py
│   │   ├── media_templates_service.py
│   │   ├── dto/
│   │   ├── repository/
│   │   └── schema/
│   ├── multimodal/             # Gemini integration
│   │   ├── gemini_controller.py
│   │   └── gemini_service.py
│   ├── source_assets/          # Asset management
│   │   ├── source_asset_controller.py
│   │   ├── source_asset_service.py
│   │   ├── dto/
│   │   ├── repository/
│   │   └── schema/
│   ├── users/                  # User management
│   │   ├── user_controller.py
│   │   ├── user_service.py
│   │   ├── dto/
│   │   ├── repository/
│   │   └── schema/
│   ├── videos/                 # Veo integration
│   │   ├── veo_controller.py
│   │   ├── veo_service.py
│   │   ├── dto/
│   │   └── schema/
│   ├── workspaces/             # Workspace collaboration
│   │   ├── workspace_controller.py
│   │   ├── workspace_service.py
│   │   ├── dto/
│   │   ├── repository/
│   │   └── schema/
│   ├── common/                 # Shared utilities
│   │   ├── database/
│   │   ├── storage/
│   │   └── models/
│   ├── config/                 # Configuration
│   │   ├── config_service.py
│   │   └── logger_config.py
│   └── __init__.py
├── main.py                     # FastAPI app initialization
├── pyproject.toml              # Python dependencies
├── pylintrc                    # Linting config
├── cloudbuild.yaml             # CI/CD pipeline
└── Dockerfile                  # Container image
```

### API Router Overview

| Router | Base Path | Purpose |
|--------|-----------|---------|
| **Imagen** | `/api/images` | Image generation endpoints |
| **Veo** | `/api/videos` | Video generation endpoints |
| **Audio** | `/api/audios` | Audio generation endpoints |
| **Gallery** | `/api/galleries` | Media library operations |
| **Gemini** | `/api/gemini` | Multimodal analysis endpoints |
| **Users** | `/api/users` | User management |
| **Workspaces** | `/api/workspaces` | Workspace management |
| **Source Assets** | `/api/source-assets` | Asset upload/management |
| **Brand Guidelines** | `/api/brand-guidelines` | Brand PDF processing |
| **Media Templates** | `/api/templates` | Prompt template management |
| **Generation Options** | `/api/generation-options` | Available generation parameters |

---

## Data Layer

The application uses a **hybrid database approach**:
- **Cloud SQL PostgreSQL**: Structured relational data (users, workspaces, media items, assets)
- **Firestore**: Real-time synchronization and mobile-friendly queries
- **Cloud Storage**: Binary media files (images, videos, audio)

### Cloud SQL PostgreSQL Database

Creative Studio uses **PostgreSQL 18** on Google Cloud SQL for storing structured data with strong consistency requirements.

#### Purpose
Cloud SQL PostgreSQL stores:
- **User Management**: User profiles, roles, workspace memberships
- **Workspace Data**: Workspace configurations, ownership, member relationships
- **Media History**: Generation history, prompts, parameters, status tracking
- **Templates & Assets**: Media templates, source assets, brand guidelines
- **Relational Integrity**: Foreign keys and constraints for data consistency

#### Tables

```mermaid
graph LR
    Users["users<br/>Email, roles, profile"]
    Workspaces["workspaces<br/>Name, owner, scope"]
    Members["workspace_members<br/>Workspace-User roles"]
    MediaItems["media_items<br/>Generation history"]
    Templates["media_templates<br/>Prompt templates"]
    SourceAssets["source_assets<br/>Uploaded files"]
    BrandGuides["brand_guidelines<br/>Brand PDFs"]

    Users -->|owner| Workspaces
    Workspaces -->|members| Members
    Members -->|member| Users
    MediaItems -->|creator| Users
    MediaItems -->|workspace| Workspaces
    Templates -->|for workspace| Workspaces
    SourceAssets -->|owner| Users
    SourceAssets -->|workspace| Workspaces
    BrandGuides -->|workspace| Workspaces
    BrandGuides -->|logo| SourceAssets
    MediaItems -->|template| Templates
```

#### Connection Architecture

```mermaid
graph LR
    CloudRun["Cloud Run<br/>FastAPI Backend"]
    ORM["SQLAlchemy<br/>Async ORM"]
    Connector["Cloud SQL<br/>Python Connector"]
    CloudSQL["Cloud SQL<br/>PostgreSQL 18"]
    Secrets["Secret Manager<br/>DB Password"]

    CloudRun -->|SQLAlchemy| ORM
    ORM -->|asyncpg| Connector
    Connector -->|TCP/IP| CloudSQL
    Connector -->|Read| Secrets
    CloudSQL -->|Execute| Query["SQL Queries"]
```

#### Key Features
- **Async Support**: SQLAlchemy AsyncSession for non-blocking database access
- **Connection Pooling**: Cloud SQL Python Connector manages connection lifecycle
- **Password Management**: Database password stored in Secret Manager
- **Migrations**: Alembic for schema versioning and migrations
- **Automatic Timestamps**: created_at and updated_at fields on all tables
- **JSON Columns**: JSONB columns for flexible data storage (source_assets, generation_parameters)
- **Array Columns**: PostgreSQL arrays for tags, URIs, color palettes

#### Query Examples

```python
# Get user with all workspaces
user = await session.execute(
    select(User).where(User.email == "user@example.com")
)

# Get media items by workspace
items = await session.execute(
    select(MediaItem)
    .where(MediaItem.workspace_id == workspace_id)
    .order_by(MediaItem.created_at.desc())
    .limit(50)
)

# Get workspace members with roles
members = await session.execute(
    select(WorkspaceMember)
    .join(User)
    .where(WorkspaceMember.workspace_id == workspace_id)
)
```

---

### Firestore Database Schema

```mermaid
graph LR
    FS["Firestore Database<br/>(Native Mode)"]

    subgraph Collections["Collections"]
        MediaLib["media_library<br/>Generated media items"]
        Users["users<br/>User profiles"]
        SourceAssets["source_assets<br/>Uploaded assets"]
        BrandGuides["brand_guidelines<br/>Brand PDFs"]
        Templates["media_templates<br/>Prompt templates"]
        Workspaces["workspaces<br/>Collaboration spaces"]
    end

    FS --> Collections

    subgraph Indexes["Auto-Generated Indexes"]
        Index1["media_library:<br/>workspace_id, user_email,<br/>created_at DESC"]
        Index2["source_assets:<br/>user_id, asset_type,<br/>created_at DESC"]
        Index3["media_library:<br/>status, created_at DESC"]
        Index4["users: role,<br/>created_at DESC"]
        Index5["brand_guidelines:<br/>workspace_id,<br/>created_at DESC"]
    end

    Collections --> Indexes
```

### Key Collections

#### media_library
Stores generated media with metadata
```
Fields:
- id (PK)
- workspace_id (FK)
- user_email (string)
- mime_type (video/mp4, image/png, etc.)
- model (imagen-3-fast, veo-1, chirp-1, etc.)
- status (pending, success, failed)
- prompt (string)
- source_asset_ids (array)
- gcs_uri (Cloud Storage path)
- created_at (timestamp)
- metadata (JSON object)
```

#### source_assets
Stores uploaded reference assets for generation
```
Fields:
- id (PK)
- workspace_id (FK)
- user_id (string)
- asset_type (garment, model, reference_image, etc.)
- scope (user, workspace, system)
- mime_type (image/png, image/jpeg, etc.)
- file_hash (string - deduplication)
- original_filename (string)
- gcs_uri (Cloud Storage path)
- created_at (timestamp)
```

#### users
User profile and role management
```
Fields:
- id (PK / email)
- email (string)
- role (admin, editor, viewer)
- workspace_id (FK)
- created_at (timestamp)
```

#### brand_guidelines
Uploaded brand style guides
```
Fields:
- id (PK)
- workspace_id (FK)
- pdf_uri (Cloud Storage path)
- extracted_text (string)
- created_at (timestamp)
```

#### media_templates
Prompt templates for quick generation
```
Fields:
- id (PK)
- workspace_id (FK)
- name (string)
- description (string)
- prompt (string)
- model (imagen-3-fast, veo-1, etc.)
- category (product, portrait, landscape, etc.)
- created_at (timestamp)
```

#### workspaces
Collaboration spaces
```
Fields:
- id (PK)
- name (string)
- owner_id (FK user)
- members (array of user IDs)
- created_at (timestamp)
```

---

## Google Cloud Platform Components

### Service Accounts & IAM Roles

```mermaid
graph TB
    Project["GCP Project"]

    subgraph BackendSA["Backend Service Account<br/>cs-{env}-run"]
        BackendEmail["Email: cs-{env}-run@<br/>PROJECT_ID.iam.gserviceaccount.com"]
        BackendRoles["Roles:<br/>• aiplatform.user<br/>• storage.objectUser<br/>• firestore.admin<br/>• secretmanager.secretAccessor"]
    end

    subgraph BuildSA["Build Service Account<br/>cs-{env}-trig"]
        BuildEmail["Email: cs-{env}-trig@<br/>PROJECT_ID.iam.gserviceaccount.com"]
        BuildRoles["Roles:<br/>• artifactregistry.writer<br/>• run.admin<br/>• cloudbuild.builds.editor<br/>• iam.serviceAccountUser"]
    end

    subgraph BucketReadSA["Bucket Reader Service Account<br/>cs-{env}-read"]
        BucketEmail["Email: cs-{env}-read@<br/>PROJECT_ID.iam.gserviceaccount.com"]
        BucketRoles["Roles:<br/>• storage.objectViewer"]
    end

    Project --> BackendSA
    Project --> BuildSA
    Project --> BucketReadSA

    BackendEmail --> BackendRoles
    BuildEmail --> BuildRoles
    BucketEmail --> BucketRoles
```

### Service Account Details & Permissions

#### Backend Runtime Service Account
**Account ID**: `cs-{env}-run`

**Purpose**: Executes backend API code on Cloud Run

**Permissions**:
```
roles/aiplatform.user
  └─ Call Vertex AI APIs (Imagen, Veo, Gemini, Chirp)

roles/storage.objectUser
  └─ Read/Write GenMedia bucket
  └─ Read signed URLs for media access

roles/firestore.admin
  └─ Full Firestore database access
  └─ Create/Update/Delete documents

roles/secretmanager.secretAccessor
  └─ Access runtime secrets from Secret Manager
```

#### Build Trigger Service Account
**Account ID**: `cs-{env}-trig`

**Purpose**: Cloud Build automation for CI/CD

**Permissions**:
```
roles/artifactregistry.writer
  └─ Push Docker images to Artifact Registry

roles/run.admin
  └─ Deploy & update Cloud Run services

roles/cloudbuild.builds.editor
  └─ Trigger and manage Cloud Build jobs

roles/iam.serviceAccountUser
  └─ Impersonate backend runtime SA for deployment
```

#### GenMedia Bucket Reader Service Account
**Account ID**: `cs-{env}-read`

**Purpose**: Generate signed URLs for media access (optional)

**Permissions**:
```
roles/storage.objectViewer
  └─ View GenMedia bucket objects
  └─ Generate presigned URLs for media access
```

### Key GCP Services

```mermaid
graph LR
    Project["GCP Project"]
    Run["Cloud Run<br/>(Backend Container)"]
    Firebase["Firebase<br/>(Frontend Hosting)"]
    FS["Firestore<br/>(NoSQL Database)"]
    GCS["Cloud Storage<br/>(GenMedia Bucket)"]
    VertexAI["Vertex AI<br/>(Imagen/Veo/Gemini)"]
    CB["Cloud Build<br/>(CI/CD)"]
    AR["Artifact Registry<br/>(Docker Images)"]
    IAM["IAM<br/>(Credentials)"]
    Secrets["Secret Manager<br/>(Secrets Storage)"]

    Project -->|Enable| Run
    Project -->|Enable| Firebase
    Project -->|Enable| FS
    Project -->|Enable| GCS
    Project -->|Enable| VertexAI
    Project -->|Enable| CB
    Project -->|Enable| AR
    Project -->|Enable| IAM
    Project -->|Enable| Secrets
```

| Service | Purpose | Role |
|---------|---------|------|
| **Cloud Run** | Backend API container execution | Serverless compute |
| **Firebase Hosting** | Static frontend SPA hosting | Frontend serving |
| **Firestore** | NoSQL document database | Primary data store |
| **Cloud Storage** | Media file storage | GenMedia bucket |
| **Vertex AI** | Generative AI model APIs | ML model access |
| **Cloud Build** | CI/CD automation | Deployment pipeline |
| **Artifact Registry** | Docker image repository | Image storage |
| **IAM** | Identity & access management | Security |
| **Secret Manager** | Encrypted secrets storage | Credentials |

---

## Infrastructure as Code (Terraform)

### Terraform Module Structure

```mermaid
graph TB
    Root["environments/dev-infra-example"]
    Platform["modules/platform<br/>Main orchestration"]
    Backend["modules/cloud-run-service<br/>Backend deployment"]
    Frontend["modules/firebase-hosting-service<br/>Frontend deployment"]
    Secrets["modules/secret-manager<br/>Secret configuration"]
    FS["Firestore DB"]
    GCS["Storage Bucket"]
    SA["Service Accounts"]
    Indexes["Firestore Indexes"]

    Root -->|calls| Platform
    Root -->|calls| Backend
    Root -->|calls| Frontend
    Root -->|calls| Secrets

    Platform -->|creates| FS
    Platform -->|creates| GCS
    Platform -->|creates| SA
    Platform -->|creates| Indexes
    Platform -->|calls| Backend
    Platform -->|calls| Frontend
    Platform -->|calls| Secrets
```

### Module Overview

| Module | Responsibility |
|--------|-----------------|
| **platform** | Core infrastructure (Firestore, Storage, IAM, Indexes) |
| **cloud-run-service** | Backend API deployment, Cloud Build triggers |
| **firebase-hosting-service** | Frontend hosting and deployment |
| **secret-manager** | Secret access configuration |

### Terraform Variables (Environment-Based)

```
Input Variables (infra/environments/dev-infra-example/terraform.tfvars):

gcp_project_id          # Google Cloud Project ID
gcp_region              # Deployment region (e.g., us-central1)
environment             # Environment name (dev, staging, prod)

Backend Configuration:
backend_service_name    # Cloud Run service name
be_env_vars             # Backend environment variables
be_cpu                  # Backend CPU allocation
be_memory               # Backend memory allocation
backend_runtime_secrets # Secret references
backend_custom_audiences# OIDC audiences

Frontend Configuration:
frontend_service_name   # Firebase service name
frontend_custom_audiences# OIDC audiences
fe_build_substitutions  # Build-time substitutions

GitHub Integration:
github_conn_name        # Cloud Build connection name
github_repo_owner       # Repository owner
github_repo_name        # Repository name
github_branch_name      # Deployment branch

Secret Configuration:
frontend_secrets        # Frontend secret names
backend_secrets         # Backend secret names

APIs to Enable:
apis_to_enable          # List of GCP APIs to activate
```

---

## CI/CD Pipeline

### Cloud Build Workflow

```mermaid
graph LR
    GitHub["GitHub Repository<br/>(Push to Branch)"]
    Trigger["Cloud Build Trigger<br/>(Repository Event)"]
    BuildJob["Cloud Build Job"]

    GitHub -->|Webhook| Trigger
    Trigger -->|Executes| BuildJob

    subgraph BackendPipeline["Backend Pipeline"]
        BuildBE["1. Build Docker Image"]
        PushBE["2. Push to Artifact Registry"]
        DeployBE["3. Deploy to Cloud Run"]
    end

    subgraph FrontendPipeline["Frontend Pipeline"]
        BuildFE["1. npm build"]
        DeployFE["2. Firebase Deploy"]
    end

    BuildJob -->|If path matches backend/**| BackendPipeline
    BuildJob -->|If path matches frontend/**| FrontendPipeline

    BackendPipeline --> BackendSA["Uses: Build SA"]
    FrontendPipeline --> FrontendSA["Uses: Build SA"]

    BackendSA -->|Deploys with| BackendRunSA["Backend Runtime SA"]
    DeployBE --> CloudRun["Cloud Run Service"]
    DeployFE --> Firebase["Firebase Hosting"]
```

### Build Configuration Files

**Backend**: `backend/cloudbuild.yaml`
- Builds Docker image from Dockerfile
- Pushes to Artifact Registry
- Deploys new image to Cloud Run service

**Frontend**: `frontend/cloudbuild-deploy.yaml`
- Runs npm build for Angular compilation
- Deploys built assets to Firebase Hosting
- Updates build substitutions for API URLs

---

## Deployment Architecture Diagram

```mermaid
graph TB
    subgraph User["User Interaction"]
        Browser["Web Browser"]
    end

    subgraph CDN["CDN & Hosting"]
        Firebase["Firebase Hosting<br/>(CDN)"]
    end

    subgraph Backend["Compute"]
        CloudRun["Cloud Run<br/>(Auto-scaling)"]
    end

    subgraph Data["Data & Storage"]
        Firestore["Firestore Database"]
        GCS["Cloud Storage<br/>(GenMedia)"]
    end

    subgraph AI["AI Services"]
        VertexAI["Vertex AI"]
        Models["Imagen | Veo | Gemini<br/>| Chirp"]
    end

    subgraph Automation["Automation"]
        CloudBuild["Cloud Build"]
        GitHub["GitHub<br/>Repository"]
    end

    Browser -->|HTTPS| Firebase
    Firebase -->|Routes /api| CloudRun
    Auth["Firebase Auth"]

    CloudRun -->|OIDC Token| Auth
    CloudRun -->|Query/Update| Firestore
    CloudRun -->|Upload/Download| GCS
    CloudRun -->|API Calls| VertexAI
    VertexAI --> Models
    GitHub -->|Webhook| CloudBuild
    CloudBuild -->|Deploy| Firebase
    CloudBuild -->|Deploy| CloudRun
```

---

## Authentication & Security Flow

```mermaid
sequenceDiagram
    actor User as User
    participant Browser as Browser
    participant Firebase as Firebase Auth
    participant Frontend as Angular Frontend
    participant Backend as FastAPI Backend
    participant Firestore as Firestore

    User->>Browser: 1. Opens App
    Browser->>Firebase: 2. Check Auth State
    alt User Authenticated
        Firebase->>Frontend: 3. Cached Token
        Frontend->>Frontend: 4. Check Token Expiry
        Frontend->>Backend: 5. API Call + Bearer Token
        Backend->>Backend: 6. Verify Token Signature
        Backend->>Firestore: 7. Execute Query
        Firestore->>Backend: 8. Return Data
        Backend->>Frontend: 9. Response
        Frontend->>Browser: 10. Render UI
    else User Not Authenticated
        Firebase->>Frontend: 3. Redirect to Login
        Frontend->>Browser: 4. Show Login Page
        User->>Firebase: 5. Enter Credentials
        Firebase->>Frontend: 6. Issue ID Token
        Frontend->>Browser: 7. Redirect to Dashboard
    end
```

---

## Environment Configuration

### Local Development
```
docker-compose.yml
├── Backend Service
│   ├── Port: 8080
│   ├── Reload: Enabled
│   └── Volume: ./backend:/app
├── Frontend Service
│   ├── Port: 4200
│   ├── Hot reload: Enabled
│   └── Volume: ./frontend/src:/app/src
└── Volumes
    └── backend_venv (Python environment)
```

### Production Deployment (GCP)
```
Cloud Run (Backend)
├── Service Account: cs-prod-run
├── Region: var.gcp_region
├── Min Instances: 1
├── Max Instances: auto-scaled
└── Secrets: From Secret Manager

Firebase Hosting (Frontend)
├── Custom Domain: PROJECT_ID.web.app
├── CDN: Google CDN
├── Rewrite: /api/* → Cloud Run backend
└── Secrets: From Secret Manager
```

---

## Key Features Architecture

### 1. Image Generation (Imagen)
```
User Prompt
    ↓
Brand Guidelines (if provided)
    ↓
Gemini: Enhance Prompt
    ↓
Imagen API Call
    ↓
Generated Image
    ↓
Store in GCS + Firestore metadata
```

### 2. Video Generation (Veo)
```
User Prompt + Optional Reference Image
    ↓
Image-to-Video or Text-to-Video
    ↓
Veo API Call
    ↓
Generated Video (polling for completion)
    ↓
Store in GCS + Firestore metadata
```

### 3. Virtual Try-On (VTO)
```
System Assets (Garments, Models)
    ↓
Source Assets Storage (user uploads)
    ↓
VTO API Integration
    ↓
Real-time Preview
```

### 4. Brand Guidelines Processing
```
User Uploads PDF
    ↓
GCS Signed URL Upload (bypass timeout)
    ↓
Backend Processing
    ↓
PDF Text Extraction
    ↓
Store Reference in Firestore
    ↓
Integrate into Generation Prompts
```

---

## Network & Security

### CORS Configuration
```
Production:
  Allowed Origins: FRONTEND_URL (Firebase domain)

Development:
  Allowed Origins: * (all domains)

Methods: GET, POST, PUT, DELETE, PATCH
Credentials: Allowed
```

### Cloud Run Security
- No public unauthenticated access (except health checks)
- Firebase OIDC token validation on all endpoints
- Environment variables from Secret Manager
- Private service account per environment

### Firestore Security
- Rules configured per environment
- User-based access control
- Workspace-level isolation

### Cloud Storage Security
- Signed URLs for temporary access
- Bucket-level IAM policies
- Optional: Service account-based presigned URL generation

---

## Scaling & Performance

### Backend Scaling (Cloud Run)
- **Min Instances**: 1 (always warm)
- **Max Instances**: Auto-scaled based on traffic
- **Timeout**: 3600 seconds (1 hour for long-running tasks)
- **Memory**: Configurable (e.g., 2Gi, 4Gi)
- **CPU**: Configurable (e.g., 1, 2, 4)

### Database Scaling (Firestore)
- **Mode**: Native (automatically scaled)
- **Indexes**: Composite indexes for common queries
- **Read/Write Capacity**: On-demand pricing model

### Frontend Delivery
- **CDN**: Firebase Hosting uses Google Cloud CDN
- **Cache**: Browser caching + CDN edge caching
- **Rewrite Rules**: /api/* routes to Cloud Run backend

---

## Monitoring & Logging

### Backend Logging
```
Logger Config: logger_config.py
├── Handler: Console output
├── Format: JSON for Cloud Logging integration
└── Level: INFO (production) / DEBUG (development)

Cloud Logging Integration:
├── Automatic log ingestion
├── Log Explorer in Google Cloud Console
└── Stackdriver error tracking
```

### Key Metrics to Monitor
- Cloud Run request latency
- Cloud Run error rate
- Firestore read/write operations
- Cloud Storage operations
- Vertex AI API latency

---

## Deployment Instructions

### Prerequisites
1. GCP Project with billing enabled
2. Google Cloud CLI installed
3. Terraform installed
4. GitHub repository access
5. Required APIs enabled

### Deploy via Terraform
```bash
cd infra/environments/dev-infra-example

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -out=tfplan

# Apply configuration
terraform apply tfplan
```

### Environment Variables
Backend services require:
- `PROJECT_ID`: GCP Project ID
- `GENMEDIA_BUCKET`: Cloud Storage bucket name
- `ENVIRONMENT`: dev, staging, or prod
- `FRONTEND_URL`: Frontend domain (production)

---

## Technology Decisions & Rationale

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Frontend Framework | Angular 18 | Enterprise-grade, full-featured framework |
| Backend Framework | FastAPI | High performance, modern Python async |
| Database | Firestore | Flexible NoSQL, built-in auth integration |
| Compute | Cloud Run | Serverless, auto-scaling, cost-effective |
| AI Models | Vertex AI | Unified Google AI platform, production-ready |
| IaC | Terraform | Provider-agnostic, version-controllable |
| Auth | Firebase Auth | Simple to integrate, multi-factor support |
| CI/CD | Cloud Build | Native GCP integration, GitHub connected |
| Code Style | Google Style Guides | Consistency, industry standard |

---

## Appendix: Useful Commands

### Local Development
```bash
# Frontend
cd frontend
npm install
npm start

# Backend
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python main.py

# Docker Compose
docker-compose up --build
```

### Production Deployment
```bash
# Terraform
cd infra/environments/dev-infra-example
terraform apply

# Manual Cloud Run deployment
gcloud run deploy creative-studio \
  --source . \
  --region us-central1 \
  --service-account cs-prod-run@PROJECT_ID.iam.gserviceaccount.com
```

### Useful GCP Commands
```bash
# View Cloud Run logs
gcloud run logs read creative-studio --region=us-central1 --limit=50

# Check Firestore database
gcloud firestore databases list

# View service accounts
gcloud iam service-accounts list

# List Terraform state
terraform state list
```

---

## Document Information

- **Last Updated**: December 2025
- **Status**: Production Ready
- **Maintainers**: Creative Studio Development Team
- **License**: Apache License 2.0
