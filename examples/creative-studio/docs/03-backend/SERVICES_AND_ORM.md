# Backend Services Architecture & Implementation

## Overview

The Creative Studio backend uses a service-oriented architecture where business logic is isolated into focused, reusable services. Each service handles a specific domain (images, videos, users, etc.) and interacts with repositories for data access.

**Service Layer Pattern**:
```
Controller (HTTP endpoints)
    ↓
Service (Business logic)
    ↓
Repository (Data access - PostgreSQL + Firestore)
    ↓
Cloud SQL PostgreSQL / Firestore / GCS (External storage)
```

**Data Access Layer**:
- **PostgreSQL**: Structured relational data via SQLAlchemy ORM
- **Firestore**: Real-time document queries
- **Cloud Storage**: Binary file operations

---

## Table of Contents

1. [Service Architecture](#service-architecture)
2. [ImageService](#imageservice)
3. [VideoService](#videoservice)
4. [AudioService](#audioservice)
5. [GalleryService](#galleryservice)
6. [UserService](#userservice)
7. [WorkspaceService](#workspaceservice)
8. [SourceAssetService](#sourceassetservice)
9. [BrandGuidelineService](#brandguidelineservice)
10. [MediaTemplateService](#mediatemplateservice)
11. [GeminiService](#geminiservice)
12. [Storage & Repository Services](#storage--repository-services)
13. [Error Handling](#error-handling)
14. [Async Operations](#async-operations)
15. [Caching Strategies](#caching-strategies)

---

## Service Architecture

### Directory Structure

```
backend/src/
├── services/
│   ├── image_service.py          # Image generation with Imagen
│   ├── video_service.py          # Video generation with Veo
│   ├── audio_service.py          # Audio generation with Chirp
│   ├── gallery_service.py        # Media library queries
│   ├── user_service.py           # User management
│   ├── workspace_service.py      # Workspace collaboration
│   ├── source_asset_service.py   # Asset upload management
│   ├── brand_guideline_service.py # PDF processing
│   ├── media_template_service.py # Template management
│   └── gemini_service.py         # Multimodal analysis
├── repositories/
│   ├── firestore_repository.py   # Firestore CRUD
│   └── storage_repository.py     # Cloud Storage operations
├── common/
│   ├── storage_service.py        # GCS wrapper
│   └── media_utils.py            # Utility functions
└── models/
    └── schemas.py               # Pydantic models
```

### Service Initialization

**File**: `backend/src/config/service_config.py`

```python
from src.services.image_service import ImageService
from src.services.video_service import VideoService
from src.services.audio_service import AudioService
from src.services.gallery_service import GalleryService
from src.services.user_service import UserService
from src.services.workspace_service import WorkspaceService
from src.repositories.firestore_repository import FirestoreRepository
from src.common.storage_service import StorageService

class ServiceContainer:
    """Central service initialization and dependency injection"""

    def __init__(self):
        # Core repositories
        self.firestore = FirestoreRepository()
        self.storage = StorageService()

        # Domain services
        self.image_service = ImageService(
            firestore=self.firestore,
            storage=self.storage,
        )
        self.video_service = VideoService(
            firestore=self.firestore,
            storage=self.storage,
        )
        self.audio_service = AudioService(
            firestore=self.firestore,
            storage=self.storage,
        )
        self.gallery_service = GalleryService(firestore=self.firestore)
        self.user_service = UserService(firestore=self.firestore)
        self.workspace_service = WorkspaceService(firestore=self.firestore)

# Singleton instance
_service_container = ServiceContainer()

def get_services():
    return _service_container
```

---

## Database & ORM (Cloud SQL PostgreSQL)

### Overview

The backend uses **SQLAlchemy AsyncORM** to interact with Cloud SQL PostgreSQL. This provides:
- Async/await support for non-blocking database operations
- Automatic connection pooling via Cloud SQL Python Connector
- Type-safe ORM models with Pydantic integration
- Automatic schema migrations via Alembic

### Database Connection

**File**: `backend/src/database.py`

```python
from google.cloud.sql.connector import Connector, IPTypes
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

class DatabaseConnector:
    """Manages Cloud SQL connection lifecycle"""
    _instance = None
    _connector = None

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def get_connector(self) -> Connector:
        if self._connector is None:
            import asyncio
            self._connector = Connector(loop=asyncio.get_running_loop())
        return self._connector

    async def cleanup(self):
        if self._connector:
            await self._connector.close_async()
            self._connector = None

async def get_connection():
    """Create async connection to Cloud SQL"""
    connector = DatabaseConnector.get_instance().get_connector()

    conn = await connector.connect_async(
        config_service.INSTANCE_CONNECTION_NAME,  # "project:region:instance"
        "asyncpg",
        user=config_service.DB_USER,
        password=config_service.DB_PASS,
        db=config_service.DB_NAME,
        ip_type=IPTypes.PUBLIC,
    )
    return conn

# Create async engine
engine = create_async_engine(
    "postgresql+asyncpg://",
    async_creator=get_connection,
    echo=config_service.LOG_LEVEL == "DEBUG",
)

# Session factory
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)
```

### ORM Models

Models are defined with SQLAlchemy declarative syntax in `backend/src/*/schema/*.py`:

```python
# backend/src/users/user_model.py
from sqlalchemy import Column, Integer, String, DateTime, ARRAY
from sqlalchemy.orm import relationship
from src.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String, unique=True, nullable=False, index=True)
    roles = Column(ARRAY(String), nullable=False)  # ["admin", "editor", "viewer"]
    name = Column(String, nullable=False)
    picture = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=text('now()'))
    updated_at = Column(DateTime(timezone=True), server_default=text('now()'))

    # Relationships
    workspaces = relationship("Workspace", foreign_keys="Workspace.owner_id")
    workspace_members = relationship("WorkspaceMember")
```

### Database Access Pattern

Services use async context managers to access the database:

```python
from src.database import AsyncSessionLocal
from src.users.user_model import User

async def get_user_by_email(email: str) -> User:
    """Get user from PostgreSQL"""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(User).where(User.email == email)
        )
        return result.scalar_one_or_none()

async def create_user(email: str, name: str, picture: str) -> User:
    """Create user in PostgreSQL"""
    async with AsyncSessionLocal() as session:
        user = User(
            email=email,
            name=name,
            picture=picture,
            roles=["viewer"]
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)
        return user

async def get_workspace_members(workspace_id: int):
    """Get workspace members with roles"""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(WorkspaceMember)
            .join(User)
            .where(WorkspaceMember.workspace_id == workspace_id)
            .order_by(User.email)
        )
        return result.scalars().all()
```

### Database Migrations (Alembic)

Track schema changes with Alembic migrations:

```bash
# Create a new migration
alembic revision --autogenerate -m "Add new column"

# Apply pending migrations (auto-runs at startup)
alembic upgrade head

# View migration history
alembic history --verbose
```

**Migration Example** (`backend/alembic/versions/6591e10bbab7_initial_schema.py`):
```python
def upgrade() -> None:
    op.create_table('media_items',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('workspace_id', sa.Integer(), nullable=False),
        sa.Column('model', sa.String(), nullable=False),
        sa.Column('status', sa.String(), nullable=False),
        sa.ForeignKeyConstraint(['workspace_id'], ['workspaces.id']),
        sa.PrimaryKeyConstraint('id')
    )
```

### Key Tables

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| **users** | User profiles | email, roles, name, picture |
| **workspaces** | Collaboration spaces | name, owner_id, scope |
| **workspace_members** | User-workspace relationships | workspace_id, user_id, role |
| **media_items** | Generation history | workspace_id, model, status, gcs_uris |
| **media_templates** | Prompt templates | name, mime_type, generation_parameters |
| **source_assets** | Uploaded files | workspace_id, gcs_uri, asset_type |
| **brand_guidelines** | Brand PDFs | workspace_id, guideline_text, color_palette |

---

## ImageService

### Purpose
Handles image generation using Google's Imagen 3.0 model with support for prompts, styles, sizes, and optional brand guideline application.

### Key Methods

#### `generate_image()`

```python
async def generate_image(
    self,
    prompt: str,
    user_email: str,
    style: str = "photorealistic",
    size: str = "1024x1024",
    guidance_scale: float = 7.5,
    negative_prompt: str = None,
    seed: int = None,
    apply_brand_guidelines: bool = False,
    workspace_id: str = None,
) -> ImageResponse:
    """
    Generate image with Imagen 3.0

    Args:
        prompt: Image description (1-1000 chars)
        user_email: User email for ownership
        style: One of: photorealistic, watercolor, oil-painting, sketch, digital-art
        size: One of: 512x512, 768x768, 1024x1024, 1024x576, 576x1024
        guidance_scale: 1.0-20.0 (higher = closer to prompt)
        negative_prompt: What to avoid in image
        seed: For reproducible results
        apply_brand_guidelines: Apply workspace brand guidelines
        workspace_id: Workspace context

    Returns:
        ImageResponse with generated image URI

    Raises:
        ValueError: Invalid input
        PermissionError: Unauthorized workspace
        VertexAIError: Imagen API error
    """
```

**Flow**:
1. Validate input (prompt length, style, size)
2. Check user has workspace access (if workspace specified)
3. Optionally apply brand guidelines to prompt
4. Call Vertex AI Imagen API
5. Download generated image from temporary URI
6. Upload to GenMedia bucket
7. Create media_library document in Firestore
8. Return response with signed URL

**Example Implementation**:

```python
async def generate_image(self, prompt: str, user_email: str, **kwargs):
    # Validate
    if not prompt or len(prompt) > 1000:
        raise ValueError("Prompt must be 1-1000 characters")

    if kwargs.get('style') not in VALID_STYLES:
        raise ValueError(f"Invalid style: {kwargs['style']}")

    # Apply brand guidelines if requested
    if kwargs.get('apply_brand_guidelines'):
        brand_guidelines = await self.firestore.get_document(
            'brand_guidelines',
            kwargs['workspace_id']
        )
        if brand_guidelines:
            # Rewrite prompt using Gemini
            prompt = await self._rewrite_prompt_for_brand(
                prompt,
                brand_guidelines['extracted_text']
            )

    # Call Vertex AI
    image_uri = await self._call_imagen_api(prompt, **kwargs)

    # Download and re-upload
    image_data = await self.storage.download(image_uri)
    gcs_uri = await self.storage.upload(
        data=image_data,
        bucket='genMedia',
        path=f'media/images/{uuid4()}.png',
    )

    # Save to Firestore
    media_doc = {
        'user_email': user_email,
        'model': 'imagen-3-fast',
        'prompt': prompt,
        'status': 'success',
        'gcs_uri': gcs_uri,
        'mime_type': 'image/png',
        'created_at': datetime.utcnow().isoformat(),
    }

    doc_id = await self.firestore.create_document('media_library', media_doc)

    return ImageResponse(
        id=doc_id,
        gcs_uri=gcs_uri,
        status='success',
    )
```

#### `get_image()`

```python
async def get_image(self, image_id: str, user_email: str) -> ImageResponse:
    """
    Get image details and generate signed URL

    Args:
        image_id: Document ID in media_library
        user_email: Current user email (for permission check)

    Returns:
        ImageResponse with metadata and signed URL

    Raises:
        PermissionError: User doesn't own image
        NotFoundError: Image doesn't exist
    """
```

#### `list_images()`

```python
async def list_images(
    self,
    user_email: str,
    page_size: int = 20,
    start_after: str = None,
) -> List[ImageResponse]:
    """
    List user's images with pagination

    Queries: media_library WHERE user_email = X ORDER BY created_at DESC
    """
```

#### `delete_image()`

```python
async def delete_image(self, image_id: str, user_email: str) -> None:
    """
    Delete image and associated GCS file

    Args:
        image_id: Document ID
        user_email: Owner verification

    Raises:
        PermissionError: User doesn't own image
    """
```

### Error Handling

```python
class ImageServiceError(Exception):
    """Base exception for image service"""
    pass

class InvalidPromptError(ImageServiceError):
    """Prompt validation failed"""
    pass

class ImageGenerationError(ImageServiceError):
    """Imagen API call failed"""
    pass

# Usage in controller:
try:
    result = await image_service.generate_image(prompt, user_email)
except InvalidPromptError as e:
    raise HTTPException(status_code=400, detail=str(e))
except ImageGenerationError as e:
    logger.error(f"Generation failed: {e}")
    raise HTTPException(status_code=503, detail="Image generation service unavailable")
```

---

## VideoService

### Purpose
Handles asynchronous video generation using Veo 2.0 model. Videos are long-running operations requiring polling for completion status.

### Key Methods

#### `generate_video()`

```python
async def generate_video(
    self,
    prompt: str,
    user_email: str,
    duration: int = 5,
    style: str = "cinematic",
    aspect_ratio: str = "16:9",
    fps: int = 24,
    seed: int = None,
    workspace_id: str = None,
) -> VideoGenerationResponse:
    """
    Start asynchronous video generation

    Args:
        prompt: Video description (1-2000 chars)
        user_email: User email
        duration: 1-60 seconds
        style: cinematic, animated, documentary
        aspect_ratio: 16:9, 9:16, 1:1
        fps: 24 or 30

    Returns:
        VideoGenerationResponse with request ID and operation ID

    Note:
        - Returns immediately with status=pending
        - Frontend must poll get_video_status() for completion
        - Processing takes 1-10 minutes depending on duration
    """
```

**Async Flow**:
```
1. Create media_library doc with status=pending
2. Call Veo API (async, returns operation_id)
3. Store operation_id in Firestore
4. Return immediately with request ID
5. Frontend polls get_video_status() periodically
6. When complete, download and store in GenMedia bucket
7. Update Firestore with status=success
```

#### `get_video_status()`

```python
async def get_video_status(
    self,
    video_id: str,
    user_email: str,
) -> VideoStatusResponse:
    """
    Get current status of video generation

    Returns:
        VideoStatusResponse with:
        - status: pending, success, failed
        - progress_percentage: 0-100 (if available from API)
        - gcs_uri: Available when status=success
        - signed_url: Pre-signed download URL
        - completed_at: Timestamp when finished
    """
```

**Implementation**:

```python
async def get_video_status(self, video_id: str, user_email: str):
    # Get document
    doc = await self.firestore.get_document('media_library', video_id)

    if doc['user_email'] != user_email:
        raise PermissionError("Not your video")

    # If already complete, return cached result
    if doc['status'] == 'success':
        return VideoStatusResponse(
            id=video_id,
            status='success',
            gcs_uri=doc['gcs_uri'],
            signed_url=await self.storage.generate_signed_url(doc['gcs_uri']),
        )

    # If pending, check operation status
    if doc['status'] == 'pending':
        operation_id = doc['operation_id']
        operation_status = await self._check_operation_status(operation_id)

        if operation_status['done']:
            # Complete the operation
            video_uri = operation_status['result']['output_uri']
            await self._finalize_video(video_id, video_uri)
        else:
            # Still processing
            progress = operation_status.get('metadata', {}).get('progress_percentage', 0)
            return VideoStatusResponse(
                id=video_id,
                status='pending',
                progress_percentage=progress,
            )

    return VideoStatusResponse(id=video_id, status=doc['status'])
```

#### `_finalize_video()`

```python
async def _finalize_video(self, video_id: str, video_uri: str):
    """
    Called when video generation completes:
    1. Download from temporary URI
    2. Upload to GenMedia bucket
    3. Update Firestore
    """
```

### Error Handling

Video-specific errors:
- Long operation timeouts (>2 hours)
- Operation failures (Veo API error)
- Polling failures (network issues)

---

## AudioService

### Purpose
Handles audio generation using Google's Chirp 1.0 model for music and sound generation.

### Key Methods

#### `generate_audio()`

```python
async def generate_audio(
    self,
    prompt: str,
    user_email: str,
    duration: int = 30,
    style: str = "ambient",
    workspace_id: str = None,
) -> AudioResponse:
    """
    Generate audio with Chirp 1.0

    Args:
        prompt: Audio description
        duration: 5-120 seconds
        style: ambient, cinematic, electronic, acoustic

    Returns:
        AudioResponse with generated audio URI
    """
```

**Implementation**:
Similar to ImageService but:
- Calls Chirp API instead of Imagen
- Returns audio/mpeg MIME type
- Duration parameter instead of size

#### `get_audio()`

```python
async def get_audio(self, audio_id: str, user_email: str) -> AudioResponse:
    """Get audio details with signed download URL"""
```

#### `list_audios()`

```python
async def list_audios(
    self,
    user_email: str,
    page_size: int = 20,
    start_after: str = None,
) -> List[AudioResponse]:
    """List user's audio files"""
```

---

## GalleryService

### Purpose
Handles gallery/media library queries, filtering, searching, and media management.

### Key Methods

#### `get_gallery()`

```python
async def get_gallery(
    self,
    user_email: str,
    page_size: int = 20,
    start_after: str = None,
    filters: dict = None,
) -> List[MediaItem]:
    """
    Get user's media library with optional filtering

    Args:
        user_email: User email
        filters: {
            'mime_type': 'image/png',
            'model': 'imagen-3-fast',
            'status': 'success',
            'date_range': (start, end),
        }

    Returns:
        Paginated list of media items

    Query:
        SELECT * FROM media_library
        WHERE user_email = X
        AND mime_type = Y (if filter)
        AND model = Z (if filter)
        ORDER BY created_at DESC
        LIMIT page_size
    """
```

**Implementation**:

```python
async def get_gallery(self, user_email: str, filters=None, **kwargs):
    query = self.firestore.collection('media_library')
    query = query.where('user_email', '==', user_email)

    # Apply filters
    if filters:
        if filters.get('mime_type'):
            query = query.where('mime_type', '==', filters['mime_type'])
        if filters.get('model'):
            query = query.where('model', '==', filters['model'])
        if filters.get('status'):
            query = query.where('status', '==', filters['status'])

    # Order and paginate
    query = query.order_by('created_at', direction='DESCENDING')

    if kwargs.get('start_after'):
        last_doc = await self.firestore.get_document('media_library', kwargs['start_after'])
        query = query.start_after(last_doc)

    docs = query.limit(kwargs.get('page_size', 20) + 1).get()

    return [doc.to_dict() for doc in docs]
```

#### `search_gallery()`

```python
async def search_gallery(
    self,
    user_email: str,
    query: str,
) -> List[MediaItem]:
    """
    Full-text search across gallery

    Note:
        - Searches in prompt field
        - Uses Firestore text search (basic substring matching)
        - For advanced search, consider Elasticsearch
    """
```

#### `get_media_detail()`

```python
async def get_media_detail(
    self,
    media_id: str,
    user_email: str,
) -> MediaItem:
    """
    Get detailed media item with signed URLs

    Returns:
        - metadata (width, height, file size)
        - signed_url (expires in 1 hour)
        - thumbnail_url (for images/videos)
    """
```

#### `delete_media()`

```python
async def delete_media(self, media_id: str, user_email: str) -> None:
    """
    Delete media and associated GCS file

    1. Verify user ownership
    2. Delete from Firestore
    3. Delete from Cloud Storage
    """
```

#### `update_media_metadata()`

```python
async def update_media_metadata(
    self,
    media_id: str,
    user_email: str,
    tags: List[str] = None,
    name: str = None,
) -> MediaItem:
    """Update tags, name, and other metadata"""
```

### Database Indexes

For efficient queries, these composite indexes are required:

```
Collection: media_library
Indexes:
  1. user_email (ASC), created_at (DESC)
  2. user_email (ASC), mime_type (ASC), created_at (DESC)
  3. user_email (ASC), model (ASC), created_at (DESC)
  4. user_email (ASC), status (ASC), created_at (DESC)
```

---

## UserService

### Purpose
Handles user management, Just-In-Time provisioning, role assignment, and user metadata.

### Key Methods

#### `get_or_create_user()`

```python
async def get_or_create_user(
    self,
    decoded_token: dict,
) -> UserModel:
    """
    Get existing user or create new one (JIT provisioning)

    Args:
        decoded_token: Firebase ID token with email, uid, name, picture

    Returns:
        UserModel with roles and workspace info

    Flow:
        1. Check if user exists in Firestore
        2. If exists, return existing user
        3. If new, create user document with:
           - email
           - display_name
           - avatar_uri
           - roles: [viewer] (default)
           - created_at
    """
```

#### `get_user()`

```python
async def get_user(self, user_id: str) -> UserModel:
    """Get user by Firebase UID"""
```

#### `update_user_profile()`

```python
async def update_user_profile(
    self,
    user_id: str,
    display_name: str = None,
    avatar_uri: str = None,
) -> UserModel:
    """Update user profile information"""
```

#### `assign_workspace()`

```python
async def assign_workspace(
    self,
    user_id: str,
    workspace_id: str,
) -> None:
    """Assign user to default workspace"""
```

#### `update_user_roles()`

```python
async def update_user_roles(
    self,
    user_id: str,
    roles: List[UserRoleEnum],
) -> UserModel:
    """
    Update user roles (admin only)

    Also updates Firebase custom claims for token refresh
    """
```

### User Model

```python
@dataclass
class UserModel:
    id: str                          # Firebase UID
    email: str
    display_name: str = None
    avatar_uri: str = None
    roles: List[UserRoleEnum] = field(default_factory=list)
    workspace_id: str = None         # Default workspace
    created_at: datetime = None
    last_login: datetime = None

    def has_role(self, role: UserRoleEnum) -> bool:
        return role in self.roles

    def can_edit(self) -> bool:
        return self.has_role(UserRoleEnum.ADMIN) or self.has_role(UserRoleEnum.EDITOR)
```

---

## WorkspaceService

### Purpose
Handles workspace management, member invitations, role assignments, and workspace isolation.

### Key Methods

#### `create_workspace()`

```python
async def create_workspace(
    self,
    name: str,
    owner_id: str,
    description: str = None,
) -> WorkspaceModel:
    """
    Create new workspace

    Args:
        name: Workspace name
        owner_id: Creating user's Firebase UID
        description: Optional description

    Returns:
        WorkspaceModel with owner as admin member

    Creates:
        - workspaces/{id} document
        - Members array with owner as admin
        - Settings document for configuration
    """
```

#### `get_workspace()`

```python
async def get_workspace(self, workspace_id: str) -> WorkspaceModel:
    """Get workspace details"""
```

#### `list_user_workspaces()`

```python
async def list_user_workspaces(self, user_id: str) -> List[WorkspaceModel]:
    """List all workspaces user is member of"""
```

#### `add_member()`

```python
async def add_member(
    self,
    workspace_id: str,
    user_email: str,
    role: UserRoleEnum = UserRoleEnum.VIEWER,
) -> WorkspacePermissionModel:
    """
    Add member to workspace

    Args:
        workspace_id: Target workspace
        user_email: New member email
        role: admin, editor, or viewer

    Process:
        1. Find user by email
        2. Add to workspace members array
        3. Update user's workspace_id (if default)
    """
```

#### `remove_member()`

```python
async def remove_member(
    self,
    workspace_id: str,
    user_id: str,
) -> None:
    """Remove member from workspace"""
```

#### `update_member_role()`

```python
async def update_member_role(
    self,
    workspace_id: str,
    user_id: str,
    new_role: UserRoleEnum,
) -> None:
    """Update member's role in workspace"""
```

#### `update_workspace()`

```python
async def update_workspace(
    self,
    workspace_id: str,
    name: str = None,
    settings: dict = None,
) -> WorkspaceModel:
    """Update workspace name and settings"""
```

#### `delete_workspace()`

```python
async def delete_workspace(self, workspace_id: str) -> None:
    """
    Delete workspace (owner only)

    Cascading deletes:
        1. All media_library items in workspace
        2. All source_assets in workspace
        3. Brand guidelines
        4. Media templates
        5. Workspace document
    """
```

### Workspace Model

```python
@dataclass
class WorkspaceModel:
    id: str
    name: str
    owner_id: str
    members: List[WorkspacePermissionModel]
    created_at: datetime
    settings: dict = field(default_factory=dict)

    def get_user_role(self, user_id: str) -> Optional[UserRoleEnum]:
        for member in self.members:
            if member.user_id == user_id:
                return member.role
        return None

    def is_member(self, user_id: str) -> bool:
        return self.get_user_role(user_id) is not None
```

---

## SourceAssetService

### Purpose
Manages user-uploaded reference assets (images, documents) used in generation.

### Key Methods

#### `get_upload_url()`

```python
async def get_upload_url(
    self,
    workspace_id: str,
    asset_type: str,
    mime_type: str,
    file_size_bytes: int,
) -> UploadUrlResponse:
    """
    Get presigned URL for direct Cloud Storage upload

    Args:
        asset_type: reference-image, brand-document, etc.
        mime_type: image/jpeg, application/pdf, etc.
        file_size_bytes: For validation

    Returns:
        UploadUrlResponse with:
        - upload_url: Presigned POST URL (valid 1 hour)
        - file_id: Temporary file identifier
        - expires_at: Expiration timestamp

    Flow:
        Frontend uploads directly to GCS bypassing backend
        (for large files)
    """
```

#### `register_asset()`

```python
async def register_asset(
    self,
    workspace_id: str,
    user_id: str,
    gcs_uri: str,
    asset_type: str,
    name: str = None,
) -> SourceAssetModel:
    """
    Register uploaded file as source asset

    Args:
        gcs_uri: gs://bucket/path/to/file
        asset_type: Categorization of asset

    Process:
        1. Verify file exists in GCS
        2. Calculate file hash
        3. Create source_assets document
        4. Return asset metadata
    """
```

#### `get_asset()`

```python
async def get_asset(
    self,
    asset_id: str,
    workspace_id: str,
) -> SourceAssetModel:
    """Get asset details with signed URL"""
```

#### `list_assets()`

```python
async def list_assets(
    self,
    workspace_id: str,
    asset_type: str = None,
) -> List[SourceAssetModel]:
    """List workspace assets with optional type filter"""
```

#### `delete_asset()`

```python
async def delete_asset(
    self,
    asset_id: str,
    workspace_id: str,
) -> None:
    """Delete asset and GCS file"""
```

### SourceAsset Model

```python
@dataclass
class SourceAssetModel:
    id: str
    workspace_id: str
    user_id: str
    asset_type: str              # reference-image, brand-document, etc.
    mime_type: str
    gcs_uri: str
    file_hash: str               # SHA-256 hash
    created_at: datetime
    name: str = None
```

---

## BrandGuidelineService

### Purpose
Handles brand guidelines PDF upload, text extraction, and summarization.

### Key Methods

#### `get_upload_url()`

```python
async def get_upload_url(
    self,
    workspace_id: str,
    file_size_bytes: int,
) -> UploadUrlResponse:
    """Get presigned URL for PDF upload"""
```

#### `process_brand_guidelines()`

```python
async def process_brand_guidelines(
    self,
    workspace_id: str,
    gcs_uri: str,
) -> BrandGuidelineModel:
    """
    Process uploaded PDF asynchronously

    Args:
        gcs_uri: gs://bucket/path/to/guidelines.pdf

    Process:
        1. Download PDF from GCS
        2. Extract text using pypdf
        3. Summarize with Gemini API
        4. Store in Firestore with status=ready

    Returns:
        BrandGuidelineModel with extracted text
    """
```

**Implementation**:

```python
async def process_brand_guidelines(self, workspace_id: str, gcs_uri: str):
    # Create initial document
    guide_doc = {
        'workspace_id': workspace_id,
        'gcs_uri': gcs_uri,
        'status': 'processing',
        'created_at': datetime.utcnow().isoformat(),
    }
    guide_id = await self.firestore.create_document('brand_guidelines', guide_doc)

    try:
        # Download PDF
        pdf_data = await self.storage.download(gcs_uri)

        # Extract text
        extracted_text = await self._extract_pdf_text(pdf_data)

        # Summarize with Gemini
        summary = await self._summarize_with_gemini(extracted_text)

        # Update with results
        await self.firestore.update_document('brand_guidelines', guide_id, {
            'extracted_text': extracted_text,
            'summary': summary,
            'status': 'ready',
            'processed_at': datetime.utcnow().isoformat(),
        })

    except Exception as e:
        logger.error(f'Brand guideline processing failed: {e}')
        await self.firestore.update_document('brand_guidelines', guide_id, {
            'status': 'failed',
            'error': str(e),
        })
```

#### `get_brand_guidelines()`

```python
async def get_brand_guidelines(
    self,
    workspace_id: str,
) -> BrandGuidelineModel:
    """
    Get brand guidelines for workspace

    Returns current guidelines or None if not set
    """
```

#### `delete_brand_guidelines()`

```python
async def delete_brand_guidelines(
    self,
    guide_id: str,
    workspace_id: str,
) -> None:
    """Delete brand guidelines"""
```

### PDF Processing Details

**Text Extraction** (using pypdf):
```python
import pypdf

async def _extract_pdf_text(self, pdf_data: bytes) -> str:
    pdf = pypdf.PdfReader(io.BytesIO(pdf_data))
    text = ""

    for page in pdf.pages:
        text += page.extract_text()

    return text
```

**Gemini Summarization**:
```python
async def _summarize_with_gemini(self, text: str) -> str:
    # Call Gemini API
    response = await self.gemini_client.generate_content(
        f"Summarize these brand guidelines:\n\n{text}",
        generation_config={'max_output_tokens': 500},
    )
    return response.text
```

---

## MediaTemplateService

### Purpose
Manages media generation templates with variable substitution.

### Key Methods

#### `create_template()`

```python
async def create_template(
    self,
    workspace_id: str,
    name: str,
    category: str,
    model: str,
    prompt_template: str,
    variables: List[TemplateVariable],
) -> MediaTemplateModel:
    """
    Create custom template

    Args:
        prompt_template: Template with {{variable}} placeholders
        variables: List of variable definitions

    Example:
        prompt_template: "A {{style}} {{item}} in {{color}}"
        variables: [
            {'name': 'style', 'required': True},
            {'name': 'item', 'required': True},
            {'name': 'color', 'required': False},
        ]
    """
```

#### `get_template()`

```python
async def get_template(self, template_id: str) -> MediaTemplateModel:
    """Get template details"""
```

#### `list_templates()`

```python
async def list_templates(
    self,
    workspace_id: str = None,
    category: str = None,
    model: str = None,
) -> List[MediaTemplateModel]:
    """List templates with optional filters"""
```

#### `generate_from_template()`

```python
async def generate_from_template(
    self,
    template_id: str,
    variables: dict,
    workspace_id: str,
    user_email: str,
    model_type: str = 'image',
) -> GenerationResponse:
    """
    Generate media using template

    Args:
        variables: {'style': 'elegant', 'item': 'dress', 'color': 'red'}

    Process:
        1. Get template
        2. Validate variables (check required)
        3. Substitute variables in prompt_template
        4. Call appropriate generation service (Image/Video/Audio)
    """
```

**Variable Substitution**:

```python
async def _substitute_variables(
    self,
    template_prompt: str,
    variables: dict,
) -> str:
    import re

    prompt = template_prompt
    # Replace all {{variable}} with values
    for var_name, var_value in variables.items():
        prompt = prompt.replace(f'{{{{{var_name}}}}}', str(var_value))

    return prompt
```

#### `delete_template()`

```python
async def delete_template(self, template_id: str, workspace_id: str) -> None:
    """Delete template"""
```

---

## GeminiService

### Purpose
Integrates Google's Gemini multimodal model for image/text analysis and prompt enhancement.

### Key Methods

#### `analyze_image()`

```python
async def analyze_image(
    self,
    image_uri: str,
    prompt: str,
    workspace_id: str,
) -> AnalysisResponse:
    """
    Analyze image with Gemini 2.0

    Args:
        image_uri: gs://bucket/path/to/image.jpg
        prompt: Analysis request (e.g., "Describe this image")

    Returns:
        AnalysisResponse with Gemini's response

    Process:
        1. Download image from GCS
        2. Call Gemini with image + prompt
        3. Return analysis text
    """
```

#### `analyze_text()`

```python
async def analyze_text(
    self,
    text: str,
    prompt: str,
) -> AnalysisResponse:
    """
    Analyze text with Gemini

    Args:
        text: Text to analyze
        prompt: Analysis request
    """
```

#### `enhance_prompt()`

```python
async def enhance_prompt(
    self,
    prompt: str,
    context: str = None,
) -> str:
    """
    Use Gemini to enhance image/video prompt

    Adds details, style guidance, quality descriptors
    """
```

#### `extract_from_image()`

```python
async def extract_from_image(
    self,
    image_uri: str,
    extraction_type: str,
) -> dict:
    """
    Extract specific data from image

    Args:
        extraction_type: text, objects, colors, composition, etc.

    Returns:
        Structured data based on extraction type
    """
```

---

## Storage & Repository Services

### FirestoreRepository

```python
class FirestoreRepository:
    """Firestore CRUD operations"""

    async def create_document(
        self,
        collection: str,
        data: dict,
        document_id: str = None,
    ) -> str:
        """Create document, return ID"""

    async def get_document(
        self,
        collection: str,
        document_id: str,
    ) -> dict:
        """Get single document"""

    async def update_document(
        self,
        collection: str,
        document_id: str,
        data: dict,
    ) -> None:
        """Partial update"""

    async def delete_document(
        self,
        collection: str,
        document_id: str,
    ) -> None:
        """Delete document"""

    async def query_documents(
        self,
        collection: str,
        where_conditions: List[tuple],
        order_by: tuple = None,
        limit: int = 20,
    ) -> List[dict]:
        """Query with filters"""

    async def batch_get(
        self,
        collection: str,
        document_ids: List[str],
    ) -> List[dict]:
        """Batch retrieve multiple documents"""

    async def batch_write(
        self,
        operations: List[dict],
    ) -> None:
        """Batch write multiple documents"""
```

### StorageService

```python
class StorageService:
    """Cloud Storage operations"""

    async def upload(
        self,
        data: bytes,
        bucket: str,
        path: str,
        content_type: str = None,
    ) -> str:
        """Upload file, return gs:// URI"""

    async def download(self, gcs_uri: str) -> bytes:
        """Download file bytes"""

    async def delete(self, gcs_uri: str) -> None:
        """Delete file"""

    async def generate_signed_url(
        self,
        gcs_uri: str,
        expires_in_hours: int = 1,
    ) -> str:
        """Generate time-limited download URL"""

    async def copy(
        self,
        source_uri: str,
        dest_uri: str,
    ) -> None:
        """Copy file within bucket"""

    async def exists(self, gcs_uri: str) -> bool:
        """Check if file exists"""
```

---

## Error Handling

### Custom Exception Hierarchy

```python
class ServiceException(Exception):
    """Base exception for all services"""
    pass

class ValidationError(ServiceException):
    """Input validation failed"""
    pass

class NotFoundError(ServiceException):
    """Resource not found"""
    pass

class PermissionError(ServiceException):
    """User lacks permission"""
    pass

class ExternalServiceError(ServiceException):
    """Vertex AI, Firestore, or GCS error"""
    pass

class AsyncOperationError(ServiceException):
    """Async operation failed"""
    pass
```

### Error Handling Pattern

```python
try:
    result = await service.do_something()
except ValidationError as e:
    # Client error - 400 Bad Request
    raise HTTPException(status_code=400, detail=str(e))
except PermissionError as e:
    # Forbidden - 403
    raise HTTPException(status_code=403, detail=str(e))
except NotFoundError as e:
    # Not found - 404
    raise HTTPException(status_code=404, detail=str(e))
except ExternalServiceError as e:
    # Service unavailable - 503
    logger.error(f'External service error: {e}')
    raise HTTPException(status_code=503, detail='Service temporarily unavailable')
except Exception as e:
    # Unexpected - 500
    logger.error(f'Unexpected error: {e}', exc_info=True)
    raise HTTPException(status_code=500, detail='Internal server error')
```

---

## Async Operations

### Long-Running Operation Pattern

Some operations (videos, PDF processing) take time:

1. **Immediate Response**:
   - Save initial document with `status=pending`
   - Return request ID
   - Return 202 Accepted

2. **Background Processing**:
   - Call Vertex AI API (async)
   - Store operation ID
   - Let operation run in background

3. **Client Polling**:
   - Frontend polls status endpoint
   - Check operation progress via Firestore
   - Query Vertex AI operation API if needed

4. **Completion**:
   - Download result
   - Upload to GenMedia bucket
   - Update Firestore with status and URI

**Example**:

```python
# Initial request
@router.post('/api/videos')
async def generate_video(request: VideoRequest, user_email: str):
    # Create pending document
    doc = await service.generate_video(request.prompt, user_email)
    # Return immediately
    return {"status": "pending", "id": doc['id']}

# Status polling
@router.get('/api/videos/{video_id}')
async def get_video_status(video_id: str, user_email: str):
    # Check status - may still be pending
    doc = await service.get_video_status(video_id, user_email)
    return {"status": doc['status'], "progress": doc.get('progress', 0)}
```

---

## Caching Strategies

### Service-Level Caching

```python
class CachedGalleryService(GalleryService):
    """Gallery service with in-memory caching"""

    def __init__(self, firestore):
        super().__init__(firestore)
        self._cache = {}
        self._cache_ttl = 5 * 60  # 5 minutes

    async def get_gallery(self, user_email: str, **kwargs):
        cache_key = f"gallery:{user_email}"
        cached = self._cache.get(cache_key)

        if cached and (time.time() - cached['time']) < self._cache_ttl:
            return cached['data']

        data = await super().get_gallery(user_email, **kwargs)
        self._cache[cache_key] = {'data': data, 'time': time.time()}

        return data
```

### Strategies by Service

| Service | Cache Duration | When to Clear |
|---------|----------------|---------------|
| GalleryService | 5 minutes | On media create/delete |
| UserService | 30 minutes | On profile update |
| WorkspaceService | 30 minutes | On workspace update |
| TemplateService | 1 hour | On template create/delete |
| BrandGuidelineService | 1 hour | On PDF reupload |

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Applies To**: Backend service implementation
- **Related Docs**: API_REFERENCE.md, AUTH_IMPLEMENTATION.md, DATA_FLOW.md
