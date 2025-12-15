# Firestore Security Rules & Access Control

## Overview

Firestore security rules control read/write access to the database. Creative Studio uses a combination of document-level security rules and server-side authorization checks in the backend.

**Security Model**:
- **Authentication**: Firebase Authentication (tokens verified by rules)
- **Authorization**: Role-based access control (RBAC)
- **Workspace Isolation**: Data partitioned by workspace
- **User Isolation**: Users can only access their own data (by default)

---

## Table of Contents

1. [Security Rules Overview](#security-rules-overview)
2. [Users Collection](#users-collection)
3. [Media Library Collection](#media-library-collection)
4. [Workspaces Collection](#workspaces-collection)
5. [Source Assets Collection](#source-assets-collection)
6. [Brand Guidelines Collection](#brand-guidelines-collection)
7. [Media Templates Collection](#media-templates-collection)
8. [Admin Access](#admin-access)
9. [Testing Security Rules](#testing-security-rules)
10. [Common Patterns](#common-patterns)

---

## Security Rules Overview

### File Location

**File**: `firestore.rules` (root of repository)

```
project-root/
├── backend/
├── frontend/
└── firestore.rules          # Security rules file
```

### Deployment

```bash
# Deploy firestore rules
firebase deploy --only firestore:rules

# Validate rules without deploying
firebase deploy --only firestore:rules --dry-run

# Rollback to previous version
firebase deploy --only firestore:rules --version=<version-id>
```

### Rule Structure

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Collections and rules here
  }
}
```

---

## Users Collection

### Purpose
Store user profiles and roles.

### Rule Configuration

```firestore
match /users/{userId} {
  // Users can only read/write their own document
  allow read: if request.auth.uid == userId;
  allow create: if request.auth.uid == userId
    && request.resource.data.email == request.auth.token.email;
  allow update: if request.auth.uid == userId
    && request.resource.data.email == resource.data.email; // Email immutable
  allow delete: if false; // Never delete users
}
```

### Document Structure

```json
{
  "users": {
    "firebase-uid-123": {
      "email": "user@example.com",
      "display_name": "John Doe",
      "avatar_uri": "https://...",
      "roles": ["viewer"],
      "workspace_id": "ws-123",
      "created_at": "2025-01-15T10:30:00Z",
      "last_login": "2025-01-15T14:30:00Z"
    }
  }
}
```

### Rules Explanation

**Read Rule**:
```
allow read: if request.auth.uid == userId;
```
- Users can only read their own profile
- Backend verifies user can access other users' workspace

**Create Rule**:
```
allow create: if request.auth.uid == userId
  && request.resource.data.email == request.auth.token.email;
```
- User creates their own document
- Email must match Firebase token (Just-In-Time provisioning)
- Prevents users from creating fake accounts

**Update Rule**:
```
allow update: if request.auth.uid == userId
  && request.resource.data.email == resource.data.email;
```
- Users can update their profile
- Email cannot be changed (immutable)

---

## Media Library Collection

### Purpose
Store generated media (images, videos, audio) with ownership and workspace context.

### Rule Configuration

```firestore
match /media_library/{mediaId} {
  // Read: User owns the media OR is admin in workspace
  allow read: if isOwner()
    || hasWorkspaceRole(resource.data.workspace_id, ['admin', 'editor']);

  // Create: Authenticated user creating their own media
  allow create: if request.auth.uid != null
    && request.resource.data.user_email == request.auth.token.email
    && request.resource.data.status in ['pending', 'success', 'failed']
    && request.resource.data.created_at == request.time;

  // Update: Owner or workspace admin
  allow update: if isOwner()
    || hasWorkspaceRole(resource.data.workspace_id, ['admin'])
    && request.resource.data.gcs_uri == resource.data.gcs_uri; // URI immutable

  // Delete: Owner or workspace admin
  allow delete: if isOwner()
    || hasWorkspaceRole(resource.data.workspace_id, ['admin']);

  // Helper functions (defined below)
}
```

### Document Structure

```json
{
  "media_library": {
    "media-abc123": {
      "user_email": "user@example.com",
      "workspace_id": "ws-123",
      "type": "image",
      "model": "imagen-3-fast",
      "prompt": "A beautiful sunset",
      "status": "success",
      "gcs_uri": "gs://bucket/media/image-123.png",
      "mime_type": "image/png",
      "metadata": {
        "width": 1024,
        "height": 1024
      },
      "created_at": "2025-01-15T10:30:00Z",
      "completed_at": "2025-01-15T10:31:15Z"
    }
  }
}
```

### Complex Queries

**User's Media with Filters**:
```javascript
db.collection('media_library')
  .where('user_email', '==', currentUserEmail)
  .where('status', '==', 'success')
  .orderBy('created_at', 'desc')
  .limit(20)
  .get();
```

**Workspace Media (Admins)**:
```javascript
db.collection('media_library')
  .where('workspace_id', '==', workspaceId)
  .orderBy('created_at', 'desc')
  .get();
```

**Required Indexes**:
```
Collection: media_library
  1. user_email (ASC), created_at (DESC)
  2. workspace_id (ASC), created_at (DESC)
  3. status (ASC), created_at (DESC)
```

---

## Workspaces Collection

### Purpose
Store workspaces and member information for collaboration.

### Rule Configuration

```firestore
match /workspaces/{workspaceId} {
  // Read: Workspace member
  allow read: if isMember(workspaceId);

  // Create: Any authenticated user
  allow create: if request.auth.uid != null
    && request.resource.data.owner_id == request.auth.uid
    && isValidWorkspaceStructure();

  // Update: Workspace admin only
  allow update: if hasRole(workspaceId, 'admin')
    && request.resource.data.owner_id == resource.data.owner_id; // Owner immutable

  // Delete: Workspace owner only
  allow delete: if request.auth.uid == resource.data.owner_id;

  // Nested: Members subcollection
  match /members/{memberId} {
    allow read: if isMember(workspaceId);
    allow create: if hasRole(workspaceId, 'admin');
    allow update: if hasRole(workspaceId, 'admin')
      && request.resource.data.user_id == resource.data.user_id; // User immutable
    allow delete: if hasRole(workspaceId, 'admin');
  }
}
```

### Document Structure

```json
{
  "workspaces": {
    "ws-123": {
      "name": "My Workspace",
      "owner_id": "user-123",
      "members": [
        {
          "user_id": "user-123",
          "role": "admin",
          "joined_at": "2025-01-01T00:00:00Z"
        },
        {
          "user_id": "user-456",
          "role": "editor",
          "joined_at": "2025-01-10T00:00:00Z"
        }
      ],
      "settings": {
        "brand_color": "#0066cc",
        "theme": "light"
      },
      "created_at": "2025-01-01T00:00:00Z"
    }
  }
}
```

---

## Source Assets Collection

### Purpose
Store user-uploaded reference assets and media files.

### Rule Configuration

```firestore
match /source_assets/{assetId} {
  // Read: Workspace members can read assets
  allow read: if isMember(resource.data.workspace_id);

  // Create: User uploads asset to their workspace
  allow create: if request.auth.uid != null
    && request.auth.uid == request.resource.data.user_id
    && isMember(request.resource.data.workspace_id);

  // Update: Asset creator only (metadata changes)
  allow update: if request.auth.uid == resource.data.user_id
    && request.resource.data.gcs_uri == resource.data.gcs_uri; // URI immutable

  // Delete: Asset creator or workspace admin
  allow delete: if request.auth.uid == resource.data.user_id
    || hasRole(resource.data.workspace_id, 'admin');
}
```

### Document Structure

```json
{
  "source_assets": {
    "asset-xyz789": {
      "workspace_id": "ws-123",
      "user_id": "user-123",
      "asset_type": "reference-image",
      "mime_type": "image/jpeg",
      "gcs_uri": "gs://bucket/assets/file-123.jpg",
      "file_hash": "sha256-abc123...",
      "name": "My Reference Image",
      "created_at": "2025-01-15T10:30:00Z"
    }
  }
}
```

---

## Brand Guidelines Collection

### Purpose
Store workspace brand guidelines and extracted content.

### Rule Configuration

```firestore
match /brand_guidelines/{guidelineId} {
  // Read: Workspace members
  allow read: if isMember(resource.data.workspace_id);

  // Create: Workspace editor+
  allow create: if request.auth.uid != null
    && hasRole(request.resource.data.workspace_id, ['admin', 'editor'])
    && request.resource.data.status == 'processing';

  // Update: Admin only (for processing results)
  allow update: if hasRole(resource.data.workspace_id, 'admin')
    && request.resource.data.gcs_uri == resource.data.gcs_uri; // URI immutable

  // Delete: Workspace admin only
  allow delete: if hasRole(resource.data.workspace_id, 'admin');
}
```

### Document Structure

```json
{
  "brand_guidelines": {
    "brand-abc123": {
      "workspace_id": "ws-123",
      "gcs_uri": "gs://bucket/guidelines/brand.pdf",
      "extracted_text": "Color Palette: Primary colors are...",
      "summary": "Brand guidelines covering colors, typography...",
      "status": "ready",
      "created_at": "2025-01-15T10:30:00Z",
      "processed_at": "2025-01-15T10:35:00Z"
    }
  }
}
```

---

## Media Templates Collection

### Purpose
Store generation templates for quick media creation.

### Rule Configuration

```firestore
match /media_templates/{templateId} {
  // Read: All authenticated users
  allow read: if request.auth.uid != null;

  // Create: Workspace admin
  allow create: if request.auth.uid != null
    && hasRole(request.resource.data.workspace_id, 'admin');

  // Update: Workspace admin
  allow update: if hasRole(resource.data.workspace_id, 'admin');

  // Delete: Workspace admin
  allow delete: if hasRole(resource.data.workspace_id, 'admin');
}
```

### Document Structure

```json
{
  "media_templates": {
    "template-abc123": {
      "workspace_id": "ws-123",
      "name": "Product Photography",
      "category": "product",
      "model": "imagen-3-fast",
      "prompt_template": "A professional product photo of {{product}} on a white background",
      "variables": [
        {
          "name": "product",
          "required": true
        }
      ],
      "created_at": "2025-01-15T10:30:00Z"
    }
  }
}
```

---

## Admin Access

### Admin Collection

For admin-only operations, create an admin-only collection:

```firestore
match /admin/{document=**} {
  // Only allow admins (custom claim)
  allow read, write: if request.auth.token.admin == true;
}
```

### Global Admin Operations

```firestore
// Override for specific operations
match /users/{userId} {
  allow read: if request.auth.uid == userId
    || request.auth.token.admin == true; // Admins can read all users
}

match /media_library/{mediaId} {
  allow read: if isOwner()
    || hasWorkspaceRole(resource.data.workspace_id, ['admin'])
    || request.auth.token.admin == true; // Global admins
}
```

---

## Testing Security Rules

### Unit Tests

**File**: `firestore.test.ts`

```typescript
import * as firebase from '@firebase/rules-unit-testing';

const projectId = 'your-project-id';
let db: any;

beforeEach(async () => {
  // Load rules
  await firebase.loadFirestoreRules({
    projectId,
    rules: fs.readFileSync('firestore.rules', 'utf8'),
  });

  db = firebase.initializeTestApp({
    projectId,
    auth: { uid: 'user123', email: 'user@example.com' },
  }).firestore();
});

afterEach(async () => {
  await firebase.clearFirestoreData({ projectId });
});

describe('User collection rules', () => {
  test('users can read their own document', async () => {
    const ref = db.collection('users').doc('user123');
    await expect(ref.get()).resolves.toBeDefined();
  });

  test('users cannot read other user documents', async () => {
    const ref = db.collection('users').doc('other-user');
    await expect(ref.get()).rejects.toThrow('Missing or insufficient permissions');
  });

  test('users can create their own profile', async () => {
    const ref = db.collection('users').doc('user123');
    await expect(
      ref.set({
        email: 'user@example.com',
        display_name: 'John Doe',
      })
    ).resolves.toBeDefined();
  });
});

describe('Media library rules', () => {
  test('users can create media for themselves', async () => {
    const ref = db.collection('media_library').doc('media123');
    await expect(
      ref.set({
        user_email: 'user@example.com',
        status: 'pending',
        created_at: firebase.firestore.Timestamp.now(),
      })
    ).resolves.toBeDefined();
  });

  test('users cannot create media for others', async () => {
    const ref = db.collection('media_library').doc('media123');
    await expect(
      ref.set({
        user_email: 'other@example.com', // Different user
        status: 'pending',
      })
    ).rejects.toThrow();
  });
});
```

### Manual Testing

```bash
# Test rules locally with emulator
firebase emulators:start --only firestore

# In another terminal, run test suite
npm test

# Deploy to staging first
firebase deploy --only firestore:rules --project staging
```

---

## Common Patterns

### Pattern 1: User-Only Access

```firestore
match /documents/{docId} {
  allow read, write: if request.auth.uid == resource.data.user_id;
}
```

### Pattern 2: Workspace-Based Access

```firestore
match /documents/{docId} {
  allow read, write: if isMember(resource.data.workspace_id);
}
```

### Pattern 3: Role-Based Access

```firestore
match /documents/{docId} {
  allow read: if hasRole(resource.data.workspace_id, ['admin', 'editor']);
  allow write: if hasRole(resource.data.workspace_id, 'admin');
}
```

### Pattern 4: Immutable Fields

```firestore
allow update: if request.resource.data.user_id == resource.data.user_id
  && request.resource.data.created_at == resource.data.created_at
  && request.resource.data.gcs_uri == resource.data.gcs_uri;
```

### Pattern 5: Status-Based Access

```firestore
match /operations/{opId} {
  allow read: if resource.data.status in ['completed', 'failed']
    || request.auth.uid == resource.data.user_id;
}
```

---

## Helper Functions

### Complete Security Rules File

**File**: `firestore.rules`

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isAuthenticated() {
      return request.auth.uid != null;
    }

    function isOwner(userId) {
      return request.auth.uid == userId;
    }

    function isMember(workspaceId) {
      return get(/databases/$(database)/documents/workspaces/$(workspaceId))
        .data.members.any(m, m.user_id == request.auth.uid);
    }

    function hasRole(workspaceId, roles) {
      let workspace = get(/databases/$(database)/documents/workspaces/$(workspaceId));
      let member = workspace.data.members[
        workspace.data.members.findindex(m, m.user_id == request.auth.uid)
      ];
      return member.role in roles;
    }

    function hasWorkspaceRole(workspaceId, roles) {
      return isMember(workspaceId) && hasRole(workspaceId, roles);
    }

    function isAdmin() {
      return request.auth.token.admin == true;
    }

    function isValidWorkspaceStructure() {
      let data = request.resource.data;
      return data.keys().hasAll(['name', 'owner_id', 'created_at']);
    }

    // Collections
    match /users/{userId} {
      allow read: if isOwner(userId) || isAdmin();
      allow create: if isOwner(userId)
        && request.resource.data.email == request.auth.token.email;
      allow update: if isOwner(userId)
        && request.resource.data.email == resource.data.email;
      allow delete: if false;
    }

    match /media_library/{mediaId} {
      allow read: if isOwner(resource.data.user_id)
        || hasWorkspaceRole(resource.data.workspace_id, ['admin', 'editor', 'viewer'])
        || isAdmin();
      allow create: if isAuthenticated()
        && request.resource.data.user_email == request.auth.token.email
        && request.resource.data.status in ['pending', 'success', 'failed']
        && request.resource.data.created_at == request.time;
      allow update: if isOwner(resource.data.user_id)
        || hasWorkspaceRole(resource.data.workspace_id, ['admin'])
        && request.resource.data.gcs_uri == resource.data.gcs_uri;
      allow delete: if isOwner(resource.data.user_id)
        || hasWorkspaceRole(resource.data.workspace_id, ['admin']);
    }

    match /workspaces/{workspaceId} {
      allow read: if isMember(workspaceId) || isAdmin();
      allow create: if isAuthenticated()
        && request.resource.data.owner_id == request.auth.uid
        && isValidWorkspaceStructure();
      allow update: if hasRole(workspaceId, 'admin')
        && request.resource.data.owner_id == resource.data.owner_id;
      allow delete: if isOwner(resource.data.owner_id);

      match /members/{memberId} {
        allow read: if isMember(workspaceId) || isAdmin();
        allow create: if hasRole(workspaceId, 'admin');
        allow update: if hasRole(workspaceId, 'admin')
          && request.resource.data.user_id == resource.data.user_id;
        allow delete: if hasRole(workspaceId, 'admin');
      }
    }

    match /source_assets/{assetId} {
      allow read: if isMember(resource.data.workspace_id) || isAdmin();
      allow create: if isOwner(request.resource.data.user_id)
        && isMember(request.resource.data.workspace_id);
      allow update: if isOwner(resource.data.user_id)
        && request.resource.data.gcs_uri == resource.data.gcs_uri;
      allow delete: if isOwner(resource.data.user_id)
        || hasRole(resource.data.workspace_id, 'admin');
    }

    match /brand_guidelines/{guidelineId} {
      allow read: if isMember(resource.data.workspace_id) || isAdmin();
      allow create: if hasRole(request.resource.data.workspace_id, ['admin', 'editor']);
      allow update: if hasRole(resource.data.workspace_id, 'admin')
        && request.resource.data.gcs_uri == resource.data.gcs_uri;
      allow delete: if hasRole(resource.data.workspace_id, 'admin');
    }

    match /media_templates/{templateId} {
      allow read: if isAuthenticated();
      allow create: if hasRole(request.resource.data.workspace_id, 'admin');
      allow update: if hasRole(resource.data.workspace_id, 'admin');
      allow delete: if hasRole(resource.data.workspace_id, 'admin');
    }
  }
}
```

---

## Security Checklist

- [ ] All collections have explicit allow/deny rules
- [ ] User-owned data only accessible by owner
- [ ] Workspace-based access uses membership checks
- [ ] Admin-only operations have role checks
- [ ] Sensitive fields are immutable (user_id, created_at, etc.)
- [ ] Created timestamps always validated
- [ ] Rules tested with unit tests
- [ ] Rules deployed to staging first
- [ ] Rules reviewed by security team
- [ ] Firestore audit logging enabled
- [ ] Backup policies configured
- [ ] Regular security rule audits scheduled

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Applies To**: Firestore database security
- **Related Docs**: AUTH_IMPLEMENTATION.md, INFRASTRUCTURE.md, DATA_FLOW.md
