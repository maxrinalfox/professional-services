# Workspace Features & Collaboration Guide

## Overview

Workspaces enable teams to collaborate on creative projects together. Each workspace has its own media library, members, settings, and brand guidelines.

**Key Concepts**:
- **Workspace**: Isolated project/team context
- **Members**: Users with specific roles in the workspace
- **Permissions**: Role-based access control
- **Collaboration**: Shared media, templates, and guidelines

---

## Table of Contents

1. [Workspace Architecture](#workspace-architecture)
2. [Creating & Managing Workspaces](#creating--managing-workspaces)
3. [Member Management](#member-management)
4. [Workspace Isolation](#workspace-isolation)
5. [Shared Resources](#shared-resources)
6. [Permissions & Access Control](#permissions--access-control)
7. [Collaboration Workflows](#collaboration-workflows)
8. [Best Practices](#best-practices)

---

## Workspace Architecture

### Workspace Data Model

Core workspace data, including its name, owner, and members, is primarily stored in **Cloud SQL PostgreSQL** for strong relational integrity and transactional consistency. Firestore may be used for real-time synchronization of certain workspace metadata or user-specific settings within a workspace.

**PostgreSQL Table: `workspaces`**
```sql
CREATE TABLE workspaces (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR NOT NULL,
    owner_id INTEGER NOT NULL REFERENCES users(id),
    description TEXT,
    settings JSONB, -- JSONB for flexible settings
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

CREATE TABLE workspace_members (
    workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
    user_id INTEGER NOT NULL REFERENCES users(id),
    role VARCHAR NOT NULL,
    joined_at TIMESTAMP DEFAULT now(),
    PRIMARY KEY (workspace_id, user_id)
);
```

**Frontend Workspace Model (Simplified)**
```typescript
interface Workspace {
  id: string;
  name: string;
  description?: string;
  ownerId: string;
  members: WorkspaceMember[];
  settings: { [key: string]: any };
  createdAt: string;
  updatedAt: string;
}

interface WorkspaceMember {
  userId: string;
  userEmail: string;
  role: 'admin' | 'editor' | 'viewer';
  joinedAt: string;
}
```

### Workspace Hierarchy

```
User
  ↓
Default Workspace (auto-created)
  ├─ Media Library
  │  ├─ Images
  │  ├─ Videos
  │  └─ Audio
  ├─ Members
  │  ├─ Owner (admin)
  │  ├─ Team Members (editors)
  │  └─ Viewers
  ├─ Source Assets
  ├─ Brand Guidelines
  └─ Media Templates
```

---

## Creating & Managing Workspaces

### Create Workspace

**Frontend**:

```typescript
@Component({
  selector: 'app-create-workspace',
  template: `
    <mat-dialog-content>
      <form [formGroup]="workspaceForm">
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Workspace Name</mat-label>
          <input matInput formControlName="name" placeholder="My Project" />
        </mat-form-field>

        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Description</mat-label>
          <textarea
            matInput
            formControlName="description"
            placeholder="What is this workspace for?"
            rows="3"
          ></textarea>
        </mat-form-field>
      </form>
    </mat-dialog-content>

    <mat-dialog-actions>
      <button mat-button mat-dialog-close>Cancel</button>
      <button
        mat-button
        color="primary"
        (click)="createWorkspace()"
        [disabled]="!workspaceForm.valid"
      >
        Create
      </button>
    </mat-dialog-actions>
  `,
})
export class CreateWorkspaceDialogComponent {
  workspaceForm: FormGroup;

  constructor(
    private workspaceService: WorkspaceService,
    public dialogRef: MatDialogRef<CreateWorkspaceDialogComponent>,
    private fb: FormBuilder
  ) {
    this.workspaceForm = this.fb.group({
      name: ['', [Validators.required, Validators.minLength(3)]],
      description: [''],
    });
  }

  async createWorkspace(): Promise<void> {
    if (!this.workspaceForm.valid) return;

    try {
      const workspace = await this.workspaceService
        .createWorkspace(this.workspaceForm.value)
        .toPromise();

      this.dialogRef.close(workspace);
    } catch (error) {
      console.error('Failed to create workspace:', error);
    }
  }
}
```

**Backend**:

```python
@router.post('/api/workspaces')
async def create_workspace(
    request: CreateWorkspaceRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Create new workspace

    Args:
        name: Workspace name
        description: Optional description

    Returns:
        Created workspace with owner as member
    """
    workspace_service = WorkspaceService()

    workspace = await workspace_service.create_workspace(
        name=request.name,
        owner_id=current_user['uid'],
        description=request.description,
    )

    return {
        'success': True,
        'data': workspace.to_dict(),
    }
```

### Switch Workspace

**Frontend**:

```typescript
@Injectable({ providedIn: 'root' })
export class WorkspaceService {
  private currentWorkspaceSubject = new BehaviorSubject<Workspace | null>(null);
  public currentWorkspace$ = this.currentWorkspaceSubject.asObservable();

  /**
   * Get user's workspaces
   */
  getUserWorkspaces(): Observable<Workspace[]> {
    return this.http.get('/api/workspaces').pipe(
      map((response: any) => response.data)
    );
  }

  /**
   * Set current workspace
   */
  async setCurrentWorkspace(workspace: Workspace): Promise<void> {
    // Save to localStorage
    localStorage.setItem('currentWorkspaceId', workspace.id);
    this.currentWorkspaceSubject.next(workspace);

    // Reload gallery with new workspace
    // Update all workspace-dependent components
  }

  /**
   * Get current workspace
   */
  getCurrentWorkspace(): Observable<Workspace> {
    return this.currentWorkspace$.pipe(
      filter((ws) => ws !== null),
      take(1)
    );
  }
}
```

---

## Member Management

### Invite Member

**Frontend**:

```typescript
@Component({
  selector: 'app-workspace-members',
  templateUrl: './workspace-members.component.html',
})
export class WorkspaceMembersComponent implements OnInit {
  /**
   * Current workspace members
   */
  members$: Observable<WorkspaceMember[]>;

  /**
   * Invitation form
   */
  inviteForm: FormGroup;
  showInviteForm = false;

  constructor(
    private workspaceService: WorkspaceService,
    private fb: FormBuilder,
    private notificationService: NotificationService
  ) {
    this.inviteForm = this.fb.group({
      email: ['', [Validators.required, Validators.email]],
      role: ['editor', Validators.required],
    });
  }

  ngOnInit(): void {
    this.loadMembers();
  }

  /**
   * Load workspace members
   */
  loadMembers(): void {
    this.members$ = this.workspaceService.getWorkspaceMembers();
  }

  /**
   * Invite member
   */
  async inviteMember(): Promise<void> {
    if (!this.inviteForm.valid) return;

    const { email, role } = this.inviteForm.value;

    try {
      await this.workspaceService.inviteMember(email, role).toPromise();
      this.notificationService.showSuccess(`Invited ${email}`);
      this.inviteForm.reset();
      this.showInviteForm = false;
      this.loadMembers();
    } catch (error) {
      this.notificationService.showError('Failed to invite member');
    }
  }

  /**
   * Update member role
   */
  async updateMemberRole(userId: string, newRole: string): Promise<void> {
    try {
      await this.workspaceService.updateMemberRole(userId, newRole).toPromise();
      this.notificationService.showSuccess('Role updated');
      this.loadMembers();
    } catch (error) {
      this.notificationService.showError('Failed to update role');
    }
  }

  /**
   * Remove member
   */
  async removeMember(userId: string): Promise<void> {
    if (!confirm('Remove this member?')) return;

    try {
      await this.workspaceService.removeMember(userId).toPromise();
      this.notificationService.showSuccess('Member removed');
      this.loadMembers();
    } catch (error) {
      this.notificationService.showError('Failed to remove member');
    }
  }
}
```

**Backend**:

```python
@router.post('/api/workspaces/{workspace_id}/members')
async def invite_member(
    workspace_id: str,
    email: str,
    role: str = 'viewer',
    current_user: dict = Depends(get_current_user),
):
    """
    Invite user to workspace

    Args:
        email: User email
        role: admin, editor, or viewer

    Only workspace admins can invite members
    """
    workspace_service = WorkspaceService()

    # Verify user is workspace admin
    workspace = await workspace_service.get_workspace(workspace_id)
    user_role = workspace.get_user_role(current_user['uid'])

    if user_role != UserRoleEnum.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='Only workspace admins can invite members'
        )

    # Find user by email
    user_service = UserService()
    user = await user_service.find_by_email(email)

    if not user:
        # Create user if doesn't exist
        user = await user_service.create_from_email(email)

    # Add to workspace
    await workspace_service.add_member(
        workspace_id,
        user.id,
        email,
        UserRoleEnum(role)
    )

    logger.info(
        'Member invited to workspace',
        extra={
            'workspace_id': workspace_id,
            'invited_email': email,
            'role': role,
            'invited_by': current_user['email'],
        }
    )

    return {
        'success': True,
        'message': f'Invited {email} as {role}',
    }
```

### Manage Permissions

**Role Permissions Matrix**:

```
Action                          | Viewer | Editor | Admin
--------------------------------|--------|--------|-------
View media                      |   ✓    |   ✓    |   ✓
Search media                    |   ✓    |   ✓    |   ✓
View brand guidelines           |   ✓    |   ✓    |   ✓
View templates                  |   ✓    |   ✓    |   ✓
Create media                    |        |   ✓    |   ✓
Edit own media metadata         |        |   ✓    |   ✓
Delete own media                |        |   ✓    |   ✓
Create templates                |        |   ✓    |   ✓
Upload brand guidelines         |        |   ✓    |   ✓
Invite members                  |        |        |   ✓
Manage member roles             |        |        |   ✓
Delete other's media            |        |        |   ✓
Update workspace settings       |        |        |   ✓
Delete workspace                |        |        |   ✓
```

---

## Workspace Isolation

Workspace isolation is enforced at multiple levels to ensure data privacy and prevent unauthorized access:

### Data Partitioning (PostgreSQL & Firestore)

Core workspace data and relationships (e.g., `workspaces`, `workspace_members`, `media_items`, `source_assets`, `brand_guidelines`, `media_templates`) are partitioned by `workspace_id` in **Cloud SQL PostgreSQL**. This ensures that queries retrieve only data relevant to the current workspace.

```python
# Media library is isolated by workspace via PostgreSQL query
media_items = await session.execute(
    select(MediaItem).where(MediaItem.workspace_id == workspace_id)
)

# Source assets are isolated via PostgreSQL query
source_assets = await session.execute(
    select(SourceAsset).where(SourceAsset.workspace_id == workspace_id)
)

# Templates are isolated via PostgreSQL query
media_templates = await session.execute(
    select(MediaTemplate).where(MediaTemplate.workspace_id == workspace_id)
)
```

Firestore collections (such as `media_library`, `source_assets`, `media_templates`, `brand_guidelines`) may mirror or cache certain metadata for real-time synchronization with frontend clients. For data within Firestore, its security rules enforce `workspace_id` based isolation:

### Security Rules (Firestore)

Firestore rules enforce workspace isolation for documents stored within Firestore collections:

```firestore
match /media_library/{mediaId} {
  // Users can only read media from workspaces they're members of
  allow read: if isMember(resource.data.workspace_id);

  // Users can only create media in workspaces they're members of
  allow create: if isMember(request.resource.data.workspace_id);

  // Users can only delete their own media or if they're workspace admin
  allow delete: if isOwner(resource.data.user_id)
    || hasRole(resource.data.workspace_id, 'admin');
}
```

### Cross-Workspace Restrictions

- Users cannot see other workspace's data
- Tokens are workspace-aware (custom claims include workspace_id)
- API endpoints validate workspace membership against PostgreSQL before returning data

---

## Shared Resources

All members of a workspace share access to the same resources, with access governed by their assigned roles and permissions. The primary source of truth for these shared resources is **Cloud SQL PostgreSQL**, with some metadata potentially mirrored in Firestore for real-time updates or specific frontend queries.

### Shared Media Library

The media library (generation history, uploaded media) is shared among all workspace members. Access is controlled by backend service logic and PostgreSQL queries based on `workspace_id`.

```typescript
// All workspace members see the same gallery
this.gallery$ = this.http.get('/api/galleries', {
  params: { workspace_id: this.currentWorkspace.id }
});
```

### Shared Brand Guidelines

Brand guidelines are defined at the workspace level and are accessible to all members who have the appropriate permissions. The content (extracted text, color palettes) is stored in **PostgreSQL**.

```python
# Get workspace brand guidelines from PostgreSQL
guidelines = await session.execute(
    select(BrandGuideline).where(BrandGuideline.workspace_id == workspace_id)
)

# All generation requests in workspace can apply these guidelines
```

### Shared Templates

Custom prompt templates are created and shared within a workspace. These templates are stored in **PostgreSQL**.

```python
# Get workspace templates from PostgreSQL
templates = await session.execute(
    select(MediaTemplate).where(MediaTemplate.workspace_id == workspace_id)
)

# Template: "Product Photography" created by admin
# All workspace members can use it
```

### Shared Source Assets

Source assets (e.g., reference images for generation) uploaded within a workspace are accessible to all its members and stored in **PostgreSQL** (metadata) and **Cloud Storage** (files).

```python
# Assets available to all workspace members from PostgreSQL
assets = await session.execute(
    select(SourceAsset).where(SourceAsset.workspace_id == workspace_id)
)
```

---

## Permissions & Access Control

### Frontend Permission Checks

```typescript
/**
 * Check if user can perform action in workspace
 */
canCreateMedia(workspace: Workspace): boolean {
  return ['admin', 'editor'].includes(workspace.userRole);
}

canManageMembers(workspace: Workspace): boolean {
  return workspace.userRole === 'admin';
}

canDeleteMedia(workspace: Workspace, mediaOwnerId: string, currentUserId: string): boolean {
  return currentUserId === mediaOwnerId || workspace.userRole === 'admin';
}

canUploadBrandGuidelines(workspace: Workspace): boolean {
  return ['admin', 'editor'].includes(workspace.userRole);
}
```

### Backend Permission Checks

```python
async def check_workspace_permission(
    user_id: str,
    workspace_id: str,
    required_role: UserRoleEnum = UserRoleEnum.VIEWER,
) -> bool:
    """
    Verify user has permission in workspace

    Args:
        user_id: Firebase UID
        workspace_id: Workspace ID
        required_role: Minimum required role

    Returns:
        True if user has permission, False otherwise
    """
    workspace_service = WorkspaceService()
    workspace = await workspace_service.get_workspace(workspace_id)

    user_role = workspace.get_user_role(user_id)

    if not user_role:
        return False

    # Check role hierarchy
    role_hierarchy = {
        UserRoleEnum.VIEWER: 0,
        UserRoleEnum.EDITOR: 1,
        UserRoleEnum.ADMIN: 2,
    }

    return role_hierarchy[user_role] >= role_hierarchy[required_role]
```

---

## Collaboration Workflows

### Workflow: Create Campaign

```
1. Admin creates workspace: "Q1 Campaign"
   ↓
2. Admin invites team members (editors)
   ↓
3. Editors upload source images
   ↓
4. Admin creates brand guidelines
   ↓
5. Admin creates templates for campaign
   ↓
6. Editors use templates to generate variations
   ↓
7. All members view final gallery
   ↓
8. Admin archives workspace when complete
```

### Workflow: Peer Review

```
1. Editor creates media: "Product Shot 1"
   ↓
2. Media appears in gallery for all members
   ↓
3. Other editors can see and comment
   ↓
4. Admin approves for publication
```

### Workflow: Brand Consistency

```
1. Admin uploads brand guidelines PDF
   ↓
2. System extracts text and summarizes
   ↓
3. When editor generates image, can "Apply Brand Guidelines"
   ↓
4. Prompt is rewritten using Gemini + guidelines
   ↓
5. Generated image matches brand better
```

---

## Best Practices

### Workspace Organization

1. **One Workspace Per Project**
   - Each campaign/project gets its own workspace
   - Keeps data organized and isolated

2. **Naming Convention**
   ```
   [Client] - [Project] - [Season/Year]
   Example: "Nike - Spring Campaign - 2025"
   ```

3. **Archive Old Workspaces**
   - Delete/archive when project complete
   - Reduces clutter and data storage costs

### Member Management

1. **Principle of Least Privilege**
   - Start with viewer role
   - Upgrade to editor only when needed
   - Only one admin per workspace (or two for backup)

2. **Regular Reviews**
   - Monthly: Review who has access
   - Quarterly: Remove inactive members
   - Annually: Audit admin accounts

3. **Documentation**
   - Document member roles and responsibilities
   - Keep list of admins for handover

### Collaboration Best Practices

1. **Clear Brand Guidelines**
   - Upload complete brand guidelines early
   - Include: colors, fonts, imagery, tone
   - Update when brand changes

2. **Reusable Templates**
   - Create templates for common tasks
   - Document template purpose
   - Version templates with updates

3. **Source Asset Organization**
   - Use descriptive names
   - Organize by type (logo, color swatches, etc.)
   - Remove unused assets regularly

4. **Communication**
   - Use workspace name to explain purpose
   - Use description for project details
   - Consider using shared notes outside system

### Performance

1. **Pagination**
   - Gallery loads 20 items at a time
   - Use filters to narrow down results
   - Archive old workspaces to improve performance

2. **API Limits**
   - Respect rate limits
   - Batch operations when possible
   - Monitor usage in analytics

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Applies To**: Workspace features and collaboration
- **Related Docs**: AUTH_IMPLEMENTATION.md, FIRESTORE_SECURITY.md, 01_ADMIN_FEATURES_GUIDE.md
