# User Roles and Permissions Guide
## Creative Studio

**Document Version**: 1.0
**Last Updated**: December 15, 2025
**Status**: Complete

---

## Table of Contents

1. [Overview](#overview)
2. [Role Hierarchy](#role-hierarchy)
3. [System-Level Roles](#system-level-roles)
4. [Workspace-Level Roles](#workspace-level-roles)
5. [Permission Matrix](#permission-matrix)
6. [Feature-by-Feature Breakdown](#feature-by-feature-breakdown)
7. [Real-World Scenarios](#real-world-scenarios)
8. [Implementation Details](#implementation-details)
9. [Best Practices](#best-practices)

---

## Overview

Creative Studio implements a **two-tier permission system** to provide flexible access control:

### Tier 1: System-Level Roles
Global roles assigned to users across the entire application.

### Tier 2: Workspace-Level Roles
Granular roles assigned within specific workspaces.

**Key Principle**: Workspace-level permissions override system-level restrictions for workspace operations.

---

## Role Hierarchy

### System-Level Roles (from lowest to highest privilege)

```
USER  →  CREATOR  →  ADMIN
```

Each role inherits permissions from lower roles plus adds new capabilities.

### Workspace-Level Roles (from lowest to highest privilege)

```
VIEWER  →  EDITOR  →  ADMIN  →  OWNER
```

---

## System-Level Roles

### 👤 USER

**What is it?**
The default role assigned to all new users. Provides basic access to core features.

**When assigned?**
- Automatically assigned to new users on first login
- Default fallback role if no roles are specified

**Capabilities**:
- ✅ View own profile
- ✅ Browse personal workspace
- ✅ Access assigned workspaces
- ✅ Create content (images, videos, audio)
- ✅ Manage own generated media
- ✅ Upload source assets to workspaces
- ✅ Use brand guidelines (read-only)
- ❌ Cannot create system-level templates
- ❌ Cannot manage other users
- ❌ Cannot configure system settings

**Code References**:
```python
# backend/src/users/user_model.py
USER = "user"  # Basic access to browse and use public features.

# Usage in controllers
RoleChecker(allowed_roles=[UserRoleEnum.USER, UserRoleEnum.ADMIN])
```

**API Endpoints Requiring USER Role**:
- POST `/api/images/generate-images` - Create images with Imagen
- POST `/api/videos/generate-videos` - Create videos with Veo
- POST `/api/audios/generate` - Create audio with Chirp
- GET `/api/galleries` - View media gallery
- POST `/api/source-assets/upload` - Upload reference images/documents
- GET `/api/media-templates` - View available templates

---

### 🎨 CREATOR

**What is it?**
An enhanced role that allows creating and managing reusable templates at the system level.

**When to assign?**
- Power users who create content templates for teams
- Content creators who want to share prompts with others
- Design leads managing brand templates

**Additional Capabilities** (beyond USER):
- ✅ Create system-level media templates
- ✅ Manage own system templates
- ✅ Share templates with workspaces
- ✅ Edit own templates
- ❌ Cannot delete other users' templates
- ❌ Cannot manage system settings

**Code References**:
```python
# backend/src/users/user_model.py
CREATOR = "creator"  # Can create and manage their own content.
```

**API Endpoints Requiring CREATOR Role**:
- POST `/api/media-templates` - Create new templates
- PUT `/api/media-templates/{id}` - Edit templates
- DELETE `/api/media-templates/{id}` - Delete own templates

---

### 👑 ADMIN

**What is it?**
Super-user role with system-wide administrative privileges and full control over all resources.

**When to assign?**
- System administrators
- Platform operators
- Support staff requiring full access

**Full Capabilities**:
- ✅ ALL permissions from USER and CREATOR roles
- ✅ Manage all users (view, update, assign roles)
- ✅ Access all workspaces regardless of membership
- ✅ Create/edit/delete any templates
- ✅ Delete any media or assets
- ✅ Configure system settings
- ✅ Bypass workspace-level restrictions
- ✅ View audit logs (if implemented)

**Code References**:
```python
# backend/src/users/user_model.py
ADMIN = "admin"  # Has full administrative privileges.

# Usage in controllers
admin_only = Depends(RoleChecker(allowed_roles=[UserRoleEnum.ADMIN]))
```

**Special Behavior**:
```python
# backend/src/workspaces/workspace_auth_guard.py
is_admin = UserRoleEnum.ADMIN in user.roles

if not (is_admin or is_public):
    # Check if user is a member
    is_member = await workspace_repo.is_member(workspace_id, user.id)
    if not is_member:
        raise HTTPException(status_code=403)
```

ADMIN users bypass membership checks and can access any workspace.

**API Endpoints Requiring ADMIN Role**:
- GET `/api/users` - List all users
- POST `/api/users/{id}/roles` - Assign roles to users
- DELETE `/api/media-templates/{id}` - Delete any template
- DELETE `/api/galleries/{id}` - Delete any media
- Access all workspace administration endpoints

---

## Workspace-Level Roles

In addition to system-level roles, each user has a **workspace-specific role** that controls what they can do within that workspace.

### 👁️ VIEWER

**What is it?**
Read-only access to workspace content. Cannot make modifications.

**Capabilities within workspace**:
- ✅ View all media in workspace gallery
- ✅ View workspace members
- ✅ View workspace templates
- ✅ Download media files
- ✅ View workspace settings (read-only)
- ❌ Cannot create content
- ❌ Cannot upload assets
- ❌ Cannot invite members
- ❌ Cannot modify workspace settings

**Use Cases**:
- Stakeholders reviewing work
- Clients viewing final deliverables
- Team members with view-only access

---

### ✏️ EDITOR

**What is it?**
Full creation and editing capabilities within the workspace. Cannot manage workspace itself.

**Additional Capabilities** (beyond VIEWER):
- ✅ Generate images, videos, audio
- ✅ Upload source assets
- ✅ Create and use templates
- ✅ Delete own content
- ✅ Edit media metadata (tags, names)
- ✅ Use brand guidelines
- ❌ Cannot change workspace settings
- ❌ Cannot invite or remove members
- ❌ Cannot transfer ownership

**Use Cases**:
- Content creators
- Design team members
- Regular contributors

---

### 🔧 ADMIN

**What is it?**
Administrative control of workspace content and members, but not ownership.

**Additional Capabilities** (beyond EDITOR):
- ✅ ALL editor capabilities
- ✅ Delete any media (not just own)
- ✅ Invite new members to workspace
- ✅ Change member roles
- ✅ Remove members
- ✅ Edit workspace settings
- ✅ Manage brand guidelines
- ✅ Create/manage workspace templates
- ❌ Cannot delete the workspace
- ❌ Cannot transfer workspace ownership
- ❌ Cannot change workspace scope

**Use Cases**:
- Team leads
- Project managers
- Content administrators

**Code References**:
```python
# backend/src/workspaces/schema/workspace_model.py
class WorkspaceRoleEnum(str, Enum):
    VIEWER = "viewer"
    EDITOR = "editor"
    ADMIN = "admin"
    OWNER = "owner"
```

---

### 👨‍💼 OWNER

**What is it?**
Complete ownership and control of the workspace. Can delete the workspace entirely.

**Additional Capabilities** (beyond ADMIN):
- ✅ ALL admin capabilities
- ✅ Delete the entire workspace
- ✅ Transfer workspace ownership
- ✅ Change workspace scope (public/private)
- ✅ Access full audit trail of workspace

**Use Cases**:
- Workspace creator
- Project owner
- Organization administrator

**Special Notes**:
- There is always exactly **one owner per workspace**
- Ownership can be transferred to another member
- Deleting a workspace cascades to all content within it

---

## Permission Matrix

### System-Level Permissions

| Action | USER | CREATOR | ADMIN |
|--------|------|---------|-------|
| **View own profile** | ✅ | ✅ | ✅ |
| **Update own profile** | ✅ | ✅ | ✅ |
| **Access public workspaces** | ✅ | ✅ | ✅ |
| **Generate images** | ✅ | ✅ | ✅ |
| **Generate videos** | ✅ | ✅ | ✅ |
| **Generate audio** | ✅ | ✅ | ✅ |
| **Create templates** | ❌ | ✅ | ✅ |
| **Delete own templates** | ❌ | ✅ | ✅ |
| **Delete any template** | ❌ | ❌ | ✅ |
| **View users list** | ❌ | ❌ | ✅ |
| **Assign user roles** | ❌ | ❌ | ✅ |
| **Access all workspaces** | ❌ | ❌ | ✅ |
| **View system settings** | ❌ | ❌ | ✅ |

---

### Workspace-Level Permissions

| Action | VIEWER | EDITOR | ADMIN | OWNER |
|--------|--------|--------|-------|-------|
| **View media** | ✅ | ✅ | ✅ | ✅ |
| **Download media** | ✅ | ✅ | ✅ | ✅ |
| **View templates** | ✅ | ✅ | ✅ | ✅ |
| **Generate content** | ❌ | ✅ | ✅ | ✅ |
| **Upload assets** | ❌ | ✅ | ✅ | ✅ |
| **Delete own content** | ❌ | ✅ | ✅ | ✅ |
| **Delete any content** | ❌ | ❌ | ✅ | ✅ |
| **Create templates** | ❌ | ✅ | ✅ | ✅ |
| **Edit workspace settings** | ❌ | ❌ | ✅ | ✅ |
| **Invite members** | ❌ | ❌ | ✅ | ✅ |
| **Change member roles** | ❌ | ❌ | ✅ | ✅ |
| **Remove members** | ❌ | ❌ | ✅ | ✅ |
| **Delete workspace** | ❌ | ❌ | ❌ | ✅ |
| **Transfer ownership** | ❌ | ❌ | ❌ | ✅ |
| **Change scope** | ❌ | ❌ | ❌ | ✅ |

---

## Feature-by-Feature Breakdown

### 🖼️ Image Generation

**Requires**: System-level USER role OR higher

**Endpoint**: `POST /api/images/generate-images`

**Workspace-level requirement**: EDITOR or higher in target workspace

**Code**:
```python
# backend/src/images/imagen_controller.py
RoleChecker(allowed_roles=[UserRoleEnum.USER, UserRoleEnum.ADMIN])
```

**Restrictions**:
- Users can only generate in workspaces where they have EDITOR or higher role
- All generated images are stored in workspace gallery
- Images tagged with user and workspace metadata

---

### 🎬 Video Generation

**Requires**: System-level USER role OR higher

**Endpoint**: `POST /api/videos/generate-videos`

**Workspace-level requirement**: EDITOR or higher in target workspace

**Code**:
```python
# backend/src/videos/veo_controller.py
RoleChecker(allowed_roles=[UserRoleEnum.USER, UserRoleEnum.ADMIN])
```

**Special Features**:
- Async operation (returns immediately with pending status)
- Can concatenate multiple videos (if EDITOR or higher)

---

### 🎵 Audio Generation

**Requires**: System-level USER role OR higher

**Endpoint**: `POST /api/audios/generate`

**Workspace-level requirement**: EDITOR or higher in target workspace

**Additional**:
- Audio transcription requires EDITOR role or higher

---

### 📚 Media Templates

**Creating Templates**:
- **Requires**: System-level CREATOR or ADMIN role
- **Endpoint**: `POST /api/media-templates`
- **Code**:
```python
admin_only = Depends(RoleChecker(allowed_roles=[UserRoleEnum.ADMIN]))
```

**Using Templates**:
- **Requires**: System-level USER role (any EDITOR in target workspace)
- **Can be used by**: Any EDITOR or higher in workspace where template is shared

**Managing Templates**:
- **Own templates**: CREATOR can edit/delete
- **All templates**: ADMIN can delete any template

---

### 📤 Source Assets (Uploads)

**Uploading Assets**:
- **Requires**: System-level USER role
- **Workspace requirement**: EDITOR or higher
- **Endpoint**: `POST /api/source-assets/upload`

**Deleting Assets**:
- **Own assets**: EDITOR who uploaded can delete
- **All assets**: ADMIN in workspace can delete any
- **System-level**: System ADMIN can delete any asset

---

### 🎨 Brand Guidelines

**Uploading PDF**:
- **Requires**: System-level USER role
- **Workspace requirement**: EDITOR or higher
- **Status**: Async processing

**Using Guidelines**:
- **Requires**: System-level USER role
- **Workspace requirement**: VIEWER or higher (read-only)
- When EDITOR generates content, can apply brand guidelines

**Managing Guidelines**:
- **Workspace ADMIN**: Can replace/delete workspace guidelines

---

### 👥 User Management

**View Users**:
- **Requires**: System-level ADMIN role only
- **Endpoint**: `GET /api/users`
- **Returns**: List of all users in system

**Assign Roles**:
- **Requires**: System-level ADMIN role only
- **Endpoint**: `POST /api/users/{id}/roles`
- **Can assign**: Any system-level role

---

### 👨‍👩‍👧 Workspace Management

**Creating Workspace**:
- **Requires**: System-level USER role (any role)
- **Creator becomes**: OWNER of new workspace
- **Default scope**: PRIVATE

**Inviting Members**:
- **Requires**: Workspace ADMIN or OWNER role
- **Can assign roles**: VIEWER, EDITOR, ADMIN to new members

**Removing Members**:
- **Requires**: Workspace ADMIN or OWNER role
- **Cannot remove**: The OWNER

**Transferring Ownership**:
- **Requires**: Workspace OWNER role only
- **New owner**: Must already be ADMIN in workspace
- **Previous owner**: Becomes ADMIN after transfer

**Deleting Workspace**:
- **Requires**: Workspace OWNER role only
- **Cascades to**: All media, assets, templates in workspace

---

## Real-World Scenarios

### Scenario 1: Design Agency

**Organizational Structure**:
- **Owner**: Creative Director (ADMIN at system level, OWNER of workspace)
- **Team**: 5 designers (USER at system, EDITOR in workspace)
- **Client**: Stakeholder viewing work (USER at system, VIEWER in workspace)

**Permissions**:
```
Creative Director:
  - System: ADMIN (manage all templates, user roles)
  - Workspace: OWNER (full control)

Designers:
  - System: USER (create content)
  - Workspace: EDITOR (generate images/videos, upload assets)

Client:
  - System: USER (basic access)
  - Workspace: VIEWER (view only, download files)
```

**Workflow**:
1. Director invites 5 designers to workspace as EDITOR
2. Designers generate content using templates
3. Director reviews and invites client as VIEWER
4. Client downloads approved materials
5. Director can remove client without affecting team

---

### Scenario 2: Internal Marketing Team

**Organizational Structure**:
- **Manager**: Marketing lead (CREATOR at system, ADMIN in workspace)
- **Contributors**: 3 content creators (USER at system, EDITOR in workspace)
- **Reviewer**: Manager (ADMIN in workspace for approval)

**Permissions**:
```
Manager:
  - System: CREATOR (create and manage templates)
  - Workspace: ADMIN (manage team, approve content)

Contributors:
  - System: USER (use tools)
  - Workspace: EDITOR (create content)

Reviewer:
  - System: USER (view only at system level)
  - Workspace: ADMIN (review and manage)
```

**Key Benefit**: Templates created by Manager are reusable by team.

---

### Scenario 3: Multi-Team Enterprise

**Setup**:
- System ADMIN manages users and policies
- Each team has workspace with own OWNER/ADMIN
- Templates shared across teams

**Permissions**:
```
System Admin:
  - System: ADMIN (global access, no workspace restrictions)
  - Can access any workspace to troubleshoot

Team Owners:
  - System: CREATOR or USER (depends on policy)
  - Workspace: OWNER (full workspace control)

Team Members:
  - System: USER
  - Workspace: EDITOR or VIEWER (depends on role)
```

---

## Implementation Details

### Authentication Flow

```
1. User logs in with Google → Firebase auth
2. Token verified → get_current_user() dependency
3. User roles loaded from database
4. Just-In-Time provisioning if new user
5. Request proceeds with user context
```

**Code Flow**:
```python
# backend/src/auth/auth_guard.py
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    user_service: UserService = Depends(UserService),
) -> UserModel:
    # 1. Verify token (Firebase or Google OIDC)
    decoded_token = await verify_token(token)

    # 2. Create user if new (JIT provisioning)
    user_doc = await user_service.create_user_if_not_exists(...)

    # 3. Return user with roles
    return user_doc  # Contains roles list
```

### Role Checking

**System-Level**:
```python
from src.auth.auth_guard import RoleChecker, get_current_user

@router.post("/generate-images")
async def generate_images(
    current_user: UserModel = Depends(get_current_user),
    service: ImagenService = Depends(),
):
    # RoleChecker validates user has USER or ADMIN role
    # If not, raises HTTPException(403)
```

**Workspace-Level**:
```python
from src.workspaces.workspace_auth_guard import workspace_auth_service

@router.post("/generate-images")
async def generate_images(
    workspace_id: int,
    current_user: UserModel = Depends(get_current_user),
):
    # Check both system role AND workspace membership
    workspace = await workspace_auth_service.authorize(
        workspace_id=workspace_id,
        user=current_user
    )
    # If user is ADMIN at system level, bypasses membership check
    # If not, checks if user is member with EDITOR+ role
```

---

### Database Schema

**Users Table**:
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR UNIQUE NOT NULL,
    roles TEXT[] NOT NULL,  -- Array of roles: ['user', 'creator', 'admin']
    name VARCHAR,
    picture VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

**Workspace Members Table**:
```sql
CREATE TABLE workspace_members (
    workspace_id INT REFERENCES workspaces(id),
    user_id INT REFERENCES users(id),
    role VARCHAR NOT NULL,  -- 'viewer', 'editor', 'admin', 'owner'
    PRIMARY KEY (workspace_id, user_id)
);
```

---

## Best Practices

### For Administrators

1. **Principle of Least Privilege**: Assign the minimum role needed
   - New users: USER role (not ADMIN)
   - Content creators: CREATOR role (not ADMIN)
   - Only grant ADMIN to system administrators

2. **Workspace Management**: Use roles effectively
   - VIEWER for stakeholders who shouldn't edit
   - EDITOR for active contributors
   - ADMIN for team leads
   - OWNER for workspace creator

3. **Regular Audits**: Review user roles quarterly
   - Remove access for departed employees
   - Update roles based on changing responsibilities

4. **Template Organization**: Use CREATOR role
   - Reduces ADMIN burden
   - Allows power users to create templates
   - Maintains control through approval

---

### For Users

1. **Know Your Role**: Understand what you can and cannot do
   - Check sidebar for role indicator
   - Request access if you need higher permissions
   - Don't assume access to all workspaces

2. **Workspace Specific**: Roles vary by workspace
   - You might be EDITOR in one workspace
   - VIEWER in another
   - No role in third (can't access)

3. **Request Escalation**: Need higher permissions?
   - Ask workspace ADMIN to upgrade your role
   - Ask system ADMIN if at system level
   - Explain why you need the access

---

### For Developers

1. **Use RoleChecker Dependency**: Always verify roles
   ```python
   @router.post("/endpoint")
   async def endpoint(
       current_user: UserModel = Depends(get_current_user),
       workspace_auth: WorkspaceModel = Depends(
           workspace_auth_service.authorize
       ),
   ):
       # Both checks done automatically
   ```

2. **Two-Tier Check for Workspace Operations**:
   ```python
   # Check system role (quick)
   is_admin = UserRoleEnum.ADMIN in user.roles

   # Check workspace role (if not admin)
   if not is_admin:
       workspace_role = await workspace_repo.get_user_role(
           workspace_id, user.id
       )
       if workspace_role not in ['editor', 'admin', 'owner']:
           raise HTTPException(403)
   ```

3. **Always Validate Permission Before Action**
   - Never trust client-side role indicators
   - Check roles at API boundary
   - Log permission denials for security

---

## Troubleshooting

### "You do not have sufficient permissions"

**Possible causes**:
1. System role too low (USER/CREATOR when ADMIN needed)
2. Not a member of target workspace
3. Workspace role too low (VIEWER when EDITOR needed)

**Solution**:
1. Check your system roles: Ask admin to view your roles
2. Check workspace membership: Admin can add you
3. Request role upgrade: Ask workspace ADMIN

---

### "Cannot access workspace"

**Possible causes**:
1. Workspace is PRIVATE and you're not a member
2. Workspace deleted
3. Your membership was removed

**Solution**:
1. Request invitation from workspace ADMIN/OWNER
2. Check if workspace still exists
3. Create new workspace if needed

---

### "Cannot delete resource"

**Possible causes**:
1. You're VIEWER or EDITOR (ADMIN+ needed)
2. System ADMIN deleted other admin's content
3. Cascading delete restriction

**Solution**:
1. Upgrade to ADMIN role in workspace
2. Contact system ADMIN for deletion
3. Check what's preventing deletion (related content)

---

## Summary

| Role | Scope | Access Level | Best For |
|------|-------|--------------|----------|
| **USER** | System | Basic | All users (default) |
| **CREATOR** | System | Enhanced | Power users creating templates |
| **ADMIN** | System | Full | System administrators |
| **VIEWER** | Workspace | Read-only | Stakeholders, reviewers |
| **EDITOR** | Workspace | Create/Edit | Active contributors |
| **ADMIN** | Workspace | Full | Team leads, administrators |
| **OWNER** | Workspace | Complete | Workspace creator, owner |

---

**For questions or permission issues, contact your system administrator.**

**Last Updated**: December 15, 2025
