# Frontend Components & Architecture

## Overview

The Creative Studio frontend is built with Angular 18 and follows a modular architecture with feature modules, shared components, and centralized services.

**Architecture Pattern**:
```
App Component
    ↓
Routing Module
    ↓
Feature Modules (Gallery, Images, Videos, Audio, VTO, Admin)
    ├─ Components (Smart + Presentational)
    ├─ Services (HTTP, State, Business Logic)
    └─ Models (Interfaces, Types)
        ↓
Shared Module (Common Components & Services)
    ├─ Common Components (Dialogs, Widgets)
    └─ Common Services (Auth, Http, User, etc.)
```

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Gallery Module](#gallery-module)
3. [Image Generation Module](#image-generation-module)
4. [Video Generation Module](#video-generation-module)
5. [Audio Generation Module](#audio-generation-module)
6. [Virtual Try-On Module](#virtual-try-on-module)
7. [Admin Module](#admin-module)
8. [Shared Components](#shared-components)
9. [Services](#services)
10. [State Management](#state-management)
11. [Component Patterns](#component-patterns)
12. [Form Handling](#form-handling)

---

## Project Structure

```
frontend/src/app/
├── app.component.ts              # Root component
├── app-routing.module.ts         # Main routing
├── auth.interceptor.ts           # HTTP interceptor for auth
├── auth.guard.ts                 # Route protection
│
├── gallery/
│   ├── gallery.module.ts
│   ├── media-gallery.component.ts      # List view
│   ├── media-gallery.component.html
│   ├── media-gallery.component.css
│   ├── media-detail.component.ts       # Detail view
│   ├── media-detail.component.html
│   ├── media-detail.component.css
│   └── gallery.service.ts
│
├── images/
│   ├── images.module.ts
│   ├── image-generation.component.ts
│   ├── image-generation.component.html
│   ├── image-generation.component.css
│   └── image.service.ts
│
├── videos/
│   ├── videos.module.ts
│   ├── video-generation.component.ts
│   ├── video-generation.component.html
│   ├── video-generation.component.css
│   ├── video-status.component.ts       # Polling UI
│   └── video.service.ts
│
├── audio/
│   ├── audio.module.ts
│   ├── audio-generation.component.ts
│   ├── audio-generation.component.html
│   ├── audio-generation.component.css
│   └── audio.service.ts
│
├── vto/
│   ├── vto.module.ts
│   ├── vto.component.ts                # Main VTO interface
│   ├── vto.component.html
│   ├── vto.component.css
│   └── vto.service.ts
│
├── admin/
│   ├── admin.module.ts
│   ├── admin-layout.component.ts
│   ├── media-templates-management.component.ts
│   ├── source-assets-management.component.ts
│   ├── users-management.component.ts
│   └── admin.service.ts
│
├── common/
│   ├── components/
│   │   ├── brand-guideline-dialog/
│   │   ├── image-cropper-dialog/
│   │   ├── media-lightbox/
│   │   ├── workspace-switcher/
│   │   ├── loading-spinner/
│   │   ├── notification-toast/
│   │   └── (10+ more components)
│   │
│   ├── services/
│   │   ├── auth.service.ts
│   │   ├── http.service.ts
│   │   ├── user.service.ts
│   │   ├── workspace.service.ts
│   │   ├── gallery.service.ts
│   │   └── (5+ more services)
│   │
│   └── models/
│       ├── user.interface.ts
│       ├── workspace.interface.ts
│       ├── media.interface.ts
│       └── (5+ more interfaces)
│
├── utils/
│   ├── validators.ts
│   ├── formatters.ts
│   ├── helpers.ts
│   └── constants.ts
│
└── environments/
    ├── environment.ts            # Development
    └── environment.prod.ts       # Production
```

---

## Gallery Module

### MediaGalleryComponent

**Purpose**: Display user's media library with filtering, searching, and pagination.

**File**: `frontend/src/app/gallery/media-gallery.component.ts`

```typescript
import { Component, OnInit, OnDestroy } from '@angular/core';
import { GalleryService } from './gallery.service';
import { Observable, Subject } from 'rxjs';
import { takeUntil, debounceTime, distinctUntilChanged } from 'rxjs/operators';

interface MediaFilter {
  mime_type?: string;
  model?: string;
  status?: string;
  search?: string;
}

@Component({
  selector: 'app-media-gallery',
  templateUrl: './media-gallery.component.html',
  styleUrls: ['./media-gallery.component.css'],
})
export class MediaGalleryComponent implements OnInit, OnDestroy {
  /**
   * Observable list of media items
   * Automatically updates via RxJS subscriptions
   */
  media$: Observable<any[]>;

  /**
   * Current pagination state
   */
  pageSize = 20;
  lastDocument: any = null;
  hasMore = true;
  isLoading = false;

  /**
   * Filter state
   */
  filters: MediaFilter = {};
  private filterSubject = new Subject<MediaFilter>();

  /**
   * Cleanup
   */
  private destroy$ = new Subject<void>();

  constructor(private galleryService: GalleryService) {}

  ngOnInit(): void {
    // Initialize media stream
    this.media$ = this.galleryService.getGallery$();

    // Handle filter changes with debounce
    this.filterSubject
      .pipe(
        debounceTime(300),
        distinctUntilChanged(),
        takeUntil(this.destroy$)
      )
      .subscribe((filters) => {
        this.filters = filters;
        this.lastDocument = null; // Reset pagination
        this.loadGallery();
      });
  }

  /**
   * Load gallery with current filters
   */
  async loadGallery(): Promise<void> {
    this.isLoading = true;
    try {
      await this.galleryService.loadGallery(
        this.pageSize,
        this.lastDocument,
        this.filters
      );
      this.isLoading = false;
    } catch (error) {
      console.error('Failed to load gallery:', error);
      this.isLoading = false;
    }
  }

  /**
   * Load more items (pagination)
   */
  loadMore(): void {
    if (!this.hasMore || this.isLoading) return;
    this.lastDocument = null; // Get next batch
    this.loadGallery();
  }

  /**
   * Filter by type (image, video, audio)
   */
  filterByType(mimeType: string): void {
    this.filterSubject.next({
      ...this.filters,
      mime_type: mimeType,
    });
  }

  /**
   * Filter by model (imagen, veo, chirp)
   */
  filterByModel(model: string): void {
    this.filterSubject.next({
      ...this.filters,
      model: model,
    });
  }

  /**
   * Search gallery
   */
  search(query: string): void {
    this.filterSubject.next({
      ...this.filters,
      search: query,
    });
  }

  /**
   * Open media detail view
   */
  viewDetails(mediaId: string): void {
    // Navigate to detail component
  }

  /**
   * Delete media item
   */
  async deleteMedia(mediaId: string): Promise<void> {
    if (!confirm('Delete this media?')) return;

    try {
      await this.galleryService.deleteMedia(mediaId);
      // Gallery automatically updates via service
    } catch (error) {
      console.error('Failed to delete:', error);
    }
  }

  /**
   * Download media
   */
  async downloadMedia(mediaId: string): Promise<void> {
    try {
      const url = await this.galleryService.getDownloadUrl(mediaId);
      window.location.href = url;
    } catch (error) {
      console.error('Download failed:', error);
    }
  }

  /**
   * Cleanup subscriptions
   */
  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

### MediaDetailComponent

**Purpose**: Display detailed information about a media item with actions.

```typescript
@Component({
  selector: 'app-media-detail',
  templateUrl: './media-detail.component.html',
})
export class MediaDetailComponent implements OnInit {
  mediaId: string;
  media$: Observable<any>;
  signedUrl$: Observable<string>;

  constructor(
    private galleryService: GalleryService,
    private route: ActivatedRoute
  ) {}

  ngOnInit(): void {
    this.mediaId = this.route.snapshot.paramMap.get('id');

    // Load media details
    this.media$ = this.galleryService.getMediaDetail(this.mediaId);

    // Generate signed URL for viewing/downloading
    this.signedUrl$ = this.media$.pipe(
      switchMap((media) => this.galleryService.getSignedUrl(media.gcs_uri))
    );
  }

  /**
   * Update media tags
   */
  async updateTags(newTags: string[]): Promise<void> {
    await this.galleryService.updateMedia(this.mediaId, { tags: newTags });
  }

  /**
   * Share media
   */
  async shareMedia(): Promise<void> {
    const url = await this.galleryService.getShareUrl(this.mediaId);
    // Copy to clipboard or open share dialog
    this.copyToClipboard(url);
  }

  /**
   * Delete media
   */
  async deleteMedia(): Promise<void> {
    if (!confirm('Delete this media?')) return;
    await this.galleryService.deleteMedia(this.mediaId);
    // Navigate back to gallery
  }

  private copyToClipboard(text: string): void {
    navigator.clipboard.writeText(text);
  }
}
```

### GalleryService

```typescript
@Injectable({ providedIn: 'root' })
export class GalleryService {
  private gallerySubject = new BehaviorSubject<any[]>([]);
  public gallery$ = this.gallerySubject.asObservable();

  constructor(private http: HttpClient) {}

  /**
   * Get gallery observable (fetches from API)
   */
  getGallery$(): Observable<any[]> {
    return this.gallerySubject.asObservable(); // Frontend components subscribe to this
  }

  /**
   * Load gallery with filters and pagination from backend API
   */
  async loadGallery(
    pageSize: number,
    startAfter: any,
    filters: any
  ): Promise<void> {
    const response = await this.http
      .get('/api/galleries', {
        params: {
          page_size: pageSize,
          start_after: startAfter?.id,
          ...filters,
        },
      })
      .toPromise();

    this.gallerySubject.next(response.data);
  }

  /**
   * Get media detail
   */
  getMediaDetail(mediaId: string): Observable<any> {
    return this.http.get(`/api/galleries/${mediaId}`).pipe(
      map((response: any) => response.data),
      shareReplay(1) // Cache the result
    );
  }

  /**
   * Get signed download URL
   */
  async getDownloadUrl(mediaId: string): Promise<string> {
    const response = await this.http
      .post(`/api/galleries/${mediaId}/download-url`, {})
      .toPromise();
    return response.data.signed_url;
  }

  /**
   * Get signed view URL
   */
  getSignedUrl(gcsUri: string): Observable<string> {
    return this.http
      .post('/api/galleries/get-signed-url', { gcs_uri: gcsUri })
      .pipe(map((response: any) => response.data.signed_url));
  }

  /**
   * Update media metadata
   */
  async updateMedia(mediaId: string, updates: any): Promise<void> {
    await this.http
      .patch(`/api/galleries/${mediaId}`, updates)
      .toPromise();
  }

  /**
   * Delete media
   */
  async deleteMedia(mediaId: string): Promise<void> {
    await this.http.delete(`/api/galleries/${mediaId}`).toPromise();
  }
}
```

---

## Image Generation Module

### ImageGenerationComponent

**Purpose**: UI for image generation with prompt input, style/size selection, and brand guidelines.

```typescript
@Component({
  selector: 'app-image-generation',
  templateUrl: './image-generation.component.html',
  styleUrls: ['./image-generation.component.css'],
})
export class ImageGenerationComponent implements OnInit {
  /**
   * Form for image generation
   */
  generationForm: FormGroup;

  /**
   * Generation state
   */
  isGenerating = false;
  generatedImage$: Observable<any>;

  /**
   * Available options
   */
  styles$ = this.imageService.getStyles$();
  sizes$ = this.imageService.getSizes$();

  constructor(
    private fb: FormBuilder,
    private imageService: ImageService,
    private workspaceService: WorkspaceService,
    private notificationService: NotificationService
  ) {
    this.generationForm = this.createForm();
  }

  /**
   * Create form with validation
   */
  private createForm(): FormGroup {
    return this.fb.group({
      prompt: [
        '',
        [
          Validators.required,
          Validators.minLength(10),
          Validators.maxLength(1000),
        ],
      ],
      style: ['photorealistic', Validators.required],
      size: ['1024x1024', Validators.required],
      negativPrompt: [''],
      guidanceScale: [7.5, [Validators.min(1), Validators.max(20)]],
      applyBrandGuidelines: [false],
    });
  }

  /**
   * Generate image
   */
  async generateImage(): Promise<void> {
    if (!this.generationForm.valid) {
      this.notificationService.showError('Please fill all required fields');
      return;
    }

    this.isGenerating = true;

    try {
      const workspace = await this.workspaceService.getCurrentWorkspace();

      this.generatedImage$ = this.imageService.generateImage({
        ...this.generationForm.value,
        workspace_id: workspace.id,
      });

      this.notificationService.showSuccess('Image generated successfully!');
      this.generationForm.reset();
    } catch (error) {
      this.notificationService.showError('Image generation failed');
      console.error(error);
    } finally {
      this.isGenerating = false;
    }
  }

  /**
   * Update prompt suggestions
   */
  updateSuggestions(query: string): void {
    // Call backend for AI suggestions
  }
}
```

### ImageService

```typescript
@Injectable({ providedIn: 'root' })
export class ImageService {
  constructor(private http: HttpClient) {}

  /**
   * Generate image
   */
  generateImage(request: ImageGenerationRequest): Observable<ImageResponse> {
    return this.http.post('/api/images', request).pipe(
      map((response: any) => response.data),
      catchError((error) => {
        if (error.status === 400) {
          throw new Error(error.error.error.message);
        }
        throw error;
      })
    );
  }

  /**
   * Get available styles
   */
  getStyles$(): Observable<string[]> {
    return this.http.get('/api/generation-options').pipe(
      map((response: any) => response.data.styles),
      shareReplay(1) // Cache for component lifetime
    );
  }

  /**
   * Get available sizes
   */
  getSizes$(): Observable<string[]> {
    return this.http.get('/api/generation-options').pipe(
      map((response: any) => response.data.sizes),
      shareReplay(1)
    );
  }

  /**
   * Get image details
   */
  getImage(imageId: string): Observable<ImageResponse> {
    return this.http
      .get(`/api/images/${imageId}`)
      .pipe(map((response: any) => response.data));
  }
}
```

---

## Video Generation Module

### VideoGenerationComponent

**Purpose**: UI for video generation with status polling.

```typescript
@Component({
  selector: 'app-video-generation',
  templateUrl: './video-generation.component.html',
})
export class VideoGenerationComponent implements OnInit, OnDestroy {
  generationForm: FormGroup;

  /**
   * Video generation state
   */
  isGenerating = false;
  videoRequest$: Observable<VideoRequest>;
  pollingActive = false;

  constructor(
    private fb: FormBuilder,
    private videoService: VideoService,
    private destroy$: Subject<void>
  ) {
    this.generationForm = this.createForm();
  }

  /**
   * Generate video
   */
  async generateVideo(): Promise<void> {
    this.isGenerating = true;

    try {
      // Call backend - returns immediately with request ID
      this.videoRequest$ = this.videoService.generateVideo(
        this.generationForm.value
      );

      // Start polling for completion
      this.videoRequest$
        .pipe(
          switchMap((request) => this.pollVideoStatus(request.id)),
          takeUntil(this.destroy$)
        )
        .subscribe();

      this.pollingActive = true;
    } finally {
      this.isGenerating = false;
    }
  }

  /**
   * Poll video status every 5 seconds
   */
  private pollVideoStatus(videoId: string): Observable<VideoStatus> {
    return interval(5000).pipe(
      switchMap(() => this.videoService.getVideoStatus(videoId)),
      tap((status) => {
        // Update UI with progress
        if (status.status === 'success') {
          this.pollingActive = false;
        }
      }),
      takeWhile((status) => status.status !== 'success' && !status.failed),
      takeUntil(this.destroy$)
    );
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

### VideoStatusComponent

```typescript
@Component({
  selector: 'app-video-status',
  template: `
    <div class="status-container">
      <p *ngIf="status.status === 'pending'">
        Generating video... {{ status.progress_percentage }}%
      </p>
      <p *ngIf="status.status === 'success'">Video ready!</p>
      <video *ngIf="status.gcs_uri" [src]="signedUrl$ | async"></video>
    </div>
  `,
})
export class VideoStatusComponent {
  @Input() status: VideoStatus;
  signedUrl$: Observable<string>;

  constructor(private videoService: VideoService) {}

  ngOnChanges(): void {
    if (this.status.gcs_uri) {
      this.signedUrl$ = this.videoService.getSignedUrl(this.status.gcs_uri);
    }
  }
}
```

---

## Audio Generation Module

### AudioGenerationComponent

```typescript
@Component({
  selector: 'app-audio-generation',
  templateUrl: './audio-generation.component.html',
})
export class AudioGenerationComponent {
  generationForm: FormGroup;

  constructor(
    private fb: FormBuilder,
    private audioService: AudioService
  ) {
    this.generationForm = this.createForm();
  }

  /**
   * Generate audio
   */
  async generateAudio(): Promise<void> {
    const result = await this.audioService
      .generateAudio(this.generationForm.value)
      .toPromise();

    // Display generated audio
  }

  /**
   * Play audio preview
   */
  async playAudio(gcsUri: string): Promise<void> {
    const url = await this.audioService.getSignedUrl(gcsUri).toPromise();
    const audio = new Audio(url);
    audio.play();
  }
}
```

---

## Virtual Try-On Module

### VTOComponent

**Purpose**: Virtual try-on interface with garment selection and image upload.

```typescript
@Component({
  selector: 'app-vto',
  templateUrl: './vto.component.html',
  styleUrls: ['./vto.component.css'],
})
export class VTOComponent implements OnInit {
  /**
   * Available garments
   */
  garments$: Observable<Garment[]>;

  /**
   * Selected garment and user image
   */
  selectedGarment: Garment;
  userImageUri: string;

  /**
   * VTO result
   */
  vtoResult$: Observable<VTOResult>;

  constructor(private vtoService: VTOService) {}

  ngOnInit(): void {
    this.garments$ = this.vtoService.getGarments();
  }

  /**
   * Select garment from catalog
   */
  selectGarment(garment: Garment): void {
    this.selectedGarment = garment;
  }

  /**
   * Handle image upload from user
   */
  async onImageSelected(file: File): Promise<void> {
    // Upload to Cloud Storage
    const uri = await this.vtoService.uploadUserImage(file);
    this.userImageUri = uri;
  }

  /**
   * Generate virtual try-on
   */
  async generateVTO(): Promise<void> {
    if (!this.selectedGarment || !this.userImageUri) {
      alert('Please select garment and upload image');
      return;
    }

    this.vtoResult$ = this.vtoService.generateVTO({
      garment_id: this.selectedGarment.id,
      person_image_uri: this.userImageUri,
    });
  }

  /**
   * Save VTO result to gallery
   */
  async saveResult(result: VTOResult): Promise<void> {
    await this.vtoService.saveToGallery(result);
  }
}
```

---

## Admin Module

### AdminLayoutComponent

**Purpose**: Admin panel layout with navigation.

```typescript
@Component({
  selector: 'app-admin-layout',
  template: `
    <div class="admin-container">
      <nav class="admin-sidebar">
        <a routerLink="templates">Media Templates</a>
        <a routerLink="assets">Source Assets</a>
        <a routerLink="users">Users Management</a>
      </nav>
      <main class="admin-content">
        <router-outlet></router-outlet>
      </main>
    </div>
  `,
})
export class AdminLayoutComponent {
  // Admin users only access via AuthGuard
}
```

### MediaTemplatesManagementComponent

```typescript
@Component({
  selector: 'app-media-templates-management',
  templateUrl: './media-templates-management.component.html',
})
export class MediaTemplatesManagementComponent implements OnInit {
  templates$: Observable<MediaTemplate[]>;
  selectedTemplate: MediaTemplate;

  constructor(private adminService: AdminService) {}

  ngOnInit(): void {
    this.templates$ = this.adminService.getTemplates();
  }

  /**
   * Create new template
   */
  async createTemplate(formValue: any): Promise<void> {
    await this.adminService.createTemplate(formValue).toPromise();
    this.templates$ = this.adminService.getTemplates(); // Refresh
  }

  /**
   * Delete template
   */
  async deleteTemplate(templateId: string): Promise<void> {
    await this.adminService.deleteTemplate(templateId).toPromise();
    this.templates$ = this.adminService.getTemplates();
  }
}
```

---

## Shared Components

### BrandGuidelineDialogComponent

```typescript
@Component({
  selector: 'app-brand-guideline-dialog',
  template: `
    <h2 mat-dialog-title>Upload Brand Guidelines</h2>
    <mat-dialog-content>
      <input
        type="file"
        accept=".pdf"
        (change)="onFileSelected($event)"
        #fileInput
      />
      <p *ngIf="isUploading">Uploading and processing...</p>
      <p *ngIf="summary">{{ summary }}</p>
    </mat-dialog-content>
    <mat-dialog-actions>
      <button mat-button mat-dialog-close>Cancel</button>
      <button mat-button [disabled]="!file" (click)="upload()">Upload</button>
    </mat-dialog-actions>
  `,
})
export class BrandGuidelineDialogComponent {
  file: File;
  isUploading = false;
  summary: string;

  constructor(
    private brandService: BrandGuidelineService,
    public dialogRef: MatDialogRef<BrandGuidelineDialogComponent>
  ) {}

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.file = input.files?.[0];
  }

  async upload(): Promise<void> {
    this.isUploading = true;

    try {
      // Get upload URL
      const { upload_url } = await this.brandService
        .getUploadUrl(this.file.size)
        .toPromise();

      // Upload directly to GCS
      await fetch(upload_url, {
        method: 'POST',
        body: this.file,
      });

      // Register with backend
      const result = await this.brandService
        .processBrandGuidelines({
          gcs_uri: `gs://bucket/path/${this.file.name}`,
        })
        .toPromise();

      this.summary = result.data.summary;
      this.isUploading = false;

      // Close after 2 seconds
      setTimeout(() => this.dialogRef.close(result), 2000);
    } catch (error) {
      console.error('Upload failed:', error);
      this.isUploading = false;
    }
  }
}
```

### ImageCropperDialogComponent

```typescript
@Component({
  selector: 'app-image-cropper-dialog',
  template: `
    <h2 mat-dialog-title>Crop Image</h2>
    <mat-dialog-content>
      <image-cropper
        [imageFile]="imageFile"
        [settings]="settings"
        output="canvas"
        (imageCropped)="imageCropped($event)"
      ></image-cropper>
    </mat-dialog-content>
    <mat-dialog-actions>
      <button mat-button mat-dialog-close>Cancel</button>
      <button mat-button (click)="saveCrop()" [disabled]="!croppedImage">
        Save
      </button>
    </mat-dialog-actions>
  `,
})
export class ImageCropperDialogComponent {
  @Input() imageFile: File;

  croppedImage: any;
  settings = {
    width: 200,
    height: 200,
    keepAspectRatio: true,
  };

  constructor(public dialogRef: MatDialogRef<ImageCropperDialogComponent>) {}

  imageCropped(event: ImageCroppedEvent): void {
    this.croppedImage = event.objectUrl;
  }

  saveCrop(): void {
    this.dialogRef.close(this.croppedImage);
  }
}
```

### WorkspaceSwitcherComponent

```typescript
@Component({
  selector: 'app-workspace-switcher',
  template: `
    <mat-select (selectionChange)="switchWorkspace($event.value)">
      <mat-select-trigger>{{ currentWorkspace?.name }}</mat-select-trigger>
      <mat-optgroup *ngFor="let workspace of workspaces$ | async">
        <mat-option [value]="workspace">{{ workspace.name }}</mat-option>
      </mat-optgroup>
    </mat-select>
  `,
})
export class WorkspaceSwitcherComponent {
  workspaces$: Observable<Workspace[]>;
  currentWorkspace: Workspace;

  constructor(private workspaceService: WorkspaceService) {}

  ngOnInit(): void {
    this.workspaces$ = this.workspaceService.getUserWorkspaces();
    this.workspaceService.currentWorkspace$
      .subscribe((ws) => (this.currentWorkspace = ws));
  }

  switchWorkspace(workspace: Workspace): void {
    this.workspaceService.setCurrentWorkspace(workspace);
  }
}
```

---

## Services

### AuthService

```typescript
@Injectable({ providedIn: 'root' })
export class AuthService {
  private currentUserSubject = new BehaviorSubject<User | null>(null);
  public currentUser$ = this.currentUserSubject.asObservable();

  private isAuthenticatedSubject = new BehaviorSubject<boolean>(false);
  public isAuthenticated$ = this.isAuthenticatedSubject.asObservable();

  constructor(private auth: Auth, private router: Router) {
    this.initializeAuthListener();
  }

  /**
   * Initialize auth state listener
   */
  private initializeAuthListener(): void {
    onAuthStateChanged(this.auth, (user) => {
      this.currentUserSubject.next(user);
      this.isAuthenticatedSubject.next(!!user);
    });
  }

  /**
   * Sign in with Google
   */
  async signInWithGoogle(): Promise<void> {
    const provider = new GoogleAuthProvider();
    const result = await signInWithPopup(this.auth, provider);
    this.router.navigate(['/dashboard']);
  }

  /**
   * Sign out
   */
  async signOut(): Promise<void> {
    await signOut(this.auth);
    this.router.navigate(['/login']);
  }

  /**
   * Get ID token for API requests
   */
  async getIdToken(): Promise<string | null> {
    const user = this.auth.currentUser;
    return user ? await user.getIdToken() : null;
  }
}
```

### HttpClientService

```typescript
@Injectable({ providedIn: 'root' })
export class HttpClientService {
  constructor(private http: HttpClient) {}

  /**
   * GET request
   */
  get<T>(url: string, options?: any): Observable<T> {
    return this.http.get<T>(url, options);
  }

  /**
   * POST request
   */
  post<T>(url: string, body: any, options?: any): Observable<T> {
    return this.http.post<T>(url, body, options);
  }

  /**
   * With retry logic
   */
  getWithRetry<T>(url: string, retries = 3): Observable<T> {
    return this.http.get<T>(url).pipe(
      retry({
        count: retries,
        delay: (error, retryCount) => {
          const delayMs = Math.pow(2, retryCount) * 1000;
          return timer(delayMs);
        },
      })
    );
  }
}
```

---

## State Management

### Image State Service

```typescript
@Injectable({ providedIn: 'root' })
export class ImageStateService {
  /**
   * Observable state of image generation
   */
  private generationStateSubject = new BehaviorSubject<ImageGenerationState>({
    isGenerating: false,
    lastGenerated: null,
    error: null,
  });

  public generationState$ = this.generationStateSubject.asObservable();

  /**
   * Start generation
   */
  startGeneration(): void {
    this.generationStateSubject.next({
      ...this.generationStateSubject.value,
      isGenerating: true,
      error: null,
    });
  }

  /**
   * Complete generation
   */
  completeGeneration(result: ImageResponse): void {
    this.generationStateSubject.next({
      isGenerating: false,
      lastGenerated: result,
      error: null,
    });
  }

  /**
   * Generation error
   */
  setError(error: string): void {
    this.generationStateSubject.next({
      ...this.generationStateSubject.value,
      isGenerating: false,
      error,
    });
  }
}
```

---

## Component Patterns

### Smart vs Presentational Components

**Smart Component** (Container):
```typescript
@Component({
  selector: 'app-media-gallery-container',
  template: `
    <app-media-gallery
      [items]="items$ | async"
      [isLoading]="isLoading$ | async"
      (onDelete)="deleteMedia($event)"
    ></app-media-gallery>
  `,
})
export class MediaGalleryContainerComponent {
  // Handles logic, data fetching, state management
}
```

**Presentational Component**:
```typescript
@Component({
  selector: 'app-media-gallery',
  template: `...`,
})
export class MediaGalleryComponent {
  @Input() items: MediaItem[];
  @Input() isLoading: boolean;
  @Output() onDelete = new EventEmitter<string>();

  // Only handles UI presentation and events
}
```

---

## Form Handling

### Reactive Forms Pattern

```typescript
generationForm = this.fb.group({
  prompt: [
    '',
    [
      Validators.required,
      Validators.minLength(10),
      Validators.maxLength(1000),
      this.noSpecialCharacters(),
    ],
  ],
  style: ['photorealistic', Validators.required],
  size: ['1024x1024'],
});

/**
 * Custom validator
 */
private noSpecialCharacters() {
  return (control: AbstractControl) => {
    const value = control.value;
    if (!value) return null;

    const hasSpecialChars = /[^a-zA-Z0-9\s,.]/.test(value);
    return hasSpecialChars ? { invalidCharacters: true } : null;
  };
}

/**
 * Submit form
 */
async submitForm(): Promise<void> {
  if (this.generationForm.invalid) {
    this.markFormGroupTouched(this.generationForm);
    return;
  }

  // Submit
}

/**
 * Mark all fields as touched to show errors
 */
private markFormGroupTouched(formGroup: FormGroup): void {
  Object.keys(formGroup.controls).forEach((key) => {
    const control = formGroup.get(key);
    control?.markAsTouched();
  });
}
```

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Applies To**: Frontend component architecture
- **Related Docs**: ARCHITECTURE.md, AUTH_IMPLEMENTATION.md, API_REFERENCE.md
