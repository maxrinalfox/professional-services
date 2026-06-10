# Component Diagrams & Visual Reference

Quick visual reference guide for all components, their relationships, and interactions in Creative Studio.

---

## System Overview

```mermaid
graph TB
    subgraph User["👤 User Layer"]
        Browser["Web Browser"]
        Device["Mobile/Desktop Device"]
    end

    subgraph Frontend["🌐 Frontend - Firebase Hosting"]
        FE["Angular SPA<br/>creative-studio-frontend"]
        FEMods["Components:<br/>Gallery | Images | Videos<br/>VTO | Audio | Templates"]
        Auth["Firebase Auth<br/>Google/Email"]
        FEState["State Management<br/>RxJS Observables"]
    end

    subgraph Backend["⚙️ Backend - Cloud Run"]
        API["FastAPI Application<br/>creative-studio-backend"]
        Routers["Routers:<br/>Images | Videos | Audio<br/>Gallery | VTO | Brand Guidelines"]
        Services["Service Layer:<br/>Imagen | Veo | Gemini<br/>Chirp | Upload | Query"]
        Middleware["Auth Interceptor<br/>CORS | Error Handler"]
    end

    subgraph Database["💾 Data Layer"]
        FS["Firestore Database<br/>(NoSQL)"]
        Collections["Collections:<br/>media_library | users<br/>source_assets | brand_guidelines<br/>media_templates | workspaces"]
        Indexes["Composite Indexes<br/>for Query Optimization"]
        GCS["Cloud Storage<br/>GenMedia Bucket"]
    end

    subgraph AI["🤖 AI Services"]
        VertexAI["Vertex AI Platform"]
        Imagen["Imagen 3.0<br/>Image Generation"]
        Veo["Veo 1.0<br/>Video Generation"]
        Gemini["Gemini 2.0<br/>Multimodal Analysis"]
        Chirp["Chirp 1.0<br/>Audio Generation"]
    end

    subgraph Infrastructure["🏗️ Infrastructure & Security"]
        CloudRun["Cloud Run<br/>Serverless Compute"]
        Firebase["Firebase<br/>Hosting & Auth"]
        IAM["IAM & Service Accounts<br/>cs-env-run | cs-env-trig"]
        Secrets["Secret Manager<br/>API Keys & Credentials"]
        CB["Cloud Build<br/>CI/CD Pipeline"]
    end

    User --> Browser
    Browser -->|HTTPS| Frontend
    Browser -->|Download| GCS

    Frontend --> FE
    FE --> FEMods
    FE --> Auth
    FE --> FEState
    FEState -->|HTTP + Bearer Token| API

    API --> Routers
    Routers --> Services
    Services --> Middleware

    Middleware -->|Verify| Auth
    Middleware -->|Query/Update| FS
    Middleware -->|Upload/Download| GCS
    Services -->|API Calls| VertexAI

    VertexAI --> Imagen
    VertexAI --> Veo
    VertexAI --> Gemini
    VertexAI --> Chirp

    FS --> Collections
    Collections --> Indexes
    GCS -.->|Store Files| GCS

    Infrastructure -->|Provisions| CloudRun
    Infrastructure -->|Provisions| Firebase
    Infrastructure -->|Manages| IAM
    Infrastructure -->|Stores| Secrets
    CB -->|Deploys| CloudRun
    CB -->|Deploys| Firebase

    IAM -->|Grants Permissions| API
    Secrets -->|Provides Credentials| API
```

---

## Frontend Architecture

```mermaid
graph LR
    subgraph App["Application Root"]
        AppComp["AppComponent<br/>(app.component.ts)"]
        Router["Angular Router<br/>(app-routing.module.ts)"]
    end

    subgraph Modules["Feature Modules"]
        Gallery["Gallery Module<br/>• media-gallery.component<br/>• media-detail.component<br/>• gallery.service"]
        Images["Images Module<br/>• imagen.component<br/>• imagen.service"]
        Videos["Videos Module<br/>• veo.component<br/>• veo.service"]
        VTO["VTO Module<br/>• vto.component<br/>• vto.service"]
        Audio["Audio Module<br/>• audio.component<br/>• audio.service"]
        Templates["Templates Module<br/>• fun-templates.component<br/>• template.service"]
        Admin["Admin Module<br/>• admin-layout.component<br/>• admin.service"]
    end

    subgraph Services["Shared Services"]
        AuthSvc["AuthService<br/>Firebase Auth"]
        HTTPSvc["HttpClientService<br/>Backend Communication"]
        LoadingSvc["LoadingService<br/>Loading State"]
        ConfigSvc["ConfigService<br/>App Configuration"]
    end

    subgraph Interceptors["HTTP Interceptors"]
        AuthInt["AuthInterceptor<br/>Adds Bearer Token"]
        ErrorInt["ErrorInterceptor<br/>Error Handling"]
    end

    subgraph Utilities["Utilities"]
        Guards["Route Guards<br/>Auth Protection"]
        UtilFuncs["Utility Functions<br/>Formatting, Validation"]
    end

    AppComp --> Router
    Router --> Modules
    Modules -->|Use| Services
    Services -->|Make Requests| HTTPSvc
    HTTPSvc -->|Pass Through| Interceptors
    Backend["FastAPI Backend"]
    Interceptors -->|Enhance Request| Backend

    Utilities -->|Support| Services
```

---

## Backend Architecture

```mermaid
graph TB
    subgraph Request["Incoming Request"]
        HTTPRequest["HTTP Request<br/>POST /api/images"]
        Headers["Headers:<br/>Authorization: Bearer TOKEN"]
    end

    subgraph Middleware["Middleware Chain"]
        CORS["CORS Middleware<br/>Validate Origins"]
        ErrorHandler["Exception Handler<br/>Catch All Errors"]
    end

    subgraph Auth["Authentication"]
        AuthInt["Auth Interceptor<br/>Verify Token"]
        FirebaseAuth["Firebase Auth<br/>Validate Signature"]
    end

    subgraph Routing["API Routing"]
        ImageRouter["📸 imagen_controller.py<br/>Routes: /api/images/*"]
        VideoRouter["🎬 veo_controller.py<br/>Routes: /api/videos/*"]
        AudioRouter["🔊 audio_controller.py<br/>Routes: /api/audios/*"]
        GalleryRouter["📷 gallery_controller.py<br/>Routes: /api/galleries/*"]
        GeminiRouter["✨ gemini_controller.py<br/>Routes: /api/gemini/*"]
        UserRouter["👤 user_controller.py<br/>Routes: /api/users/*"]
        AssetRouter["📁 source_asset_controller<br/>Routes: /api/source-assets/*"]
        BrandRouter["🎨 brand_guideline_controller<br/>Routes: /api/brand-guidelines/*"]
        TemplateRouter["📋 media_templates_controller<br/>Routes: /api/templates/*"]
        WorkspaceRouter["🏢 workspace_controller<br/>Routes: /api/workspaces/*"]
    end

    subgraph Services["Service Layer"]
        ImageSvc["ImageService<br/>Imagen API Integration"]
        VideoSvc["VideoService<br/>Veo API Integration"]
        AudioSvc["AudioService<br/>Chirp API Integration"]
        GallerySvc["GalleryService<br/>Firestore Queries"]
        GeminiSvc["GeminiService<br/>Gemini API Integration"]
        UserSvc["UserService<br/>User Management"]
        AssetSvc["AssetService<br/>File Operations"]
        BrandSvc["BrandService<br/>PDF Processing"]
        TemplateSvc["TemplateService<br/>Template Management"]
        WorkspaceSvc["WorkspaceService<br/>Collaboration"]
    end

    subgraph Repository["Repository/Data Access"]
        FSRepo["Firestore Repository<br/>CRUD Operations"]
        GCSRepo["Cloud Storage Repository<br/>File Operations"]
    end

    subgraph External["External Services"]
        VertexAI["Vertex AI<br/>Model APIs"]
        Firestore["Firestore<br/>Database"]
        GCS["Cloud Storage<br/>File Storage"]
    end

    HTTPRequest --> CORS
    CORS --> ErrorHandler
    ErrorHandler --> Auth
    Auth --> FirebaseAuth
    FirebaseAuth -->|If Valid| Routing

    Routing -->|POST /api/images| ImageRouter
    Routing -->|POST /api/videos| VideoRouter
    Routing -->|POST /api/audios| AudioRouter
    Routing -->|GET /api/galleries| GalleryRouter
    Routing -->|POST /api/gemini| GeminiRouter
    Routing -->|GET /api/users| UserRouter
    Routing -->|POST /api/source-assets| AssetRouter
    Routing -->|POST /api/brand-guidelines| BrandRouter
    Routing -->|GET /api/templates| TemplateRouter
    Routing -->|GET /api/workspaces| WorkspaceRouter

    ImageRouter --> ImageSvc
    VideoRouter --> VideoSvc
    AudioRouter --> AudioSvc
    GalleryRouter --> GallerySvc
    GeminiRouter --> GeminiSvc
    UserRouter --> UserSvc
    AssetRouter --> AssetSvc
    BrandRouter --> BrandSvc
    TemplateRouter --> TemplateSvc
    WorkspaceRouter --> WorkspaceSvc

    ImageSvc --> Repository
    VideoSvc --> Repository
    AudioSvc --> Repository
    GallerySvc --> Repository
    GeminiSvc --> Repository
    UserSvc --> Repository
    AssetSvc --> Repository
    BrandSvc --> Repository
    TemplateSvc --> Repository
    WorkspaceSvc --> Repository

    Repository -->|Query/Update| Firestore
    Repository -->|Upload/Download| GCS
    ImageSvc -->|API Call| VertexAI
    VideoSvc -->|API Call| VertexAI
    AudioSvc -->|API Call| VertexAI
    GeminiSvc -->|API Call| VertexAI
```

---

## Data Model Relationships

```mermaid
erDiagram
    USERS ||--o{ MEDIA_LIBRARY : creates
    USERS ||--o{ SOURCE_ASSETS : uploads
    USERS ||--o{ WORKSPACES : owns
    WORKSPACES ||--o{ MEDIA_LIBRARY : contains
    WORKSPACES ||--o{ SOURCE_ASSETS : contains
    WORKSPACES ||--o{ BRAND_GUIDELINES : has
    WORKSPACES ||--o{ MEDIA_TEMPLATES : has
    MEDIA_LIBRARY ||--o{ SOURCE_ASSETS : uses

    USERS {
        string id PK
        string email
        string role
        string workspace_id FK
        timestamp created_at
    }

    WORKSPACES {
        string id PK
        string name
        string owner_id FK
        array members
        timestamp created_at
    }

    MEDIA_LIBRARY {
        string id PK
        string workspace_id FK
        string user_email
        string model
        string mime_type
        string status
        string prompt
        string gcs_uri
        array source_asset_ids
        timestamp created_at
    }

    SOURCE_ASSETS {
        string id PK
        string workspace_id FK
        string user_id FK
        string asset_type
        string mime_type
        string file_hash
        string gcs_uri
        timestamp created_at
    }

    BRAND_GUIDELINES {
        string id PK
        string workspace_id FK
        string pdf_uri
        string extracted_text
        timestamp created_at
    }

    MEDIA_TEMPLATES {
        string id PK
        string workspace_id FK
        string name
        string prompt
        string model
        string category
        timestamp created_at
    }
```

---

## Service Account Permissions Map

```mermaid
graph TB
    Project["GCP Project"]

    subgraph RunSA["cs-prod-run<br/>(Runtime)"]
        RunRole1["aiplatform.user<br/>└─ Vertex AI APIs"]
        RunRole2["storage.objectUser<br/>└─ GenMedia Bucket"]
        RunRole3["firestore.admin<br/>└─ Firestore DB"]
        RunRole4["secretmanager.secretAccessor<br/>└─ Secrets"]
    end

    subgraph TrigSA["cs-prod-trig<br/>(Cloud Build)"]
        TrigRole1["artifactregistry.writer<br/>└─ Push Images"]
        TrigRole2["run.admin<br/>└─ Deploy Services"]
        TrigRole3["cloudbuild.builds.editor<br/>└─ Manage Builds"]
        TrigRole4["iam.serviceAccountUser<br/>└─ Impersonate SAs"]
    end

    subgraph ReadSA["cs-prod-read<br/>(Optional)"]
        ReadRole1["storage.objectViewer<br/>└─ Read Bucket"]
    end

    Project --> RunSA
    Project --> TrigSA
    Project --> ReadSA

    Services1["Imagen API<br/>Veo API<br/>Gemini API<br/>Chirp API"]
    Services2["Generated Media<br/>Source Files"]
    Services3["Collections<br/>Documents<br/>Indexes"]
    Services4["API Keys<br/>Credentials"]
    Services5["Artifact Registry<br/>Docker Images"]
    Services6["Cloud Run<br/>Services"]
    Services7["Build Jobs<br/>Logs"]
    Services8["Presigned URLs<br/>Media Access"]

    RunSA -->|Uses| Services1
    RunSA -->|Reads/Writes| Services2
    RunSA -->|Queries/Updates| Services3
    RunSA -->|Accesses| Services4

    TrigSA -->|Pushes to| Services5
    TrigSA -->|Deploys to| Services6
    TrigSA -->|Manages| Services7
    TrigSA -->|Runs as| RunSA

    ReadSA -->|Generates URLs| Services8
```

---

## Deployment Pipeline

```mermaid
graph LR
    GitHub["GitHub<br/>Repository"]
    Webhook["Webhook Event<br/>Push to main"]
    CloudBuild["Cloud Build<br/>Trigger"]

    subgraph BackendPipeline["Backend Pipeline"]
        FetchBE["1. Fetch Code"]
        BuildBE["2. Build Image"]
        PushBE["3. Push to AR"]
        DeployBE["4. Deploy CR"]
        VerifyBE["5. Health Check"]
    end

    subgraph FrontendPipeline["Frontend Pipeline"]
        FetchFE["1. Fetch Code"]
        InstallFE["2. npm install"]
        BuildFE["3. npm build"]
        DeployFE["4. Firebase Deploy"]
        VerifyFE["5. Health Check"]
    end

    GitHub -->|Push| Webhook
    Webhook -->|Triggers| CloudBuild

    CloudBuild -->|Path: backend/**| BackendPipeline
    CloudBuild -->|Path: frontend/**| FrontendPipeline

    FetchBE --> BuildBE
    BuildBE --> PushBE
    PushBE --> DeployBE
    DeployBE --> VerifyBE

    FetchFE --> InstallFE
    InstallFE --> BuildFE
    BuildFE --> DeployFE
    DeployFE --> VerifyFE

    TrigSANode["cs-prod-trig SA"]
    RunSANode["cs-prod-run SA"]

    BackendPipeline -->|Runs as| TrigSANode
    FrontendPipeline -->|Runs as| TrigSANode

    DeployBE -->|Runs with| RunSANode
    DeployFE -->|Runs with| RunSANode
```

---

## Request/Response Lifecycle

```mermaid
sequenceDiagram
    participant Browser
    participant FE as Frontend
    participant Interceptor as Auth Interceptor
    participant API as Backend API
    participant Auth as Firebase Auth
    participant Service as Service Layer
    participant DB as Firestore
    participant AI as Vertex AI
    participant Response

    Browser->>FE: 1. User Action
    FE->>Auth: 2. Get ID Token
    Auth-->>FE: 3. Token

    FE->>Interceptor: 4. HTTP Request
    Interceptor->>Interceptor: 5. Add Bearer Token
    Interceptor->>API: 6. Request + Token

    API->>API: 7. Parse Request
    API->>Auth: 8. Verify Token
    Auth-->>API: 9. Token Valid + Claims

    API->>Service: 10. Call Service Method
    Service->>DB: 11. Query Data
    DB-->>Service: 12. Data
    Service->>AI: 13. API Call
    AI-->>Service: 14. Result
    Service->>DB: 15. Store Result
    DB-->>Service: 16. Stored

    Service-->>API: 17. Return Result
    API-->>Interceptor: 18. Response
    Interceptor-->>FE: 19. Response
    FE-->>Browser: 20. Update UI
    Browser-->>Browser: 21. Display Result
```

---

## Network Communication Map

```mermaid
graph TB
    subgraph EdgeNetwork["User's Network"]
        Browser["🌐 User Browser"]
    end

    subgraph GCPNetwork["Google Cloud Platform"]
        FE["Firebase<br/>Hosting<br/>Global CDN"]
        CloudRun["Cloud Run<br/>Backend<br/>us-central1"]
        FS["Firestore<br/>Database"]
        GCS["Cloud Storage<br/>Bucket"]
        VertexAI["Vertex AI<br/>APIs"]
    end

    Browser -->|1. HTTPS<br/>GET /| FE
    Browser -->|2. HTTPS<br/>Static Assets| FE
    FE -->|3. HTTPS<br/>Rewrite /api/| CloudRun

    CloudRun -->|4. Internal<br/>Firestore SDK| FS
    CloudRun -->|5. Internal<br/>Storage API| GCS
    CloudRun -->|6. HTTPS<br/>Vertex AI API| VertexAI

    VertexAI -->|7. HTTPS<br/>Models Response| CloudRun
    CloudRun -->|8. Response<br/>JSON| FE
    FE -->|9. Response<br/>JSON| Browser

    Browser -->|10. HTTPS<br/>Download| GCS
```

**Note**: All GCP services are isolated in the same VPC/Region for low latency.

---

## Security Boundaries

```mermaid
graph TB
    Internet["☁️ Internet/Public"]
    AuthBoundary["🔐 Authentication Boundary<br/>Firebase Auth"]
    AppBoundary["🛡️ Application Boundary<br/>Cloud Run"]
    DataBoundary["🔒 Data Boundary<br/>Firestore/Storage"]

    Browser["Browser"]
    Frontend["Firebase<br/>Hosting"]
    Backend["FastAPI<br/>Cloud Run"]
    DB["Firestore"]
    Storage["Cloud Storage"]

    Internet -->|HTTPS Only| Frontend
    Frontend -->|OIDC Token| AuthBoundary
    AuthBoundary -->|Token Valid?| AppBoundary

    AppBoundary -->|REST + Token| Backend
    Backend -->|Service Account| DataBoundary
    DataBoundary -->|Authenticated| DB
    DataBoundary -->|Authenticated| Storage
```

**Security Notes**:
- **Authentication Boundary**: All requests must have valid Firebase token
- **Data Boundary**: Direct access only via authenticated service accounts

---

## Monitoring & Observability

```mermaid
graph LR
    App["Creative Studio<br/>Application"]
    Logging["Cloud Logging<br/>Centralized Logs"]
    Metrics["Cloud Monitoring<br/>Metrics & Alerts"]
    Tracing["Cloud Trace<br/>Request Tracing"]

    App -->|Log Events| Logging
    App -->|Metrics| Metrics
    App -->|Traces| Tracing

    Dashboard["Google Cloud<br/>Console Dashboard"]
    PagerDuty["Alerting System"]
    Team["Engineering Team"]
    Analysis["Analytics & Reports"]

    Logging -->|Error Analysis| Dashboard
    Metrics -->|Performance Data| Dashboard
    Tracing -->|Request Timeline| Dashboard

    Dashboard -->|Alerts| PagerDuty
    PagerDuty -->|Notify| Team

    Logging -->|Historical Data| Analysis
```

---

## Scaling Architecture

```mermaid
graph TB
    Users["👥 Users"]

    subgraph LoadBalancing["Load Distribution"]
        CDN["Firebase CDN<br/>Global Edge Locations"]
    end

    subgraph AutoScale["Auto-Scaling Layer"]
        LB["Cloud Run<br/>Load Balancer"]
        Instances["Service Instances<br/>Min: 1<br/>Max: Auto"]
    end

    subgraph Database["Data Layer"]
        FS["Firestore<br/>(On-Demand Pricing)"]
        Cache["Cloud Memorystore<br/>(Optional)"]
    end

    Users -->|HTTPS| CDN
    CDN -->|Route| LB
    LB -->|Distribute| Instances

    Instances -->|Query| FS
    Instances -->|Cache| Cache
    Cache -->|Miss| FS
```

**Scaling Details**:
- **Service Instances**: Scales from 1 to 100s of instances based on traffic
- **Firestore**: Scales automatically based on read/write operations

---

## Disaster Recovery

```mermaid
graph TB
    subgraph PrimaryRegion["Primary Region<br/>us-central1"]
        PrimBE["Cloud Run<br/>Backend"]
        PrimFE["Firebase<br/>Hosting"]
        PrimDB["Firestore<br/>Database"]
        PrimGCS["Cloud Storage<br/>Bucket"]
    end

    subgraph Backup["Backup & Recovery"]
        FSBackup["Firestore Backups<br/>Daily Automated"]
        GCSBackup["Cloud Storage<br/>Versioning"]
        Replication["Multi-Region<br/>Replication"]
    end

    subgraph Monitoring["Monitoring & Alerts"]
        HealthCheck["Health Checks<br/>5 min interval"]
        Alerts["Alert Policies<br/>Automated Notifications"]
    end

    PrimaryRegion -->|Backup| Backup
    PrimaryRegion -->|Monitor| Monitoring

    Recovery["Automatic Failover<br/>Manual Restoration"]

    Monitoring -->|Detects Issue| Alerts
    Alerts -->|Triggers| Recovery

    Backup -->|Restore if Needed| PrimaryRegion
```

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Audience**: Architects, System Designers, DevOps
- **License**: Apache License 2.0
