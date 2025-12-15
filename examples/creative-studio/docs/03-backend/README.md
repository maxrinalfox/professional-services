# Backend Development

Backend implementation guides, API reference, and database patterns.

## 📖 Guides in This Section

### [SERVICES_AND_ORM.md](SERVICES_AND_ORM.md)
**Service layer architecture and SQLAlchemy ORM**

- Service layer pattern and organization
- FastAPI route handlers and dependency injection
- SQLAlchemy AsyncORM configuration
- Cloud SQL Python Connector setup
- Database connection lifecycle management
- ORM model definitions (User, Workspace, MediaItem, etc.)
- Async database access patterns
- Alembic migrations and schema versioning
- Query examples and best practices
- Error handling in services
- Caching strategies and optimization

**For:** Backend developers, full-stack developers

---

### [API_ENDPOINTS.md](API_ENDPOINTS.md)
**Complete REST API reference**

- All 20+ API endpoints documented
- Request/response models and examples
- Pydantic DTOs and validation
- HTTP status codes and error handling
- Authentication headers and token handling
- Pagination and filtering
- File upload specifications
- Rate limiting and quotas
- Query parameters and path parameters
- Optional vs required fields
- Enum values and constraints
- Timestamp formats (ISO 8601)

**For:** Frontend developers, API consumers, integrators

---

### [AUTHENTICATION.md](AUTHENTICATION.md)
**Authentication and authorization implementation**

- Firebase Authentication integration
- OAuth2 token flow (Bearer tokens)
- JWT token validation process
- Token refresh and expiration
- Just-in-Time (JIT) user provisioning
- Firebase Admin SDK setup
- Role-based access control (RBAC)
- Admin, Editor, Viewer role definitions
- Workspace-level permissions enforcement
- Custom claims and user metadata
- Token security best practices
- Logout and session termination

**For:** Backend developers, security engineers, full-stack developers

---

## 🛠️ Quick Setup

### 1. Install Dependencies
```bash
cd backend
pip install -r requirements.txt  # Or: uv pip install -r requirements.txt
```

### 2. Configure Environment
```bash
cp .env.template .env
# Edit .env with:
# - PROJECT_ID: Your GCP project
# - GOOGLE_TOKEN_AUDIENCE: OAuth Client ID
# - INSTANCE_CONNECTION_NAME: Cloud SQL connection
# - DB_NAME, DB_USER, DB_PASS: Database credentials
```

### 3. Initialize Database
```bash
# Apply migrations
alembic upgrade head

# Or run locally with Docker
docker-compose up postgres
```

### 4. Run Backend
```bash
# Development (with auto-reload)
uvicorn src.main:app --reload

# Or with Docker
docker-compose up backend
```

**Backend URL:** `http://localhost:8080/api`

---

## 📊 Database Schema

### Core Tables

**users**
```
- id (PK)
- email (UNIQUE)
- roles[] (array of roles)
- name, picture
- created_at, updated_at
```

**workspaces**
```
- id (PK)
- name, owner_id (FK: users)
- scope (personal|organization)
- created_at, updated_at
```

**workspace_members**
```
- workspace_id (FK), user_id (FK) - Composite PK
- role (admin|editor|viewer)
```

**media_items**
```
- id (PK)
- workspace_id, user_id (FKs)
- model (imagen, veo, chirp, gemini)
- status (pending|success|failed)
- prompt, gcs_uris[], thumbnail_uris[]
- generation_time, error_message
- created_from_template_id (FK)
- created_at, updated_at
```

**media_templates**
```
- id (PK)
- name, description, mime_type
- generation_parameters (JSONB)
- gcs_uris[], tags[]
- created_at, updated_at
```

**source_assets**
```
- id (PK)
- workspace_id, user_id (FKs)
- gcs_uri, original_filename
- asset_type (image|video|audio|document)
- file_hash, scope (personal|workspace)
- created_at, updated_at
```

**brand_guidelines**
```
- id (PK)
- workspace_id (FK), logo_asset_id (FK)
- name, status, error_message
- guideline_text, color_palette[]
- tone_of_voice_summary, visual_style_summary
- created_at, updated_at
```

See [SERVICES_AND_ORM.md#database-schema](SERVICES_AND_ORM.md#database-schema) for full details.

---

## 🔑 Key Concepts

### Service Layer Pattern
```
Controller (HTTP endpoint)
    ↓
Service (Business logic)
    ↓
Repository (Data access)
    ↓
Database / Cache
```

### SQLAlchemy AsyncORM
```python
async with AsyncSessionLocal() as session:
    # Query example
    user = await session.execute(
        select(User).where(User.email == "user@example.com")
    )
    user = user.scalar_one_or_none()
```

### Database Migrations
```bash
# Create migration
alembic revision --autogenerate -m "Add new table"

# Review migration file before applying
# Apply migration
alembic upgrade head
```

---

## 🔐 Authentication Flow

```
1. Frontend: User logs in with Google
2. Firebase: Returns ID token (JWT)
3. Frontend: Sends token in Authorization header
4. Backend: Validates token with Firebase
5. Backend: Creates/updates user in PostgreSQL (JIT)
6. Backend: Checks workspace permissions in PostgreSQL
7. Backend: Executes operation
8. Backend: Returns response
```

---

## 📝 Common Development Tasks

### Adding a New API Endpoint
1. Create Pydantic DTOs in `src/*/schema/`
2. Implement logic in `src/*/services/`
3. Create route in `src/*/routers/`
4. Register route in `main.py`
5. Document in API_ENDPOINTS.md

### Adding a New Database Table
1. Create model in `src/*/schema/model.py`
2. Create migration: `alembic revision --autogenerate`
3. Review and adjust migration
4. Apply: `alembic upgrade head`
5. Update service layer to use new model

### Querying the Database
1. Import model and select from sqlalchemy
2. Use AsyncSessionLocal context manager
3. Execute query with await
4. Handle None/empty results
5. See examples in SERVICES_AND_ORM.md

---

## 🚀 Next Steps

1. **Setup backend:** Follow Quick Setup above
2. **Understand services:** Read [SERVICES_AND_ORM.md](SERVICES_AND_ORM.md)
3. **Learn API:** Check [API_ENDPOINTS.md](API_ENDPOINTS.md)
4. **Understand auth:** Review [AUTHENTICATION.md](AUTHENTICATION.md)
5. **Full architecture:** [02-architecture/SYSTEM_DESIGN.md](../02-architecture/SYSTEM_DESIGN.md)
6. **Database details:** [06-infrastructure/CLOUD_SQL.md](../06-infrastructure/CLOUD_SQL.md) (create this file)

---

## 📚 Learn More

- **Data flow:** [02-architecture/DATA_FLOW.md](../02-architecture/DATA_FLOW.md)
- **Testing:** [08-testing/TESTING_STRATEGY.md](../08-testing/TESTING_STRATEGY.md)
- **Deployment:** [06-infrastructure/CLOUD_RUN.md](../06-infrastructure/CLOUD_RUN.md) (create this file)
- **Environment setup:** [01-getting-started/ENVIRONMENTS.md](../01-getting-started/ENVIRONMENTS.md)
