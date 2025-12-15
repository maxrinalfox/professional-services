# Role-Based Access Control (RBAC)

This document provides an overview of the Role-Based Access Control (RBAC) implementation in Creative Studio.

> **For comprehensive role definitions, permissions, and scenarios, see [02_USER_ROLES_AND_PERMISSIONS.md](02_USER_ROLES_AND_PERMISSIONS.md)**

---

## Overview

Creative Studio implements a **two-tier permission system**:

1. **System-Level Roles** - Global roles across the entire application
2. **Workspace-Level Roles** - Granular roles within specific workspaces

---

## Quick Reference

### System-Level Roles

| Role | Access | Use Case |
|------|--------|----------|
| **USER** | Basic | Default for all users |
| **CREATOR** | Enhanced | Power users, template creators |
| **ADMIN** | Full system | System administrators |

### Workspace-Level Roles

| Role | Access | Use Case |
|------|--------|----------|
| **VIEWER** | Read-only | Stakeholders, reviewers |
| **EDITOR** | Create/Edit | Contributors, content creators |
| **ADMIN** | Full workspace | Team leads, administrators |
| **OWNER** | Complete | Workspace creator |

---

## Key Architecture

### Two-Tier Permission Model

```
┌─────────────────────────────────────┐
│     System-Level Roles              │
│  (USER, CREATOR, ADMIN)             │
│   Global application access         │
└──────────────┬──────────────────────┘
               │
               ↓ Combined with
               │
┌─────────────────────────────────────┐
│    Workspace-Level Roles            │
│ (VIEWER, EDITOR, ADMIN, OWNER)      │
│  Per-workspace access control       │
└─────────────────────────────────────┘
```

### Role Hierarchy

**System-Level** (least to most privileged):
```
USER → CREATOR → ADMIN
```

**Workspace-Level** (least to most privileged):
```
VIEWER → EDITOR → ADMIN → OWNER
```

---

## Implementation Details

### Authentication Flow

1. User logs in with Google
2. Token verified by Firebase/Google OIDC
3. User roles loaded from database
4. Just-In-Time (JIT) provisioning for new users
5. Request proceeds with authenticated user context

### Role Verification

**System-Level Check**:
```python
# Check if user has required system role
from src.auth.auth_guard import RoleChecker

@router.post("/endpoint")
async def endpoint(
    current_user: UserModel = Depends(
        RoleChecker(allowed_roles=[UserRoleEnum.ADMIN])
    ),
):
    # User must have ADMIN role to proceed
```

**Workspace-Level Check**:
```python
# Check both system role and workspace membership
from src.workspaces.workspace_auth_guard import workspace_auth_service

workspace = await workspace_auth_service.authorize(
    workspace_id=workspace_id,
    user=current_user
)
# Checks: is system ADMIN OR is workspace member with appropriate role
```

---

## Feature-Level Access Control

### Creation Endpoints

| Feature | System Role | Workspace Role |
|---------|-------------|----------------|
| Generate Images | USER | EDITOR |
| Generate Videos | USER | EDITOR |
| Generate Audio | USER | EDITOR |
| Create Templates | CREATOR | ADMIN |
| Upload Assets | USER | EDITOR |

### Management Endpoints

| Action | System Role | Workspace Role |
|--------|-------------|----------------|
| Delete own content | USER | EDITOR |
| Delete any content | ADMIN | ADMIN |
| Invite members | ADMIN | ADMIN |
| Remove members | ADMIN | ADMIN |
| Change roles | ADMIN | ADMIN |
| Delete workspace | ADMIN | OWNER |

---

## Database-Level Enforcement

### Users Table
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR UNIQUE NOT NULL,
    roles TEXT[] NOT NULL,  -- ['user'], ['user', 'creator'], or ['admin']
    name VARCHAR,
    picture VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

### Workspace Members Table
```sql
CREATE TABLE workspace_members (
    workspace_id INT REFERENCES workspaces(id),
    user_id INT REFERENCES users(id),
    role VARCHAR NOT NULL,  -- 'viewer', 'editor', 'admin', 'owner'
    PRIMARY KEY (workspace_id, user_id)
);
```

**Constraints**:
- Every user defaults to 'user' role if roles list is empty
- Workspace membership requires explicit entry in workspace_members table
- One OWNER per workspace (enforced by application logic)

---

## API Endpoint Authorization

All protected endpoints follow this pattern:

1. **Authenticate**: Verify valid token
2. **Check System Role**: Verify required system-level role
3. **Check Workspace Access**: Verify workspace membership (if applicable)
4. **Execute**: Perform authorized action

**Example: Generate Image**
```python
@router.post("/api/images/generate-images")
async def generate_images(
    image_request: CreateImagenDto,
    current_user: UserModel = Depends(get_current_user),
):
    # Step 1: get_current_user handles authentication
    # Step 2: RoleChecker validates USER or ADMIN role (implicit)
    # Step 3: workspace_auth_service.authorize checks workspace membership
    # Step 4: ImagenService.start_image_generation_job creates content
```

---

## Permission Escalation

### Request Higher System Role
- Ask a **System ADMIN**
- Requires justification
- Common for: template creators (CREATOR role)

### Request Higher Workspace Role
- Ask **Workspace ADMIN** or **OWNER**
- Instant access (no admin approval needed)
- Common for: promoting VIEWER to EDITOR

---

## Security Principles

### Principle of Least Privilege
- Users get minimum required access
- New users default to USER role
- Admins grant escalated access only when needed

### Defense in Depth
- Authentication at API boundary
- Authorization at endpoint level
- Database-level role enforcement
- Workspace membership verification

### Audit Trail
- All role changes logged (when audit logging implemented)
- Access to restricted resources logged
- Failed authorization attempts logged

---

## For More Information

- **Complete Role Guide**: [02_USER_ROLES_AND_PERMISSIONS.md](02_USER_ROLES_AND_PERMISSIONS.md)
  - Detailed capability matrix
  - Real-world scenarios
  - Troubleshooting guide

- **Authentication**: [../03-backend/AUTHENTICATION.md](../03-backend/AUTHENTICATION.md)
  - Token verification details
  - JIT provisioning
  - Organization filtering

- **API Security**: [../03-backend/02_API_ENDPOINTS_REFERENCE.md](../03-backend/02_API_ENDPOINTS_REFERENCE.md)
  - Protected endpoint examples
  - Error responses
  - Rate limiting

---

**Document Status**: Complete
**Last Updated**: December 15, 2025
