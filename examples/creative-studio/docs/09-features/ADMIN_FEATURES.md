# Admin Features & Management Guide

## Overview

The Admin Panel in Creative Studio provides workspace administrators and system administrators with tools to manage users, media templates, source assets, and system configuration.

**Admin Access Levels**:
- **Workspace Admin**: Manage workspace members, templates, and guidelines
- **System Admin**: Full application control via custom claims

---

## Table of Contents

1. [Admin Panel Overview](#admin-panel-overview)
2. [User Management](#user-management)
3. [Media Templates Management](#media-templates-management)
4. [Source Assets Management](#source-assets-management)
5. [Workspace Management](#workspace-management)
6. [Analytics & Reporting](#analytics--reporting)
7. [Access Control](#access-control)
8. [Admin Best Practices](#admin-best-practices)

---

## Admin Panel Overview

### Access URL

```
Development: http://localhost:4200/admin
Production: https://app.your-domain.com/admin
```

### Authentication

Only users with `admin` role can access the admin panel:

```typescript
// File: frontend/src/app/admin/admin.guard.ts
@Injectable({ providedIn: 'root' })
export class AdminGuard implements CanActivate {
  constructor(
    private authService: AuthService,
    private router: Router
  ) {}

  async canActivate(): Promise<boolean> {
    const user = await this.authService.getCurrentUser();

    if (user?.roles?.includes('admin')) {
      return true;
    }

    this.router.navigate(['/dashboard']);
    return false;
  }
}
```

### Admin Layout

**File**: `frontend/src/app/admin/admin-layout.component.ts`

```typescript
@Component({
  selector: 'app-admin-layout',
  template: `
    <div class="admin-container">
      <!-- Navigation Sidebar -->
      <nav class="admin-sidebar">
        <div class="admin-header">
          <h2>Admin Panel</h2>
          <span class="user-badge">{{ currentUser?.email }}</span>
        </div>

        <ul class="admin-menu">
          <li>
            <a routerLink="users" routerLinkActive="active">
              <mat-icon>people</mat-icon>
              Users Management
            </a>
          </li>
          <li>
            <a routerLink="templates" routerLinkActive="active">
              <mat-icon>template_shapes</mat-icon>
              Media Templates
            </a>
          </li>
          <li>
            <a routerLink="assets" routerLinkActive="active">
              <mat-icon>folder</mat-icon>
              Source Assets
            </a>
          </li>
          <li>
            <a routerLink="workspace" routerLinkActive="active">
              <mat-icon>business</mat-icon>
              Workspace Settings
            </a>
          </li>
          <li>
            <a routerLink="analytics" routerLinkActive="active">
              <mat-icon>analytics</mat-icon>
              Analytics
            </a>
          </li>
        </ul>

        <button
          class="logout-btn"
          (click)="logout()"
          mat-button
        >
          Logout
        </button>
      </nav>

      <!-- Main Content -->
      <main class="admin-content">
        <router-outlet></router-outlet>
      </main>
    </div>
  `,
  styleUrls: ['./admin-layout.component.css'],
})
export class AdminLayoutComponent implements OnInit {
  currentUser: User;

  constructor(
    private authService: AuthService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.authService.currentUser$.subscribe((user) => {
      this.currentUser = user;
    });
  }

  logout(): void {
    this.authService.signOut();
  }
}
```

---

## User Management

### Users Management Component

**File**: `frontend/src/app/admin/users-management.component.ts`

```typescript
@Component({
  selector: 'app-users-management',
  templateUrl: './users-management.component.html',
  styleUrls: ['./users-management.component.css'],
})
export class UsersManagementComponent implements OnInit {
  /**
   * List of workspace users
   */
  users$: Observable<User[]>;

  /**
   * Columns to display in table
   */
  displayedColumns: string[] = ['email', 'display_name', 'roles', 'joined_at', 'actions'];

  /**
   * Selected user for editing
   */
  selectedUser: User | null = null;
  isEditingUser = false;

  constructor(
    private adminService: AdminService,
    private dialog: MatDialog,
    private notificationService: NotificationService
  ) {}

  ngOnInit(): void {
    this.loadUsers();
  }

  /**
   * Load all workspace users
   */
  loadUsers(): void {
    this.users$ = this.adminService.getWorkspaceUsers().pipe(
      catchError((error) => {
        console.error('Failed to load users:', error);
        return of([]);
      })
    );
  }

  /**
   * Open dialog to invite new user
   */
  openInviteDialog(): void {
    const dialogRef = this.dialog.open(InviteUserDialogComponent, {
      width: '400px',
      data: {},
    });

    dialogRef.afterClosed().subscribe((result) => {
      if (result) {
        this.inviteUser(result.email, result.role);
      }
    });
  }

  /**
   * Invite new user to workspace
   */
  async inviteUser(email: string, role: UserRole): Promise<void> {
    try {
      await this.adminService.inviteUser(email, role).toPromise();
      this.notificationService.showSuccess(`Invited ${email} as ${role}`);
      this.loadUsers();
    } catch (error) {
      this.notificationService.showError('Failed to invite user');
    }
  }

  /**
   * Update user role
   */
  async updateUserRole(userId: string, newRole: UserRole): Promise<void> {
    try {
      await this.adminService.updateUserRole(userId, newRole).toPromise();
      this.notificationService.showSuccess('Role updated');
      this.loadUsers();
    } catch (error) {
      this.notificationService.showError('Failed to update role');
    }
  }

  /**
   * Remove user from workspace
   */
  async removeUser(userId: string): Promise<void> {
    if (!confirm('Remove this user from workspace?')) {
      return;
    }

    try {
      await this.adminService.removeUser(userId).toPromise();
      this.notificationService.showSuccess('User removed');
      this.loadUsers();
    } catch (error) {
      this.notificationService.showError('Failed to remove user');
    }
  }

  /**
   * View user details
   */
  viewUserDetails(user: User): void {
    this.selectedUser = user;
    this.isEditingUser = true;
  }

  /**
   * Close edit panel
   */
  closeEditPanel(): void {
    this.isEditingUser = false;
    this.selectedUser = null;
  }
}
```

### Invite User Dialog

**File**: `frontend/src/app/admin/invite-user-dialog.component.ts`

```typescript
@Component({
  selector: 'app-invite-user-dialog',
  template: `
    <h2 mat-dialog-title>Invite User to Workspace</h2>

    <mat-dialog-content>
      <form [formGroup]="inviteForm">
        <!-- Email Input -->
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>User Email</mat-label>
          <input
            matInput
            formControlName="email"
            type="email"
            placeholder="user@example.com"
          />
          <mat-error *ngIf="inviteForm.get('email')?.hasError('required')">
            Email is required
          </mat-error>
          <mat-error *ngIf="inviteForm.get('email')?.hasError('email')">
            Invalid email format
          </mat-error>
        </mat-form-field>

        <!-- Role Selection -->
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Role</mat-label>
          <mat-select formControlName="role">
            <mat-option value="viewer">Viewer (Read-only)</mat-option>
            <mat-option value="editor">Editor (Can create media)</mat-option>
            <mat-option value="admin">Admin (Full control)</mat-option>
          </mat-select>
        </mat-form-field>

        <!-- Help Text -->
        <p class="role-description">
          <strong>Viewer</strong>: Can view gallery and templates only<br />
          <strong>Editor</strong>: Can create, edit, and delete their own media<br />
          <strong>Admin</strong>: Full workspace control including user management
        </p>
      </form>
    </mat-dialog-content>

    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Cancel</button>
      <button
        mat-button
        color="primary"
        [disabled]="!inviteForm.valid || isLoading"
        (click)="send()"
      >
        <mat-spinner *ngIf="isLoading" diameter="20"></mat-spinner>
        Send Invite
      </button>
    </mat-dialog-actions>
  `,
})
export class InviteUserDialogComponent {
  inviteForm: FormGroup;
  isLoading = false;

  constructor(
    public dialogRef: MatDialogRef<InviteUserDialogComponent>,
    private fb: FormBuilder
  ) {
    this.inviteForm = this.fb.group({
      email: ['', [Validators.required, Validators.email]],
      role: ['viewer', Validators.required],
    });
  }

  send(): void {
    if (this.inviteForm.valid) {
      this.dialogRef.close(this.inviteForm.value);
    }
  }
}
```

### Backend User Management Service

**File**: `backend/src/routes/admin_controller.py`

```python
from fastapi import APIRouter, Depends, HTTPException, status
from src.security.oauth2 import get_current_user
from src.security.authorization import require_role
from src.models.user_model import UserRoleEnum
from src.services.user_service import UserService
from src.services.workspace_service import WorkspaceService

router = APIRouter(prefix='/api/admin', tags=['admin'])

@router.get('/users')
async def get_workspace_users(
    current_user: dict = Depends(require_role([UserRoleEnum.ADMIN])),
):
    """
    Get all users in workspace

    Requires: Admin role
    """
    workspace_service = WorkspaceService()
    workspace = await workspace_service.get_user_workspace(current_user['uid'])

    return {
        'success': True,
        'data': [
            {
                'user_id': m.user_id,
                'email': m.user_email,
                'role': m.role.value,
                'joined_at': m.joined_at.isoformat(),
            }
            for m in workspace.members
        ],
    }

@router.post('/users/invite')
async def invite_user(
    email: str,
    role: str,
    current_user: dict = Depends(require_role([UserRoleEnum.ADMIN])),
):
    """
    Invite user to workspace

    Args:
        email: User email to invite
        role: admin, editor, or viewer
    """
    if role not in ['admin', 'editor', 'viewer']:
        raise HTTPException(status_code=400, detail='Invalid role')

    workspace_service = WorkspaceService()
    workspace = await workspace_service.get_user_workspace(current_user['uid'])

    # Add user to workspace
    await workspace_service.add_member(
        workspace.id,
        email,
        UserRoleEnum(role)
    )

    return {'success': True, 'message': f'User {email} invited'}

@router.patch('/users/{user_id}/role')
async def update_user_role(
    user_id: str,
    new_role: str,
    current_user: dict = Depends(require_role([UserRoleEnum.ADMIN])),
):
    """Update user role in workspace"""
    workspace_service = WorkspaceService()

    await workspace_service.update_member_role(
        user_id,
        UserRoleEnum(new_role)
    )

    return {'success': True, 'message': 'Role updated'}

@router.delete('/users/{user_id}')
async def remove_user(
    user_id: str,
    current_user: dict = Depends(require_role([UserRoleEnum.ADMIN])),
):
    """Remove user from workspace"""
    workspace_service = WorkspaceService()

    await workspace_service.remove_member(user_id)

    return {'success': True, 'message': 'User removed'}
```

---

## Media Templates Management

### Templates Management Component

**File**: `frontend/src/app/admin/media-templates-management.component.ts`

```typescript
@Component({
  selector: 'app-media-templates-management',
  templateUrl: './media-templates-management.component.html',
})
export class MediaTemplatesManagementComponent implements OnInit {
  /**
   * List of templates
   */
  templates$: Observable<MediaTemplate[]>;

  /**
   * Form for creating/editing template
   */
  templateForm: FormGroup;

  /**
   * Template being edited (null = creating new)
   */
  editingTemplate: MediaTemplate | null = null;
  showForm = false;

  constructor(
    private adminService: AdminService,
    private fb: FormBuilder,
    private notificationService: NotificationService
  ) {
    this.templateForm = this.createForm();
  }

  ngOnInit(): void {
    this.loadTemplates();
  }

  /**
   * Load all templates
   */
  loadTemplates(): void {
    this.templates$ = this.adminService.getTemplates();
  }

  /**
   * Create template form
   */
  private createForm(): FormGroup {
    return this.fb.group({
      name: ['', [Validators.required, Validators.minLength(3)]],
      category: ['product', Validators.required],
      model: ['imagen-3-fast', Validators.required],
      prompt_template: ['', [Validators.required, Validators.minLength(10)]],
      variables: this.fb.array([]),
    });
  }

  /**
   * Open form to create new template
   */
  openCreateForm(): void {
    this.editingTemplate = null;
    this.templateForm.reset();
    this.showForm = true;
  }

  /**
   * Open form to edit template
   */
  openEditForm(template: MediaTemplate): void {
    this.editingTemplate = template;
    this.templateForm.patchValue({
      name: template.name,
      category: template.category,
      model: template.model,
      prompt_template: template.prompt_template,
    });
    this.showForm = true;
  }

  /**
   * Save template (create or update)
   */
  async saveTemplate(): Promise<void> {
    if (!this.templateForm.valid) {
      this.notificationService.showError('Please fill all required fields');
      return;
    }

    try {
      if (this.editingTemplate) {
        // Update
        await this.adminService
          .updateTemplate(this.editingTemplate.id, this.templateForm.value)
          .toPromise();
        this.notificationService.showSuccess('Template updated');
      } else {
        // Create
        await this.adminService
          .createTemplate(this.templateForm.value)
          .toPromise();
        this.notificationService.showSuccess('Template created');
      }

      this.showForm = false;
      this.loadTemplates();
    } catch (error) {
      this.notificationService.showError('Failed to save template');
    }
  }

  /**
   * Delete template
   */
  async deleteTemplate(templateId: string): Promise<void> {
    if (!confirm('Delete this template?')) return;

    try {
      await this.adminService.deleteTemplate(templateId).toPromise();
      this.notificationService.showSuccess('Template deleted');
      this.loadTemplates();
    } catch (error) {
      this.notificationService.showError('Failed to delete template');
    }
  }

  /**
   * Preview template with sample variables
   */
  previewTemplate(): void {
    const promptTemplate = this.templateForm.get('prompt_template')?.value;
    // Parse {{variable}} placeholders and show preview
  }
}
```

### Template Form

**File**: `frontend/src/app/admin/template-form.component.html`

```html
<div *ngIf="showForm" class="template-form-container">
  <h3>{{ editingTemplate ? 'Edit Template' : 'Create Template' }}</h3>

  <form [formGroup]="templateForm" (ngSubmit)="saveTemplate()">
    <!-- Name -->
    <mat-form-field appearance="outline" class="full-width">
      <mat-label>Template Name</mat-label>
      <input matInput formControlName="name" placeholder="e.g., Product Photography" />
    </mat-form-field>

    <!-- Category -->
    <mat-form-field appearance="outline" class="full-width">
      <mat-label>Category</mat-label>
      <mat-select formControlName="category">
        <mat-option value="product">Product</mat-option>
        <mat-option value="fashion">Fashion</mat-option>
        <mat-option value="interior">Interior</mat-option>
        <mat-option value="social-media">Social Media</mat-option>
      </mat-select>
    </mat-form-field>

    <!-- Model -->
    <mat-form-field appearance="outline" class="full-width">
      <mat-label>AI Model</mat-label>
      <mat-select formControlName="model">
        <mat-option value="imagen-3-fast">Imagen 3.0 (Fast)</mat-option>
        <mat-option value="imagen-3">Imagen 3.0</mat-option>
        <mat-option value="veo-2">Veo 2.0 (Video)</mat-option>
        <mat-option value="chirp">Chirp (Audio)</mat-option>
      </mat-select>
    </mat-form-field>

    <!-- Prompt Template -->
    <mat-form-field appearance="outline" class="full-width">
      <mat-label>Prompt Template</mat-label>
      <textarea
        matInput
        formControlName="prompt_template"
        rows="5"
        placeholder="Use {{variable_name}} for variables&#10;e.g., A professional photo of {{product}} in {{location}}"
      ></textarea>
      <mat-hint>Use {{variable_name}} syntax for variables</mat-hint>
    </mat-form-field>

    <!-- Preview -->
    <div class="template-preview" *ngIf="templateForm.valid">
      <h4>Preview</h4>
      <p>{{ previewTemplate() }}</p>
    </div>

    <!-- Actions -->
    <div class="form-actions">
      <button mat-button type="button" (click)="showForm = false">Cancel</button>
      <button mat-button color="primary" type="submit" [disabled]="!templateForm.valid">
        {{ editingTemplate ? 'Update' : 'Create' }}
      </button>
    </div>
  </form>
</div>
```

---

## Source Assets Management

### Assets Management Component

**File**: `frontend/src/app/admin/source-assets-management.component.ts`

```typescript
@Component({
  selector: 'app-source-assets-management',
  templateUrl: './source-assets-management.component.html',
})
export class SourceAssetsManagementComponent implements OnInit {
  /**
   * List of source assets
   */
  assets$: Observable<SourceAsset[]>;

  /**
   * File upload
   */
  selectedFile: File | null = null;
  isUploading = false;

  /**
   * Asset type filter
   */
  assetTypeFilter = '';

  constructor(
    private adminService: AdminService,
    private notificationService: NotificationService
  ) {}

  ngOnInit(): void {
    this.loadAssets();
  }

  /**
   * Load all source assets
   */
  loadAssets(): void {
    this.assets$ = this.adminService.getSourceAssets(this.assetTypeFilter);
  }

  /**
   * Handle file selection
   */
  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.selectedFile = input.files?.[0] || null;
  }

  /**
   * Upload asset
   */
  async uploadAsset(): Promise<void> {
    if (!this.selectedFile) {
      this.notificationService.showError('Please select a file');
      return;
    }

    this.isUploading = true;

    try {
      // Get presigned URL
      const { upload_url } = await this.adminService
        .getAssetUploadUrl(this.selectedFile.size, this.selectedFile.type)
        .toPromise();

      // Upload to GCS directly
      await fetch(upload_url, {
        method: 'POST',
        body: this.selectedFile,
      });

      // Register asset
      const assetUri = `gs://bucket/assets/${this.selectedFile.name}`;
      await this.adminService.registerAsset({
        gcs_uri: assetUri,
        asset_type: 'reference-image',
        name: this.selectedFile.name,
      }).toPromise();

      this.notificationService.showSuccess('Asset uploaded successfully');
      this.selectedFile = null;
      this.loadAssets();
    } catch (error) {
      this.notificationService.showError('Failed to upload asset');
    } finally {
      this.isUploading = false;
    }
  }

  /**
   * Delete asset
   */
  async deleteAsset(assetId: string): Promise<void> {
    if (!confirm('Delete this asset?')) return;

    try {
      await this.adminService.deleteAsset(assetId).toPromise();
      this.notificationService.showSuccess('Asset deleted');
      this.loadAssets();
    } catch (error) {
      this.notificationService.showError('Failed to delete asset');
    }
  }

  /**
   * Download asset
   */
  async downloadAsset(assetId: string, name: string): Promise<void> {
    try {
      const url = await this.adminService.getAssetDownloadUrl(assetId).toPromise();
      const a = document.createElement('a');
      a.href = url;
      a.download = name;
      a.click();
    } catch (error) {
      this.notificationService.showError('Download failed');
    }
  }

  /**
   * Filter by asset type
   */
  filterByType(type: string): void {
    this.assetTypeFilter = type;
    this.loadAssets();
  }
}
```

---

## Workspace Management

### Workspace Settings Component

**File**: `frontend/src/app/admin/workspace-settings.component.ts`

```typescript
@Component({
  selector: 'app-workspace-settings',
  templateUrl: './workspace-settings.component.html',
})
export class WorkspaceSettingsComponent implements OnInit {
  /**
   * Workspace configuration form
   */
  settingsForm: FormGroup;

  /**
   * Current workspace data
   */
  workspace$: Observable<Workspace>;

  constructor(
    private adminService: AdminService,
    private fb: FormBuilder,
    private notificationService: NotificationService
  ) {
    this.settingsForm = this.createForm();
  }

  ngOnInit(): void {
    this.loadWorkspace();
  }

  /**
   * Load workspace settings
   */
  loadWorkspace(): void {
    this.workspace$ = this.adminService.getWorkspaceSettings();

    this.workspace$.subscribe((workspace) => {
      this.settingsForm.patchValue(workspace);
    });
  }

  /**
   * Create settings form
   */
  private createForm(): FormGroup {
    return this.fb.group({
      name: ['', Validators.required],
      description: [''],
      brand_color: ['#0066cc'],
      theme: ['light'],
    });
  }

  /**
   * Save workspace settings
   */
  async saveSettings(): Promise<void> {
    if (!this.settingsForm.valid) {
      this.notificationService.showError('Please fill all required fields');
      return;
    }

    try {
      await this.adminService
        .updateWorkspaceSettings(this.settingsForm.value)
        .toPromise();
      this.notificationService.showSuccess('Settings saved');
    } catch (error) {
      this.notificationService.showError('Failed to save settings');
    }
  }

  /**
   * Delete workspace
   */
  async deleteWorkspace(): Promise<void> {
    const confirm = window.confirm(
      'This will permanently delete the workspace and all its data. This cannot be undone.'
    );

    if (!confirm) return;

    try {
      await this.adminService.deleteWorkspace().toPromise();
      this.notificationService.showSuccess('Workspace deleted');
      // Redirect to home
    } catch (error) {
      this.notificationService.showError('Failed to delete workspace');
    }
  }
}
```

---

## Analytics & Reporting

### Analytics Dashboard

**File**: `frontend/src/app/admin/analytics.component.ts`

```typescript
@Component({
  selector: 'app-admin-analytics',
  templateUrl: './analytics.component.html',
})
export class AnalyticsComponent implements OnInit {
  /**
   * Analytics data
   */
  analytics$: Observable<AnalyticsData>;

  /**
   * Charts
   */
  generationByModel: any;
  usageOverTime: any;
  userActivity: any;

  /**
   * Date range filter
   */
  dateRange = new FormGroup({
    start: new FormControl(this.getLast30Days()),
    end: new FormControl(new Date()),
  });

  constructor(private adminService: AdminService) {}

  ngOnInit(): void {
    this.loadAnalytics();
  }

  /**
   * Load analytics data
   */
  loadAnalytics(): void {
    this.analytics$ = this.adminService.getAnalytics({
      start_date: this.dateRange.get('start')?.value,
      end_date: this.dateRange.get('end')?.value,
    });

    this.analytics$.subscribe((data) => {
      this.initializeCharts(data);
    });
  }

  /**
   * Initialize charts with data
   */
  private initializeCharts(data: AnalyticsData): void {
    // Generation by model
    this.generationByModel = {
      labels: Object.keys(data.generation_by_model),
      datasets: [
        {
          data: Object.values(data.generation_by_model),
          backgroundColor: ['#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0'],
        },
      ],
    };

    // Usage over time
    this.usageOverTime = {
      labels: data.daily_usage.map((d) => d.date),
      datasets: [
        {
          label: 'Images',
          data: data.daily_usage.map((d) => d.images),
          borderColor: '#FF6384',
        },
        {
          label: 'Videos',
          data: data.daily_usage.map((d) => d.videos),
          borderColor: '#36A2EB',
        },
        {
          label: 'Audio',
          data: data.daily_usage.map((d) => d.audio),
          borderColor: '#FFCE56',
        },
      ],
    };
  }

  /**
   * Export analytics as CSV
   */
  exportAsCSV(): void {
    this.analytics$.subscribe((data) => {
      const csv = this.convertToCSV(data);
      const blob = new Blob([csv], { type: 'text/csv' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `analytics-${new Date().toISOString()}.csv`;
      a.click();
    });
  }

  /**
   * Convert analytics to CSV
   */
  private convertToCSV(data: AnalyticsData): string {
    // Implementation
    return '';
  }

  /**
   * Get last 30 days date
   */
  private getLast30Days(): Date {
    const date = new Date();
    date.setDate(date.getDate() - 30);
    return date;
  }
}
```

### Analytics API Endpoint

**File**: `backend/src/routes/admin_controller.py`

```python
@router.get('/analytics')
async def get_analytics(
    start_date: str = None,
    end_date: str = None,
    current_user: dict = Depends(require_role([UserRoleEnum.ADMIN])),
):
    """
    Get workspace analytics

    Args:
        start_date: ISO format date (default: 30 days ago)
        end_date: ISO format date (default: today)

    Returns:
        AnalyticsData with generation stats, user activity, etc.
    """
    if not start_date:
        start_date = (datetime.utcnow() - timedelta(days=30)).isoformat()
    if not end_date:
        end_date = datetime.utcnow().isoformat()

    workspace_service = WorkspaceService()
    workspace = await workspace_service.get_user_workspace(current_user['uid'])

    # Query media library for stats
    media_docs = await firestore.collection('media_library') \
        .where('workspace_id', '==', workspace.id) \
        .where('created_at', '>=', start_date) \
        .where('created_at', '<=', end_date) \
        .get()

    # Group by model
    by_model = {}
    daily_usage = {}

    for doc in media_docs:
        model = doc.get('model', 'unknown')
        by_model[model] = by_model.get(model, 0) + 1

        # Group by date
        date = doc.get('created_at').split('T')[0]
        if date not in daily_usage:
            daily_usage[date] = {'images': 0, 'videos': 0, 'audio': 0}

        mime_type = doc.get('mime_type', '')
        if mime_type.startswith('image'):
            daily_usage[date]['images'] += 1
        elif mime_type.startswith('video'):
            daily_usage[date]['videos'] += 1
        elif mime_type.startswith('audio'):
            daily_usage[date]['audio'] += 1

    return {
        'success': True,
        'data': {
            'generation_by_model': by_model,
            'daily_usage': [
                {'date': date, **stats}
                for date, stats in sorted(daily_usage.items())
            ],
            'total_media': len(media_docs),
            'unique_users': len(set(d.get('user_email') for d in media_docs)),
        },
    }
```

---

## Access Control

### Admin Role Assignment

To make a user an admin:

**Backend**:
```python
from src.config.firebase_admin import firebase_admin_service

# Set admin custom claims
firebase_admin_service.set_custom_claims(user_uid, {
    'admin': True,
    'roles': ['admin'],
})
```

**Via Firestore**:
```json
{
  "users": {
    "user-uid-123": {
      "email": "admin@example.com",
      "roles": ["admin"],
      "admin": true
    }
  }
}
```

### Role Hierarchy

```
System Admin (Full control)
  ↓
Workspace Admin (Workspace control)
  ↓
Editor (Create media)
  ↓
Viewer (Read-only)
```

---

## Admin Best Practices

### Security

1. **Principle of Least Privilege**
   - Assign minimal roles needed
   - Regularly review admin users
   - Remove admin access when not needed

2. **Audit Logging**
   ```python
   # Log all admin actions
   logger.info('Admin action', extra={
       'admin_user': current_user['email'],
       'action': 'updated_user_role',
       'target_user': user_id,
       'new_role': new_role,
   })
   ```

3. **Require Confirmation**
   - Confirm before deleting workspaces
   - Confirm before removing users
   - Confirm before major changes

### Best Practices

1. **Regular Backups**
   - Enable Firestore automated backups
   - Test recovery procedures

2. **Monitoring**
   - Monitor user invitations for spam
   - Track API quota usage
   - Monitor error rates

3. **Documentation**
   - Document admin procedures
   - Keep runbooks for common tasks
   - Document incident response

4. **Testing**
   - Test admin features in staging first
   - Verify permissions before rollout
   - Test disaster recovery scenarios

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Applies To**: Admin panel functionality
- **Related Docs**: FRONTEND_COMPONENTS.md, AUTH_IMPLEMENTATION.md, FIRESTORE_SECURITY.md
