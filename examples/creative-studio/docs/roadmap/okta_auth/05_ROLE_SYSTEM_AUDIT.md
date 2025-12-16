# Role System Audit & Design Document
## Creative Studio Authentication - Role Definitions Inconsistency

**Version**: 1.0
**Date**: December 16, 2025
**Status**: Critical Issue Identified - REQUIRES CLARIFICATION
**Priority**: HIGH

---

## Executive Summary

🚨 **CRITICAL ISSUE FOUND**: The role system has **3 conflicting definitions** across different parts of the codebase:

### The Problem

| Source | Roles Defined | Status |
|--------|---------------|--------|
| **Your Proposed** | `cs_login`, `cs_user`, `cs_creator`, `cs_admin` | ❓ New proposal |
| **Backend Source Code** | `user`, `creator`, `admin` | ✅ Actual implementation |
| **Authentication Docs** | `viewer`, `editor`, `admin` (workspace-level) | ⚠️ Workspace-only, not system-level |
| **User Roles Docs** | System-level: `user`, `creator`, `admin` + Workspace-level: `viewer`, `editor`, `admin`, `owner` | ⚠️ Mixed/incomplete |

**No `cs_login` role exists anywhere in the codebase.**

---

## Part 1: Current Role System Analysis

### What Actually Exists in Code

**File**: `backend/src/users/user_model.py`

```python
class UserRoleEnum(str, Enum):
    """
    Defines the distinct roles a user can have within the application,
    enabling role-based access control.
    """

    USER = "user"          # Basic access to browse and use public features.
    CREATOR = "creator"    # Can create and manage their own content.
    ADMIN = "admin"        # Has full administrative privileges, including user management.
```

**Current System-Level Roles** (Actually Implemented):
1. ✅ `user` - Basic access
2. ✅ `creator` - Create templates/content
3. ✅ `admin` - Full system access

**Key Points**:
- Only 3 system-level roles
- No `cs_login` role
- No `cs_` prefix
- Stored in PostgreSQL `users.roles` column (ARRAY of strings)
- Default role: `user` (assigned on first login via JIT provisioning)

---

### Your Proposed Roles

```
cs_login   → Required to login (DOES NOT EXIST)
cs_user    → Basic permission (maps to: user)
cs_creator → Create projects (maps to: creator)
cs_admin   → Super user (maps to: admin)
```

**Analysis**:
- ❌ `cs_login` - **Not needed, everyone who logs in is already authenticated via Firebase**
- ✅ `cs_user` - Maps to existing `user` role
- ✅ `cs_creator` - Maps to existing `creator` role
- ✅ `cs_admin` - Maps to existing `admin` role

---

## Part 2: Where the Confusion Comes From

### 1. System-Level vs Workspace-Level Roles

Creative Studio has **TWO TIERS** of roles:

#### Tier 1: System-Level Roles (in PostgreSQL users table)
```python
USER      → Can access the app
CREATOR   → Can create templates
ADMIN     → Can manage everything
```

**Where they're used**: Global permissions, system administration

#### Tier 2: Workspace-Level Roles (in PostgreSQL workspace_members table)
```python
VIEWER    → Read-only access to workspace
EDITOR    → Can create/edit/delete media
ADMIN     → Can manage workspace (members, settings)
OWNER     → Can delete workspace, transfer ownership
```

**Where they're used**: Per-workspace permissions, collaboration

### Documentation Mismatch

**File**: `docs/05-security/02_USER_ROLES_AND_PERMISSIONS.md`

Describes BOTH tiers, but:
- ✅ System-level roles: `user`, `creator`, `admin` (correct)
- ⚠️ Workspace roles: `viewer`, `editor`, `admin`, `owner` (correct, but these are DIFFERENT from system-level)

**Problem**: Documentation is correct but doesn't match your proposed names!

### Authentication Flow Documentation

**File**: `docs/03-backend/03_AUTHENTICATION_FLOW.md`

Shows workspace-level roles (`viewer`, `editor`, `admin`) but **was not updated** when system-level roles were renamed or clarified.

---

## Part 3: The `cs_login` Role Issue

### What is `cs_login` for?

Your proposal suggests:
> "cs_login - Creative studio login, required to login"

**Analysis**: This role is **NOT NEEDED** because:

1. **Firebase handles authentication**, not the app
   - Users log in via Firebase (Google, Okta, etc.)
   - Firebase returns a valid JWT token
   - Backend validates token with Firebase Admin SDK

2. **Every authenticated user is already authorized**
   - If user can sign in to Firebase, they CAN access the app
   - The `user` role is the DEFAULT and is automatically assigned

3. **Current flow**:
   ```
   1. User signs in via Firebase → Firebase verifies identity
   2. Backend receives Firebase token → Validates with Admin SDK
   3. JIT provisioning creates user in PostgreSQL → Assigns `user` role
   4. User can now use the app

   NO SEPARATE LOGIN ROLE NEEDED!
   ```

4. **If you wanted to restrict access**, you'd use:
   - ✅ A **blocklist** (revoked users, suspended accounts)
   - ✅ A **permission check** (must have `user` role - already exists)
   - ❌ NOT a separate `cs_login` role

---

## Part 4: What Should Happen Instead

### Option A: Keep Current System (RECOMMENDED) ✅

**Keep the existing roles exactly as they are**:
- `user` - Basic access
- `creator` - Create templates
- `admin` - Full access

**Why**:
- ✅ Already implemented in code
- ✅ Works with current JIT provisioning
- ✅ Documented in source code
- ✅ Simple and clear
- ✅ No migration needed

**Updates needed**:
- Fix documentation to match code (change "viewer/editor/admin" in auth docs to clarify they're workspace-only)
- Remove confusion about two-tier system

---

### Option B: Rename with `cs_` Prefix (NOT RECOMMENDED)

**Rename to your proposed names**:
- `cs_user` (was: `user`)
- `cs_creator` (was: `creator`)
- `cs_admin` (was: `admin`)
- ~~`cs_login`~~ (DELETE - not needed)

**Why I don't recommend**:
- ❌ Requires database migration
- ❌ Requires code changes across all files
- ❌ Doesn't actually improve functionality
- ❌ Just adds "cs_" prefix unnecessarily
- ❌ Breaks existing integrations

**If you MUST rename**:
- Database migration: `UPDATE users SET roles = ARRAY['cs_user'] WHERE roles = ARRAY['user']`
- Code changes: ~15 files in backend
- Update Firebase custom claims
- Effort: 4-6 hours

---

### Option C: Three-Tier System (For Future Enterprise)

If you want more granular control:

```python
class SystemRoleEnum(str, Enum):
    """System-level access"""
    GUEST      → No login (site visitors)
    USER       → Basic authenticated user
    CREATOR    → Can create system-level content
    ADMIN      → Full system administration

class WorkspaceRoleEnum(str, Enum):
    """Workspace-level access"""
    VIEWER     → Read-only
    EDITOR     → Full creation/editing
    ADMIN      → Manage workspace
    OWNER      → Delete/transfer
```

**But this requires**:
- Rethinking entire system
- Adding GUEST role (for unauthenticated users - currently not supported)
- Database schema changes
- Major refactoring

**Not recommended** unless you have specific enterprise requirements.

---

## Part 5: Clarified Role Definitions

### System-Level Roles (What Actually Exists)

#### 1. 👤 `user` (System Role)

**Database**: Stored in `users.roles` ARRAY column

**Current Definition in Code**:
> "Basic access to browse and use public features"

**Clarified Definition**:
- ✅ Can authenticate/log in
- ✅ Can view own profile
- ✅ Can browse public workspaces
- ✅ Can access assigned workspaces (if they're a member)
- ✅ Can generate images/videos/audio (if workspace editor)
- ✅ Can create source assets (if workspace editor)
- ❌ Cannot create system-level templates
- ❌ Cannot manage other users
- ❌ Cannot configure system settings

**API Endpoints Accessible**:
```
POST /api/images/generate-images      ✅ (with workspace editor role)
POST /api/videos/generate-videos      ✅ (with workspace editor role)
POST /api/audios/generate             ✅ (with workspace editor role)
GET  /api/galleries                   ✅ (with workspace access)
POST /api/source-assets/upload        ✅ (with workspace editor role)
GET  /api/workspaces                  ✅ (own workspaces only)
```

**Default on First Login**: ✅ YES (assigned automatically via JIT)

**Who Gets This Role**: All new authenticated users

---

#### 2. 🎨 `creator` (System Role)

**Database**: Stored in `users.roles` ARRAY column

**Current Definition in Code**:
> "Can create and manage their own content"

**Clarified Definition**:
- ✅ All permissions of `user` role
- ✅ Can create system-level media templates
- ✅ Can manage own system-level templates
- ✅ Can share templates with workspaces
- ❌ Cannot delete other users' templates
- ❌ Cannot manage system settings
- ❌ Cannot manage users

**API Endpoints Accessible**:
```
POST /api/media-templates             ✅ (create new templates)
PUT  /api/media-templates/{id}        ✅ (edit own templates)
DELETE /api/media-templates/{id}      ✅ (delete own templates only)
```

**Default on First Login**: ❌ NO (must be manually assigned)

**Who Gets This Role**: Content creators, design leads, power users

---

#### 3. 👑 `admin` (System Role)

**Database**: Stored in `users.roles` ARRAY column

**Current Definition in Code**:
> "Has full administrative privileges, including user management"

**Clarified Definition**:
- ✅ All permissions of `user` and `creator` roles
- ✅ Can manage all users (view, update, assign roles)
- ✅ Access all workspaces (bypasses membership check)
- ✅ Can create/edit/delete any template
- ✅ Can delete any media or assets
- ✅ Can configure system settings
- ✅ Can bypass workspace-level restrictions
- ✅ Can view audit logs

**Code Shows**:
```python
# backend/src/workspaces/workspace_auth_guard.py
is_admin = UserRoleEnum.ADMIN in user.roles

if not (is_admin or is_public):
    # Check if user is a member
    is_member = await workspace_repo.is_member(workspace_id, user.id)
    if not is_member:
        raise HTTPException(status_code=403)
```

**Translation**: Admins skip workspace membership checks!

**API Endpoints Accessible**:
```
GET    /api/users                     ✅ (list all users)
POST   /api/users/{id}/roles          ✅ (assign roles)
DELETE /api/media-templates/{id}      ✅ (delete any template)
DELETE /api/galleries/{id}            ✅ (delete any media)
[All workspace admin endpoints]        ✅
```

**Default on First Login**: ❌ NO (must be manually assigned)

**Who Gets This Role**: System administrators, platform operators

---

### Workspace-Level Roles (Separate Tier)

These are DIFFERENT from system-level roles. Used for per-workspace permissions.

#### 👁️ `viewer` (Workspace Role)
- Read-only access to workspace
- Cannot create or modify content

#### ✏️ `editor` (Workspace Role)
- Can generate images/videos, upload assets
- Can delete own content
- Cannot change workspace settings

#### 🔧 `admin` (Workspace Role)
- Can delete any content
- Can invite/remove members
- Can change member roles
- Can edit workspace settings
- Cannot delete workspace or transfer ownership

#### 👨‍💼 `owner` (Workspace Role)
- Full control of workspace
- Can delete entire workspace
- Can transfer ownership

---

## Part 6: Complete Role Permission Matrix

### System-Level Permissions

| Action | user | creator | admin |
|--------|------|---------|-------|
| **View own profile** | ✅ | ✅ | ✅ |
| **Update own profile** | ✅ | ✅ | ✅ |
| **Access public workspaces** | ✅ | ✅ | ✅ |
| **Generate images** | ✅ (if workspace editor) | ✅ (if workspace editor) | ✅ |
| **Generate videos** | ✅ (if workspace editor) | ✅ (if workspace editor) | ✅ |
| **Generate audio** | ✅ (if workspace editor) | ✅ (if workspace editor) | ✅ |
| **Create system templates** | ❌ | ✅ | ✅ |
| **Delete own templates** | ❌ | ✅ | ✅ |
| **Delete any template** | ❌ | ❌ | ✅ |
| **View users list** | ❌ | ❌ | ✅ |
| **Assign user roles** | ❌ | ❌ | ✅ |
| **Access all workspaces** | ❌ | ❌ | ✅ |
| **View system settings** | ❌ | ❌ | ✅ |
| **Login to system** | ✅ (default) | ✅ | ✅ |

---

## Part 7: Database Implementation

### Current PostgreSQL Schema

```sql
-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR UNIQUE NOT NULL,
    roles VARCHAR[] DEFAULT ARRAY['user']::VARCHAR[],  -- Array of role strings
    name VARCHAR DEFAULT '',
    picture VARCHAR DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Example data:
INSERT INTO users (email, roles, name) VALUES
    ('user1@example.com', ARRAY['user'], 'User One'),
    ('creator1@example.com', ARRAY['user', 'creator'], 'Creator One'),
    ('admin1@example.com', ARRAY['user', 'creator', 'admin'], 'Admin One');
```

**Note**: A user can have MULTIPLE roles (array). This allows:
- `['user']` - Basic user
- `['user', 'creator']` - User + creator capabilities
- `['user', 'creator', 'admin']` - Full permissions

### Firebase Custom Claims

When setting custom claims (optional):
```python
firebase_admin_service.set_custom_claims(user_uid, {
    'roles': ['user', 'creator'],
    'provisioned_at': datetime.utcnow().isoformat(),
})
```

These appear in the JWT token, but **PostgreSQL is source of truth**.

---

## Part 8: JIT Provisioning Default Roles

### Current Flow

```python
# backend/src/services/user_service.py
async def get_or_create_user(self, decoded_token: dict) -> UserModel:
    # ... (check if user exists)

    # Create new user with DEFAULT ROLE
    user_data = {
        'email': user_email,
        'display_name': decoded_token.get('name', ''),
        'roles': ['user'],  # <- HARDCODED DEFAULT!
        # ...
    }

    await self.firestore.set_document('users', user_uid, user_data)
```

**Default role on first login**: `user`

**This is correct** because:
- ✅ Everyone should start as a basic user
- ✅ Admins can then assign `creator` or `admin` roles
- ✅ No need for a separate `cs_login` role

---

## Part 9: Recommendations & Next Steps

### ✅ RECOMMENDED: Use Existing Roles

**Keep the system as-is**:
- System roles: `user`, `creator`, `admin`
- Workspace roles: `viewer`, `editor`, `admin`, `owner`
- No `cs_login` role

**Update documentation only**:
1. **Fix `docs/03-backend/03_AUTHENTICATION_FLOW.md`**:
   - Section "Role Definitions" currently shows workspace roles (`viewer`, `editor`, `admin`)
   - Should clarify: "Workspace-level roles; see 02_USER_ROLES_AND_PERMISSIONS.md for system-level roles"

2. **Verify `docs/05-security/02_USER_ROLES_AND_PERMISSIONS.md`**:
   - ✅ Already has system-level roles correct
   - ✅ Already has workspace-level roles correct
   - Update: Add note that system roles are GLOBAL, workspace roles are LOCAL

3. **Create simple reference**:
   - One-page quick reference: "System Roles vs Workspace Roles"

**Time to implement**: 2 hours (documentation updates only)

---

### ❌ NOT RECOMMENDED: Rename with `cs_` Prefix

**Reason**: Adds complexity without benefit

**If you insist, here's what's needed**:

1. **Database migration**:
```sql
BEGIN;

-- Update system-level roles
UPDATE users SET roles = array_replace(roles, 'user', 'cs_user');
UPDATE users SET roles = array_replace(roles, 'creator', 'cs_creator');
UPDATE users SET roles = array_replace(roles, 'admin', 'cs_admin');

COMMIT;
```

2. **Code changes** (~15 files):
   - `backend/src/users/user_model.py` - Update enum
   - `backend/src/*/controller.py` - Update role checks
   - `backend/src/*/service.py` - Update role assignments

3. **Delete `cs_login` entirely** - doesn't make sense

**Time to implement**: 4-6 hours

---

### ❓ CLARIFICATION NEEDED

**Questions for your team**:

1. **Why the `cs_` prefix?**
   - Just for clarity? (Better: use better documentation)
   - Namespace collision with another system? (What other system?)
   - Future multi-tenant? (Plan accordingly before implementing)

2. **Why `cs_login` role?**
   - Need to restrict who can login? (Use blocklist instead)
   - Need to track login vs non-login users? (Add boolean flag, not a role)
   - Something else? (Explain use case)

3. **Where did these role names come from?**
   - Customer requirement?
   - Design document?
   - Comparison with another system?

---

## Part 10: What Actually Exists vs What's Proposed

### Current Implementation (Code is Source of Truth)

```
✅ ACTUALLY IMPLEMENTED:
  └─ System-Level Roles:
     ├─ user (default on first login)
     ├─ creator (for template creation)
     └─ admin (for system administration)

  └─ Workspace-Level Roles:
     ├─ viewer (read-only)
     ├─ editor (create/edit/delete own)
     ├─ admin (manage workspace)
     └─ owner (delete/transfer)
```

### Your Proposed

```
❓ PROPOSED (NOT YET IMPLEMENTED):
  └─ System-Level Roles:
     ├─ cs_login (DO NOT DO THIS - not needed)
     ├─ cs_user (maps to current: user)
     ├─ cs_creator (maps to current: creator)
     └─ cs_admin (maps to current: admin)
```

### The Gap

| Feature | Current | Your Proposal | Recommendation |
|---------|---------|---------------|-----------------|
| **System-level roles** | ✅ Exist | Renamed but same | Keep as-is |
| **Workspace-level roles** | ✅ Exist | No mention | Keep as-is |
| **cs_login role** | ❌ Doesn't exist | New role | DELETE - not needed |
| **Role prefixing** | None | cs_ prefix | Not necessary |
| **Default role on login** | user | cs_user? | Keep: user |
| **Database impact** | Current ✅ | Migration required ❌ | No migration needed |
| **Documentation impact** | Current ⚠️ | Needs update ⚠️ | Update docs only |

---

## Part 11: Action Items

### Immediate (Today)

- [ ] Review this document with team
- [ ] Clarify: Do you want to rename roles or just document them?
- [ ] Clarify: What is `cs_login` supposed to do?
- [ ] Decision: Option A (document current) or Option B (rename + migrate)?

### If Option A (RECOMMENDED): Document Current

- [ ] Update `docs/03-backend/03_AUTHENTICATION_FLOW.md` - Section "Role Definitions"
- [ ] Add note: System vs workspace role clarification
- [ ] Create 1-page reference card
- [ ] No code changes
- [ ] No database migration

**Time**: 2 hours

### If Option B: Rename Roles

- [ ] Create database migration script
- [ ] Update `backend/src/users/user_model.py` enum
- [ ] Search all controllers/services for role checks (~15 files)
- [ ] Test all permission checks
- [ ] Update documentation
- [ ] Run migration in dev/staging/prod

**Time**: 4-6 hours

---

## Summary Table

| Question | Answer | Status |
|----------|--------|--------|
| **Are current roles properly described?** | Partially - code is clear, docs are incomplete | ⚠️ Needs docs update |
| **Should we add cs_login role?** | NO - not needed, everyone who logs in is authenticated | 🔴 Don't do this |
| **Should we rename with cs_ prefix?** | Not recommended, but possible if required | 🟡 Only if essential |
| **Are roles stored correctly in DB?** | YES - PostgreSQL ARRAY works well | ✅ Good |
| **Is JIT provisioning correct?** | YES - assigns `user` role by default | ✅ Good |
| **Is authentication flow correct?** | YES - Firebase handles auth, roles for authorization | ✅ Good |

---

## Conclusion

**Current system is well-designed**. The confusion is in documentation and the false requirement for `cs_login` role.

**Recommended action**:
1. Keep roles exactly as they are
2. Update documentation to clarify system vs workspace roles
3. Delete the `cs_login` concept entirely
4. Use existing `user`, `creator`, `admin` roles

**If external requirement mandates `cs_` prefix**:
- State it explicitly
- Plan 4-6 hour migration
- Update all affected files
- Test thoroughly

---

**Document Ready for Review**
**Questions?** See Part 9 for clarification needed from your team
