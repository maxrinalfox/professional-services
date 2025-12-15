# UI Patterns & Component Usage Guide

## Overview

Creative Studio uses Angular Material and Tailwind CSS to implement consistent UI patterns across the application. This guide documents common patterns for dialogs, modals, forms, notifications, loading states, and error handling.

**Design System**:
- **Framework**: Angular Material (Material Design 3)
- **Styling**: Tailwind CSS for custom utilities
- **Icons**: Material Icons
- **Theming**: Light/Dark theme support
- **Accessibility**: WCAG 2.1 AA compliant

---

## Table of Contents

1. [Dialog Patterns](#dialog-patterns)
2. [Modal Patterns](#modal-patterns)
3. [Form Patterns](#form-patterns)
4. [Notification Patterns](#notification-patterns)
5. [Loading State Patterns](#loading-state-patterns)
6. [Error Display Patterns](#error-display-patterns)
7. [Data Table Patterns](#data-table-patterns)
8. [Navigation Patterns](#navigation-patterns)
9. [Component Examples](#component-examples)
10. [Accessibility Best Practices](#accessibility-best-practices)

---

## Dialog Patterns

### Basic Dialog Pattern

**File**: `frontend/src/app/common/dialogs/base-dialog.component.ts`

```typescript
import { Component, Inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';

/**
 * Basic dialog component template
 *
 * Usage:
 *   this.dialog.open(MyDialogComponent, {
 *     width: '600px',
 *     data: { /* your data */ }
 *   });
 */
@Component({
  selector: 'app-base-dialog',
  template: `
    <h2 mat-dialog-title>{{ title }}</h2>

    <mat-dialog-content>
      <!-- Content here -->
      <ng-content></ng-content>
    </mat-dialog-content>

    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Cancel</button>
      <button
        mat-button
        color="primary"
        (click)="onConfirm()"
        [disabled]="isLoading"
      >
        <mat-spinner *ngIf="isLoading" diameter="20"></mat-spinner>
        {{ confirmText }}
      </button>
    </mat-dialog-actions>
  `,
})
export class BaseDialogComponent {
  title = 'Dialog Title';
  confirmText = 'Confirm';
  isLoading = false;

  constructor(
    public dialogRef: MatDialogRef<BaseDialogComponent>,
    @Inject(MAT_DIALOG_DATA) public data: any
  ) {}

  onConfirm(): void {
    // Override in child component
    this.dialogRef.close();
  }
}
```

### Confirmation Dialog Pattern

```typescript
@Component({
  selector: 'app-confirmation-dialog',
  template: `
    <h2 mat-dialog-title>{{ title }}</h2>

    <mat-dialog-content>
      <p>{{ message }}</p>
      <mat-form-field *ngIf="requiresInput" appearance="outline" class="full-width">
        <mat-label>{{ inputLabel }}</mat-label>
        <input matInput [(ngModel)]="inputValue" />
      </mat-form-field>
    </mat-dialog-content>

    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close="cancel">Cancel</button>
      <button
        mat-button
        color="warn"
        [disabled]="requiresInput && !inputValue"
        (click)="onConfirm()"
      >
        {{ confirmText }}
      </button>
    </mat-dialog-actions>
  `,
})
export class ConfirmationDialogComponent {
  @Input() title = 'Confirm';
  @Input() message = 'Are you sure?';
  @Input() confirmText = 'Delete';
  @Input() requiresInput = false;
  @Input() inputLabel = 'Type to confirm';

  inputValue = '';

  constructor(public dialogRef: MatDialogRef<ConfirmationDialogComponent>) {}

  onConfirm(): void {
    this.dialogRef.close('confirmed');
  }
}
```

### Form Dialog Pattern

```typescript
@Component({
  selector: 'app-form-dialog',
  template: `
    <h2 mat-dialog-title>{{ title }}</h2>

    <mat-dialog-content>
      <form [formGroup]="form" (ngSubmit)="onSubmit()">
        <!-- Form fields -->
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Name</mat-label>
          <input matInput formControlName="name" />
          <mat-error *ngIf="form.get('name')?.hasError('required')">
            Name is required
          </mat-error>
        </mat-form-field>

        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Email</mat-label>
          <input matInput formControlName="email" type="email" />
          <mat-error *ngIf="form.get('email')?.hasError('email')">
            Invalid email format
          </mat-error>
        </mat-form-field>
      </form>
    </mat-dialog-content>

    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Cancel</button>
      <button
        mat-button
        color="primary"
        [disabled]="!form.valid || isSubmitting"
        (click)="onSubmit()"
      >
        <mat-spinner *ngIf="isSubmitting" diameter="20"></mat-spinner>
        Save
      </button>
    </mat-dialog-actions>
  `,
})
export class FormDialogComponent {
  form: FormGroup;
  @Input() title = 'Form';
  isSubmitting = false;

  constructor(
    private fb: FormBuilder,
    public dialogRef: MatDialogRef<FormDialogComponent>,
    @Inject(MAT_DIALOG_DATA) public data: any
  ) {
    this.form = this.fb.group({
      name: ['', Validators.required],
      email: ['', [Validators.required, Validators.email]],
    });
  }

  onSubmit(): void {
    if (this.form.invalid) return;

    this.isSubmitting = true;
    // Handle submission
    this.dialogRef.close(this.form.value);
  }
}
```

---

## Modal Patterns

### Alert Modal Pattern

```typescript
/**
 * Alert dialog service
 *
 * Usage:
 *   this.alertService.show('Error', 'Something went wrong', 'error');
 */
@Injectable({ providedIn: 'root' })
export class AlertService {
  constructor(private dialog: MatDialog) {}

  show(title: string, message: string, type: 'info' | 'warning' | 'error' | 'success' = 'info'): void {
    const config = {
      width: '400px',
      data: { title, message, type },
    };

    this.dialog.open(AlertModalComponent, config);
  }
}

@Component({
  selector: 'app-alert-modal',
  template: `
    <div class="alert-container" [ngClass]="'alert-' + data.type">
      <mat-icon class="alert-icon">
        {{ getIcon() }}
      </mat-icon>

      <div class="alert-content">
        <h3>{{ data.title }}</h3>
        <p>{{ data.message }}</p>
      </div>

      <button
        mat-icon-button
        class="alert-close"
        (click)="dialogRef.close()"
      >
        <mat-icon>close</mat-icon>
      </button>
    </div>
  `,
  styles: [`
    .alert-container {
      display: flex;
      gap: 16px;
      padding: 16px;
      border-radius: 4px;
    }

    .alert-info {
      background-color: #e3f2fd;
      color: #1976d2;
    }

    .alert-success {
      background-color: #e8f5e9;
      color: #388e3c;
    }

    .alert-warning {
      background-color: #fff3e0;
      color: #f57c00;
    }

    .alert-error {
      background-color: #ffebee;
      color: #d32f2f;
    }

    .alert-icon {
      flex-shrink: 0;
    }

    .alert-content h3 {
      margin: 0 0 8px 0;
      font-size: 16px;
      font-weight: 500;
    }

    .alert-content p {
      margin: 0;
      font-size: 14px;
    }

    .alert-close {
      flex-shrink: 0;
    }
  `],
})
export class AlertModalComponent {
  constructor(
    public dialogRef: MatDialogRef<AlertModalComponent>,
    @Inject(MAT_DIALOG_DATA) public data: any
  ) {}

  getIcon(): string {
    const icons = {
      info: 'info',
      success: 'check_circle',
      warning: 'warning',
      error: 'error',
    };
    return icons[this.data.type] || 'info';
  }
}
```

### Progress Modal Pattern

```typescript
/**
 * Progress modal for long-running operations
 *
 * Usage:
 *   const progressRef = this.progressService.show('Processing...');
 *   // Long operation
 *   progressRef.update({ progress: 50, message: 'Half done' });
 *   progressRef.close();
 */
@Injectable({ providedIn: 'root' })
export class ProgressModalService {
  private currentRef: MatDialogRef<ProgressModalComponent> | null = null;

  constructor(private dialog: MatDialog) {}

  show(title: string, message: string = ''): ProgressRef {
    this.currentRef = this.dialog.open(ProgressModalComponent, {
      width: '400px',
      disableClose: true,
      data: { title, message, progress: 0 },
    });

    return {
      update: (data) => {
        if (this.currentRef) {
          this.currentRef.componentInstance.updateProgress(data);
        }
      },
      close: () => {
        if (this.currentRef) {
          this.currentRef.close();
          this.currentRef = null;
        }
      },
    };
  }
}

interface ProgressRef {
  update(data: { progress?: number; message?: string }): void;
  close(): void;
}

@Component({
  selector: 'app-progress-modal',
  template: `
    <h2 mat-dialog-title>{{ data.title }}</h2>

    <mat-dialog-content>
      <p *ngIf="data.message">{{ data.message }}</p>

      <mat-progress-bar
        mode="determinate"
        [value]="data.progress"
        class="mb-2"
      ></mat-progress-bar>

      <div class="progress-text">
        {{ data.progress }}%
      </div>
    </mat-dialog-content>
  `,
  styles: [`
    .progress-text {
      text-align: center;
      font-size: 12px;
      color: #999;
      margin-top: 8px;
    }
  `],
})
export class ProgressModalComponent {
  constructor(@Inject(MAT_DIALOG_DATA) public data: any) {}

  updateProgress(update: { progress?: number; message?: string }): void {
    if (update.progress !== undefined) {
      this.data.progress = update.progress;
    }
    if (update.message !== undefined) {
      this.data.message = update.message;
    }
  }
}
```

---

## Form Patterns

### Reactive Form Pattern

```typescript
@Component({
  selector: 'app-image-generation-form',
  template: `
    <form [formGroup]="form" (ngSubmit)="onSubmit()" class="form-container">
      <!-- Prompt Input -->
      <mat-form-field appearance="outline" class="full-width">
        <mat-label>Image Description</mat-label>
        <textarea
          matInput
          formControlName="prompt"
          rows="4"
          placeholder="Describe the image you want to generate..."
        ></textarea>
        <mat-hint align="end">{{ form.get('prompt')?.value?.length || 0 }}/2000</mat-hint>
        <mat-error *ngIf="form.get('prompt')?.hasError('required')">
          Prompt is required
        </mat-error>
        <mat-error *ngIf="form.get('prompt')?.hasError('maxlength')">
          Prompt cannot exceed 2000 characters
        </mat-error>
      </mat-form-field>

      <!-- Model Selection -->
      <mat-form-field appearance="outline" class="full-width">
        <mat-label>AI Model</mat-label>
        <mat-select formControlName="model">
          <mat-option value="imagen-3-fast">Imagen 3.0 (Fast)</mat-option>
          <mat-option value="imagen-3">Imagen 3.0 (Quality)</mat-option>
        </mat-select>
      </mat-form-field>

      <!-- Size Selection -->
      <div class="form-row">
        <mat-form-field appearance="outline">
          <mat-label>Width</mat-label>
          <input matInput type="number" formControlName="width" />
        </mat-form-field>

        <mat-form-field appearance="outline">
          <mat-label>Height</mat-label>
          <input matInput type="number" formControlName="height" />
        </mat-form-field>
      </div>

      <!-- Style Selection -->
      <mat-form-field appearance="outline" class="full-width">
        <mat-label>Style</mat-label>
        <mat-select formControlName="style">
          <mat-option value="photorealistic">Photorealistic</mat-option>
          <mat-option value="illustration">Illustration</mat-option>
          <mat-option value="abstract">Abstract</mat-option>
        </mat-select>
      </mat-form-field>

      <!-- Advanced Options (Expandable) -->
      <mat-expansion-panel>
        <mat-expansion-panel-header>
          <mat-panel-title>Advanced Options</mat-panel-title>
        </mat-expansion-panel-header>

        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Negative Prompt</mat-label>
          <textarea matInput formControlName="negativePrompt"></textarea>
        </mat-form-field>

        <mat-slider
          formControlName="quality"
          min="1"
          max="10"
          step="1"
        ></mat-slider>
      </mat-expansion-panel>

      <!-- Actions -->
      <div class="form-actions">
        <button
          mat-button
          type="button"
          (click)="onReset()"
          [disabled]="isLoading"
        >
          Clear
        </button>

        <button
          mat-raised-button
          color="primary"
          type="submit"
          [disabled]="!form.valid || isLoading"
        >
          <mat-spinner *ngIf="isLoading" diameter="20"></mat-spinner>
          Generate Image
        </button>
      </div>

      <!-- Error Display -->
      <mat-error class="form-error" *ngIf="serverError">
        {{ serverError }}
      </mat-error>
    </form>
  `,
  styles: [`
    .form-container {
      display: flex;
      flex-direction: column;
      gap: 16px;
      padding: 16px;
    }

    .form-row {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
    }

    .form-actions {
      display: flex;
      gap: 8px;
      justify-content: flex-end;
    }

    .form-error {
      background-color: #ffebee;
      color: #d32f2f;
      padding: 12px;
      border-radius: 4px;
    }

    .full-width {
      width: 100%;
    }
  `],
})
export class ImageGenerationFormComponent {
  form: FormGroup;
  isLoading = false;
  serverError = '';

  constructor(
    private fb: FormBuilder,
    private imageService: ImageService
  ) {
    this.form = this.fb.group({
      prompt: ['', [Validators.required, Validators.maxLength(2000)]],
      model: ['imagen-3-fast', Validators.required],
      width: [1024, [Validators.required, Validators.min(256), Validators.max(2048)]],
      height: [1024, [Validators.required, Validators.min(256), Validators.max(2048)]],
      style: ['photorealistic', Validators.required],
      negativePrompt: [''],
      quality: [7],
    });
  }

  onSubmit(): void {
    if (!this.form.valid) return;

    this.isLoading = true;
    this.serverError = '';

    this.imageService.generateImage(this.form.value).subscribe({
      next: (result) => {
        this.isLoading = false;
        // Handle success
      },
      error: (error) => {
        this.isLoading = false;
        this.serverError = error.error?.message || 'Failed to generate image';
      },
    });
  }

  onReset(): void {
    this.form.reset({
      model: 'imagen-3-fast',
      width: 1024,
      height: 1024,
      style: 'photorealistic',
      quality: 7,
    });
  }
}
```

### Form Validation Pattern

```typescript
/**
 * Custom validators for forms
 */
export class CustomValidators {
  /**
   * Validate email domain
   */
  static emailDomain(allowedDomains: string[]): ValidatorFn {
    return (control: AbstractControl): ValidationErrors | null => {
      if (!control.value) return null;

      const email = control.value;
      const domain = email.split('@')[1];

      return allowedDomains.includes(domain) ? null : { invalidDomain: true };
    };
  }

  /**
   * Validate password strength
   */
  static passwordStrength(): ValidatorFn {
    return (control: AbstractControl): ValidationErrors | null => {
      if (!control.value) return null;

      const password = control.value;
      const hasUpperCase = /[A-Z]/.test(password);
      const hasLowerCase = /[a-z]/.test(password);
      const hasDigit = /[0-9]/.test(password);
      const hasSpecialChar = /[!@#$%^&*]/.test(password);
      const isLongEnough = password.length >= 8;

      const passwordValid =
        hasUpperCase &&
        hasLowerCase &&
        hasDigit &&
        hasSpecialChar &&
        isLongEnough;

      return passwordValid
        ? null
        : {
            weakPassword: {
              hasUpperCase,
              hasLowerCase,
              hasDigit,
              hasSpecialChar,
              isLongEnough,
            },
          };
    };
  }

  /**
   * Async validator for checking email availability
   */
  static emailAvailable(userService: UserService): AsyncValidatorFn {
    return (control: AbstractControl): Observable<ValidationErrors | null> => {
      if (!control.value) {
        return of(null);
      }

      return userService.checkEmailAvailable(control.value).pipe(
        map((available) => (available ? null : { emailTaken: true })),
        catchError(() => of(null))
      );
    };
  }
}

// Usage in form
this.form = this.fb.group({
  email: [
    '',
    [Validators.required, Validators.email],
    [CustomValidators.emailAvailable(this.userService)],
  ],
  password: ['', [Validators.required, CustomValidators.passwordStrength()]],
});
```

---

## Notification Patterns

### Toast Notification Pattern

```typescript
/**
 * Toast notification service
 *
 * Usage:
 *   this.toast.success('Image generated successfully');
 *   this.toast.error('Failed to upload image');
 *   this.toast.info('Processing image...');
 */
@Injectable({ providedIn: 'root' })
export class ToastService {
  private snackBar = inject(MatSnackBar);

  success(message: string, duration: number = 3000): void {
    this.snackBar.open(message, 'Close', {
      duration,
      horizontalPosition: 'end',
      verticalPosition: 'bottom',
      panelClass: ['toast-success'],
    });
  }

  error(message: string, duration: number = 5000): void {
    this.snackBar.open(message, 'Close', {
      duration,
      horizontalPosition: 'end',
      verticalPosition: 'bottom',
      panelClass: ['toast-error'],
    });
  }

  info(message: string, duration: number = 3000): void {
    this.snackBar.open(message, 'Close', {
      duration,
      horizontalPosition: 'end',
      verticalPosition: 'bottom',
      panelClass: ['toast-info'],
    });
  }

  warning(message: string, duration: number = 4000): void {
    this.snackBar.open(message, 'Close', {
      duration,
      horizontalPosition: 'end',
      verticalPosition: 'bottom',
      panelClass: ['toast-warning'],
    });
  }

  /**
   * Action toast with custom button
   */
  action(
    message: string,
    actionLabel: string,
    callback: () => void
  ): void {
    const snackBarRef = this.snackBar.open(message, actionLabel, {
      duration: 5000,
      horizontalPosition: 'end',
      verticalPosition: 'bottom',
    });

    snackBarRef.onAction().subscribe(() => {
      callback();
    });
  }
}
```

### Custom Notification Component

```typescript
@Component({
  selector: 'app-notification',
  template: `
    <div class="notification-container" [@slideIn]="visible">
      <div class="notification" [ngClass]="'notification-' + type">
        <mat-icon class="notification-icon">{{ getIcon() }}</mat-icon>

        <div class="notification-content">
          <strong>{{ title }}</strong>
          <p *ngIf="message">{{ message }}</p>
        </div>

        <button
          mat-icon-button
          class="notification-close"
          (click)="close()"
        >
          <mat-icon>close</mat-icon>
        </button>
      </div>
    </div>
  `,
  styles: [`
    .notification-container {
      position: fixed;
      top: 16px;
      right: 16px;
      z-index: 1000;
    }

    .notification {
      display: flex;
      gap: 12px;
      padding: 16px;
      border-radius: 4px;
      background-color: white;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
      min-width: 300px;
    }

    .notification-success {
      border-left: 4px solid #4caf50;
      color: #2e7d32;
    }

    .notification-error {
      border-left: 4px solid #f44336;
      color: #c62828;
    }

    .notification-info {
      border-left: 4px solid #2196f3;
      color: #1565c0;
    }

    .notification-warning {
      border-left: 4px solid #ff9800;
      color: #e65100;
    }

    .notification-content {
      flex: 1;
    }

    .notification-content strong {
      display: block;
      margin-bottom: 4px;
    }

    .notification-content p {
      margin: 0;
      font-size: 14px;
    }
  `],
  animations: [
    trigger('slideIn', [
      transition(':enter', [
        style({ transform: 'translateX(400px)', opacity: 0 }),
        animate('300ms ease-out', style({ transform: 'translateX(0)', opacity: 1 })),
      ]),
      transition(':leave', [
        animate('300ms ease-in', style({ transform: 'translateX(400px)', opacity: 0 })),
      ]),
    ]),
  ],
})
export class NotificationComponent {
  @Input() type: 'success' | 'error' | 'info' | 'warning' = 'info';
  @Input() title = '';
  @Input() message = '';
  @Input() duration = 3000;
  @Output() closed = new EventEmitter<void>();

  visible = true;

  ngOnInit(): void {
    setTimeout(() => {
      this.close();
    }, this.duration);
  }

  getIcon(): string {
    const icons = {
      success: 'check_circle',
      error: 'error',
      info: 'info',
      warning: 'warning_amber',
    };
    return icons[this.type];
  }

  close(): void {
    this.visible = false;
    setTimeout(() => this.closed.emit(), 300);
  }
}
```

---

## Loading State Patterns

### Skeleton Loader Pattern

```typescript
@Component({
  selector: 'app-skeleton-loader',
  template: `
    <div class="skeleton" [ngClass]="'skeleton-' + variant">
      <ngx-skeleton-loader
        [count]="count"
        [borderRadius]="borderRadius"
        [height]="height"
        animation="pulse"
        appearance="line"
      ></ngx-skeleton-loader>
    </div>
  `,
  styles: [`
    .skeleton {
      padding: 16px;
    }

    .skeleton-text {
      width: 100%;
      height: 20px;
      border-radius: 4px;
    }

    .skeleton-circle {
      width: 48px;
      height: 48px;
      border-radius: 50%;
    }

    .skeleton-card {
      width: 100%;
      height: 200px;
      border-radius: 8px;
    }

    .skeleton-thumbnail {
      width: 100%;
      aspect-ratio: 1;
      border-radius: 4px;
    }
  `],
})
export class SkeletonLoaderComponent {
  @Input() variant: 'text' | 'circle' | 'card' | 'thumbnail' = 'text';
  @Input() count = 1;
  @Input() borderRadius = '4px';
  @Input() height = '20px';
}
```

### Spinner Overlay Pattern

```typescript
@Component({
  selector: 'app-spinner-overlay',
  template: `
    <div class="spinner-overlay" *ngIf="visible" [@fadeInOut]>
      <mat-spinner [diameter]="diameter"></mat-spinner>
      <p *ngIf="message" class="spinner-message">{{ message }}</p>
    </div>
  `,
  styles: [`
    .spinner-overlay {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background-color: rgba(0, 0, 0, 0.5);
      z-index: 999;
    }

    .spinner-message {
      margin-top: 16px;
      color: white;
      font-size: 14px;
    }
  `],
  animations: [
    trigger('fadeInOut', [
      transition(':enter', [
        style({ opacity: 0 }),
        animate('200ms', style({ opacity: 1 })),
      ]),
      transition(':leave', [
        animate('200ms', style({ opacity: 0 })),
      ]),
    ]),
  ],
})
export class SpinnerOverlayComponent {
  @Input() visible = false;
  @Input() message = '';
  @Input() diameter = 50;
}
```

### Loading State Service

```typescript
@Injectable({ providedIn: 'root' })
export class LoadingService {
  private loadingSubject = new BehaviorSubject<boolean>(false);
  public loading$ = this.loadingSubject.asObservable();

  private messageSubject = new BehaviorSubject<string>('');
  public message$ = this.messageSubject.asObservable();

  show(message: string = ''): void {
    this.messageSubject.next(message);
    this.loadingSubject.next(true);
  }

  hide(): void {
    this.loadingSubject.next(false);
    this.messageSubject.next('');
  }

  withLoading<T>(
    observable: Observable<T>,
    message: string = 'Loading...'
  ): Observable<T> {
    return new Observable((observer) => {
      this.show(message);
      observable.subscribe({
        next: (value) => {
          observer.next(value);
          this.hide();
        },
        error: (error) => {
          observer.error(error);
          this.hide();
        },
        complete: () => {
          observer.complete();
          this.hide();
        },
      });
    });
  }
}

// Usage
ngOnInit(): void {
  this.loadingService
    .withLoading(this.mediaService.getGallery(), 'Loading gallery...')
    .subscribe((data) => {
      this.items = data;
    });
}
```

---

## Error Display Patterns

### Inline Error Pattern

```typescript
@Component({
  selector: 'app-inline-error',
  template: `
    <div class="inline-error" *ngIf="visible" [@slideDown]>
      <mat-icon>error</mat-icon>
      <div class="error-content">
        <strong>{{ title }}</strong>
        <p *ngIf="message">{{ message }}</p>
      </div>
      <button mat-icon-button (click)="close()">
        <mat-icon>close</mat-icon>
      </button>
    </div>
  `,
  styles: [`
    .inline-error {
      display: flex;
      gap: 12px;
      padding: 12px;
      background-color: #ffebee;
      border: 1px solid #ef5350;
      border-radius: 4px;
      color: #c62828;
    }

    .inline-error mat-icon {
      flex-shrink: 0;
    }

    .error-content {
      flex: 1;
    }

    .error-content strong {
      display: block;
      font-size: 14px;
      margin-bottom: 4px;
    }

    .error-content p {
      margin: 0;
      font-size: 12px;
    }
  `],
  animations: [
    trigger('slideDown', [
      transition(':enter', [
        style({ height: 0, opacity: 0 }),
        animate('300ms ease-out', style({ height: '*', opacity: 1 })),
      ]),
      transition(':leave', [
        animate('300ms ease-in', style({ height: 0, opacity: 0 })),
      ]),
    ]),
  ],
})
export class InlineErrorComponent {
  @Input() title = 'Error';
  @Input() message = '';
  @Input() autoClose = 5000;
  @Output() closed = new EventEmitter<void>();

  visible = true;

  ngOnInit(): void {
    if (this.autoClose > 0) {
      setTimeout(() => this.close(), this.autoClose);
    }
  }

  close(): void {
    this.visible = false;
    setTimeout(() => this.closed.emit(), 300);
  }
}
```

### Error State Component

```typescript
@Component({
  selector: 'app-error-state',
  template: `
    <div class="error-state">
      <mat-icon class="error-icon">{{ icon }}</mat-icon>
      <h3>{{ title }}</h3>
      <p class="error-message">{{ message }}</p>

      <div class="error-actions">
        <button
          mat-raised-button
          color="primary"
          *ngIf="showRetry"
          (click)="retry.emit()"
        >
          Try Again
        </button>

        <button
          mat-stroked-button
          (click)="goBack.emit()"
        >
          Go Back
        </button>
      </div>

      <details *ngIf="details" class="error-details">
        <summary>Technical Details</summary>
        <pre>{{ details }}</pre>
      </details>
    </div>
  `,
  styles: [`
    .error-state {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 48px 16px;
      min-height: 400px;
      text-align: center;
    }

    .error-icon {
      font-size: 64px;
      width: 64px;
      height: 64px;
      color: #d32f2f;
      margin-bottom: 16px;
    }

    h3 {
      margin: 0 0 8px 0;
      font-size: 20px;
    }

    .error-message {
      color: #666;
      margin: 0 0 24px 0;
      max-width: 400px;
    }

    .error-actions {
      display: flex;
      gap: 12px;
      margin-bottom: 24px;
    }

    .error-details {
      width: 100%;
      max-width: 600px;
      background-color: #f5f5f5;
      border-radius: 4px;
      padding: 8px;
    }

    .error-details summary {
      cursor: pointer;
      padding: 8px;
      font-size: 12px;
      color: #999;
    }

    .error-details pre {
      margin: 8px 0 0 0;
      font-size: 11px;
      overflow-x: auto;
      color: #666;
    }
  `],
})
export class ErrorStateComponent {
  @Input() title = 'Something Went Wrong';
  @Input() message = 'An error occurred while processing your request.';
  @Input() icon = 'error_outline';
  @Input() showRetry = true;
  @Input() details: string | null = null;
  @Output() retry = new EventEmitter<void>();
  @Output() goBack = new EventEmitter<void>();
}
```

---

## Data Table Patterns

### Responsive Data Table

```typescript
@Component({
  selector: 'app-data-table',
  template: `
    <div class="table-container">
      <!-- Search and Filter Bar -->
      <div class="table-toolbar">
        <mat-form-field appearance="outline" class="search-field">
          <mat-label>Search</mat-label>
          <input matInput [(ngModel)]="searchTerm" placeholder="Search..." />
          <mat-icon matSuffix>search</mat-icon>
        </mat-form-field>

        <button mat-icon-button (click)="refresh()">
          <mat-icon>refresh</mat-icon>
        </button>
      </div>

      <!-- Table -->
      <mat-table [dataSource]="dataSource" class="full-width">
        <!-- Checkbox Column -->
        <ng-container matColumnDef="select">
          <mat-header-cell *matHeaderCellDef>
            <mat-checkbox
              [checked]="selection.hasValue() && isAllSelected()"
              (change)="toggleSelectAll()"
            ></mat-checkbox>
          </mat-header-cell>
          <mat-cell *matCellDef="let row">
            <mat-checkbox
              [checked]="selection.isSelected(row)"
              (change)="selection.toggle(row)"
            ></mat-checkbox>
          </mat-cell>
        </ng-container>

        <!-- Name Column -->
        <ng-container matColumnDef="name">
          <mat-header-cell *matHeaderCellDef>Name</mat-header-cell>
          <mat-cell *matCellDef="let row">{{ row.name }}</mat-cell>
        </ng-container>

        <!-- Email Column -->
        <ng-container matColumnDef="email">
          <mat-header-cell *matHeaderCellDef>Email</mat-header-cell>
          <mat-cell *matCellDef="let row">{{ row.email }}</mat-cell>
        </ng-container>

        <!-- Role Column -->
        <ng-container matColumnDef="role">
          <mat-header-cell *matHeaderCellDef>Role</mat-header-cell>
          <mat-cell *matCellDef="let row">
            <mat-chip [highlighted]=\"row.role === 'admin'\">
              {{ row.role }}
            </mat-chip>
          </mat-cell>
        </ng-container>

        <!-- Actions Column -->
        <ng-container matColumnDef="actions">
          <mat-header-cell *matHeaderCellDef>Actions</mat-header-cell>
          <mat-cell *matCellDef="let row">
            <button mat-icon-button [matMenuTriggerFor]="menu">
              <mat-icon>more_vert</mat-icon>
            </button>
            <mat-menu #menu="matMenu">
              <button mat-menu-item (click)="edit(row)">
                <mat-icon>edit</mat-icon>
                <span>Edit</span>
              </button>
              <button mat-menu-item (click)="delete(row)">
                <mat-icon>delete</mat-icon>
                <span>Delete</span>
              </button>
            </mat-menu>
          </mat-cell>
        </ng-container>

        <!-- Header and Rows -->
        <mat-header-row *matHeaderRowDef="displayedColumns"></mat-header-row>
        <mat-row
          *matRowDef="let row; columns: displayedColumns"
          [ngClass]="{ selected: selection.isSelected(row) }"
        ></mat-row>
      </mat-table>

      <!-- Pagination -->
      <mat-paginator
        [pageSizeOptions]="[10, 25, 50]"
        [pageSize]="pageSize"
        (page)="onPageChange($event)"
      ></mat-paginator>
    </div>
  `,
  styles: [`
    .table-container {
      display: flex;
      flex-direction: column;
      height: 100%;
    }

    .table-toolbar {
      display: flex;
      gap: 12px;
      padding: 16px;
      background-color: #f5f5f5;
    }

    .search-field {
      flex: 1;
      max-width: 300px;
    }

    .full-width {
      width: 100%;
    }

    mat-row.selected {
      background-color: #e3f2fd;
    }
  `],
})
export class DataTableComponent {
  displayedColumns: string[] = ['select', 'name', 'email', 'role', 'actions'];
  selection = new SelectionModel<any>(true, []);
  dataSource: MatTableDataSource<any>;
  pageSize = 10;
  searchTerm = '';

  ngOnInit(): void {
    this.dataSource = new MatTableDataSource(this.data);
    this.dataSource.filterPredicate = (data, filter) => {
      return data.name.toLowerCase().includes(filter) ||
        data.email.toLowerCase().includes(filter);
    };
  }

  isAllSelected(): boolean {
    return this.selection.selected.length === this.dataSource.data.length;
  }

  toggleSelectAll(): void {
    if (this.isAllSelected()) {
      this.selection.clear();
    } else {
      this.dataSource.data.forEach((row) => this.selection.select(row));
    }
  }

  onPageChange(event: PageEvent): void {
    this.pageSize = event.pageSize;
    // Handle pagination
  }

  refresh(): void {
    // Reload data
  }

  edit(row: any): void {
    // Edit action
  }

  delete(row: any): void {
    // Delete action
  }
}
```

---

## Navigation Patterns

### Breadcrumb Navigation

```typescript
@Component({
  selector: 'app-breadcrumb',
  template: `
    <nav aria-label="breadcrumb" class="breadcrumb">
      <ol>
        <li *ngFor="let item of breadcrumbs; let last = last">
          <a
            *ngIf="!last"
            [routerLink]="item.url"
            routerLinkActive="active"
          >
            {{ item.label }}
          </a>
          <span *ngIf="last" class="current">
            {{ item.label }}
          </span>
          <mat-icon *ngIf="!last" class="separator">chevron_right</mat-icon>
        </li>
      </ol>
    </nav>
  `,
  styles: [`
    .breadcrumb {
      padding: 12px 16px;
      background-color: #f5f5f5;
      border-bottom: 1px solid #e0e0e0;
    }

    .breadcrumb ol {
      display: flex;
      align-items: center;
      margin: 0;
      padding: 0;
      list-style: none;
    }

    .breadcrumb li {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .breadcrumb a {
      color: #1976d2;
      text-decoration: none;
      font-size: 14px;
    }

    .breadcrumb a:hover {
      text-decoration: underline;
    }

    .breadcrumb .current {
      color: #666;
      font-size: 14px;
      font-weight: 500;
    }

    .breadcrumb .separator {
      font-size: 20px;
      color: #999;
    }
  `],
})
export class BreadcrumbComponent {
  @Input() breadcrumbs: Array<{ label: string; url?: string }> = [];
}
```

### Sidebar Navigation

```typescript
@Component({
  selector: 'app-sidebar-nav',
  template: `
    <mat-sidenav-container class="sidenav-container">
      <!-- Sidenav -->
      <mat-sidenav
        #sidenav
        mode="side"
        [opened]="!isMobile"
        [fixedInViewport]="isMobile"
        class="sidenav"
      >
        <mat-nav-list>
          <h2 mat-subheader>Main</h2>

          <mat-list-item
            routerLink="/dashboard"
            routerLinkActive="active"
          >
            <mat-icon matListItemIcon>dashboard</mat-icon>
            <span matListItemTitle>Dashboard</span>
          </mat-list-item>

          <mat-list-item
            routerLink="/gallery"
            routerLinkActive="active"
          >
            <mat-icon matListItemIcon>image</mat-icon>
            <span matListItemTitle>Gallery</span>
          </mat-list-item>

          <mat-list-item
            routerLink="/generate"
            routerLinkActive="active"
          >
            <mat-icon matListItemIcon>auto_awesome</mat-icon>
            <span matListItemTitle>Generate</span>
          </mat-list-item>

          <h2 mat-subheader>Admin</h2>

          <mat-list-item
            *ngIf="canAccessAdmin()"
            routerLink="/admin"
            routerLinkActive="active"
          >
            <mat-icon matListItemIcon>admin_panel_settings</mat-icon>
            <span matListItemTitle>Admin Panel</span>
          </mat-list-item>
        </mat-nav-list>
      </mat-sidenav>

      <!-- Content -->
      <mat-sidenav-content>
        <mat-toolbar color="primary">
          <button
            mat-icon-button
            (click)="sidenav.toggle()"
            class="menu-button"
          >
            <mat-icon>menu</mat-icon>
          </button>
          <span class="spacer"></span>
          <button mat-icon-button [matMenuTriggerFor]="profileMenu">
            <mat-icon>account_circle</mat-icon>
          </button>
          <mat-menu #profileMenu="matMenu">
            <button mat-menu-item (click)="logout()">
              <mat-icon>logout</mat-icon>
              <span>Logout</span>
            </button>
          </mat-menu>
        </mat-toolbar>

        <main class="content">
          <router-outlet></router-outlet>
        </main>
      </mat-sidenav-content>
    </mat-sidenav-container>
  `,
  styles: [`
    .sidenav-container {
      height: 100vh;
    }

    .sidenav {
      width: 256px;
    }

    .content {
      padding: 16px;
    }

    .spacer {
      flex: 1 1 auto;
    }
  `],
})
export class SidebarNavComponent {
  @ViewChild('sidenav') sidenav!: MatSidenav;
  isMobile = false;

  constructor(private breakpointObserver: BreakpointObserver) {
    this.breakpointObserver
      .observe(Breakpoints.Handset)
      .subscribe((result) => {
        this.isMobile = result.matches;
      });
  }

  canAccessAdmin(): boolean {
    // Check user role
    return true;
  }

  logout(): void {
    // Handle logout
  }
}
```

---

## Component Examples

### Image Cropper Dialog

Real-world example from the application:

```typescript
@Component({
  selector: 'app-image-cropper-dialog',
  template: `
    <h2 mat-dialog-title>Crop Image</h2>

    <mat-dialog-content>
      <div class="cropper-container">
        <image-cropper
          [imageBase64]="imageSrc"
          [maintainAspectRatio]="true"
          [aspectRatio]="aspectRatio"
          (imageCropped)="imageCropped($event)"
        ></image-cropper>
      </div>

      <div class="aspect-ratio-selector">
        <mat-button-toggle-group [(value)]="aspectRatio">
          <mat-button-toggle value="1/1">Square</mat-button-toggle>
          <mat-button-toggle value="4/3">4:3</mat-button-toggle>
          <mat-button-toggle value="16/9">16:9</mat-button-toggle>
          <mat-button-toggle value="free">Free</mat-button-toggle>
        </mat-button-toggle-group>
      </div>
    </mat-dialog-content>

    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Cancel</button>
      <button
        mat-button
        color="primary"
        [disabled]="!croppedImage"
        (click)="onSave()"
      >
        Save
      </button>
    </mat-dialog-actions>
  `,
  styles: [`
    .cropper-container {
      height: 400px;
      overflow: auto;
    }

    .aspect-ratio-selector {
      margin-top: 16px;
    }
  `],
})
export class ImageCropperDialogComponent {
  imageSrc: string;
  aspectRatio = '1/1';
  croppedImage: any;

  constructor(
    public dialogRef: MatDialogRef<ImageCropperDialogComponent>,
    @Inject(MAT_DIALOG_DATA) public data: { imageSrc: string }
  ) {
    this.imageSrc = data.imageSrc;
  }

  imageCropped(event: any): void {
    this.croppedImage = event.base64;
  }

  onSave(): void {
    this.dialogRef.close(this.croppedImage);
  }
}
```

---

## Accessibility Best Practices

### Semantic HTML

```typescript
// ❌ Bad - Non-semantic elements
<div (click)="doSomething()">Click me</div>

// ✅ Good - Semantic button
<button (click)="doSomething()">Click me</button>

// ❌ Bad - No form labels
<input type="email" />

// ✅ Good - Associated labels
<label for="email">Email Address</label>
<input id="email" type="email" />
```

### ARIA Attributes

```typescript
// Provide context for screen readers
@Component({
  template: `
    <button
      (click)="toggleMenu()"
      [attr.aria-expanded]="isMenuOpen"
      aria-label="Toggle main menu"
    >
      <mat-icon>menu</mat-icon>
    </button>

    <nav *ngIf="isMenuOpen" [attr.role]="'menu'">
      <button
        routerLink="/home"
        [attr.role]="'menuitem'"
        [attr.aria-current]="isActive('/home') ? 'page' : undefined"
      >
        Home
      </button>
    </nav>

    <!-- Loading state -->
    <div [attr.aria-busy]="isLoading" [attr.aria-live]="'polite'">
      <mat-spinner *ngIf="isLoading"></mat-spinner>
      <div *ngIf="!isLoading">Content loaded</div>
    </div>
  `,
})
export class AccessibleComponentComponent {}
```

### Keyboard Navigation

```typescript
@Directive({
  selector: '[appFocusTrap]',
})
export class FocusTrapDirective {
  @HostListener('keydown.tab', ['$event'])
  handleTab(event: KeyboardEvent): void {
    const focusableElements = this.el.nativeElement.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );

    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];

    if (event.shiftKey) {
      if (document.activeElement === firstElement) {
        lastElement.focus();
        event.preventDefault();
      }
    } else {
      if (document.activeElement === lastElement) {
        firstElement.focus();
        event.preventDefault();
      }
    }
  }

  constructor(private el: ElementRef) {}
}
```

### Color Contrast

```css
/* ✅ Good - Sufficient contrast (WCAG AA) */
.text-on-light {
  color: #333;       /* #333 on white = 12.6:1 */
  background: white;
}

/* ❌ Bad - Insufficient contrast */
.text-on-light-bad {
  color: #999;       /* #999 on white = 2.3:1 (fails) */
  background: white;
}

/* ✅ Interactive elements have focus indicators */
button:focus {
  outline: 2px solid #1976d2;
  outline-offset: 2px;
}
```

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Applies To**: Frontend UI/UX patterns and component implementation
- **Related Docs**: FRONTEND_COMPONENTS.md, ADMIN_FEATURES.md, WORKSPACE_FEATURES.md

