# Authentication & Authorization Implementation

## ⚠️ CURRENT STATE: Hybrid Implementation (Needs Refactoring)

Creative Studio currently has a **hybrid authentication setup** that is not optimal:

**Current Stack**:
- **Frontend (Local Dev)**: Firebase SDK + Google provider via `signInWithPopup()`
- **Frontend (Production)**: Deprecated `google.accounts.id` API (hardcoded Google only)
- **User Directory**: PostgreSQL (NOT Firebase Authentication)
- **Token Validation**: Firebase Admin SDK (verifies token authenticity)
- **Metadata Storage**: Firestore (user roles, workspace info)
- **Authorization**: Role-based access control (RBAC) + Workspace-level permissions

**Critical Issues**:
- ❌ No users created in Firebase Authentication
- ❌ No multi-provider support (hardcoded to Google)
- ❌ Deprecated API in production
- ❌ Can't add Okta/SAML without major refactoring

**See Bug Report**: [BUG-002: Hybrid Broken Authentication System](../10-bugs/02_HYBRID_AUTHENTICATION_SYSTEM.md) for detailed analysis and Phase 1 alternatives to fix this

---

## Current Implementation (As-Is)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Firebase Authentication Setup](#firebase-authentication-setup)
3. [Frontend Authentication Flow](#frontend-authentication-flow)
4. [Backend Authentication Flow](#backend-authentication-flow)
5. [Authorization & RBAC](#authorization--rbac)
6. [Workspace-Level Permissions](#workspace-level-permissions)
7. [JWT Token Details](#jwt-token-details)
8. [Just-In-Time User Provisioning](#just-in-time-user-provisioning)
9. [Security Best Practices](#security-best-practices)
10. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### Current Authentication Flow (Actual Implementation)

```
┌─────────────────────────────────────┐
│        User Browser                 │
│   Click "Sign In with Google"       │
└──────────────────┬──────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼ (Local Dev)         ▼ (Production)
┌──────────────────┐  ┌─────────────────────┐
│  Firebase SDK    │  │ google.accounts.id  │
│ signInWithPopup()│  │   (DEPRECATED API)  │
└────────┬─────────┘  └────────┬────────────┘
         │                     │
         └──────────┬──────────┘
                    │
                    ▼
        ┌──────────────────────┐
        │  Google OAuth Server │
        │  (Validates Google   │
        │   credentials)       │
        └──────────┬───────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │  Get JWT Token       │
        │  (Google ID Token)   │
        └──────────┬───────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │  Angular Frontend    │
        │  (Store Token)       │
        └──────────┬───────────┘
                   │
        ┌──────────┴──────────────────┐
        │ 5. Include in API requests  │
        │    Authorization: Bearer X  │
        │                             │
        ▼                             ▼
┌─────────────────────────┐  ┌──────────────────────┐
│    FastAPI Backend      │  │  Firebase Admin SDK  │
│  (OAuth2PasswordBearer) │  │  (Verify Token is    │
│                         │  │   authentic - verify │
│                         │  │   signature only)    │
└────────┬────────────────┘  └──────────┬───────────┘
         │                             │
         │                             ▼
         │                   ┌─────────────────────┐
         │                   │ Token Valid?        │
         │                   │ (Signature OK?)     │
         │                   └────────┬────────────┘
         │                            │
         ├─────────────────────────────┘
         │
         ▼
    ┌──────────────────────────────┐
    │ Extract user email from      │
    │ token payload                │
    └────────┬─────────────────────┘
             │
             ▼
    ┌──────────────────────────────┐
    │ Query PostgreSQL:            │
    │ SELECT user WHERE email=X    │
    │ (NOT Firebase Auth!)         │
    └────────┬─────────────────────┘
             │
             ├─ If not found:
             │  └─→ INSERT new user in PostgreSQL (JIT)
             │     Set default role (Viewer)
             │
             ├─ If found:
             │  └─→ Continue
             │
             ▼
    ┌──────────────────────────────┐
    │ Query Firestore:             │
    │ Get user roles + workspace   │
    │ permissions                  │
    └────────┬─────────────────────┘
             │
             ▼
    ┌──────────────────────────────┐
    │ Check RBAC permissions       │
    │ (Admin/Editor/Viewer)        │
    └────────┬─────────────────────┘
             │
    ┌────────┴──────────┐
    │                   │
    ▼ (Authorized)      ▼ (Denied)
┌─────────────────┐  ┌──────────────┐
│ Execute Request │  │ 403 Forbidden│
└────────┬────────┘  └──────────────┘
         │
         ▼
┌─────────────────────────┐
│ Return Response         │
│ to Frontend             │
└─────────────────────────┘
```

### Key Points About Current Implementation

- **No Firebase Authentication User Directory**: Users are stored in PostgreSQL, not Firebase Auth
- **Token Validation Only**: Firebase Admin SDK only verifies token signature, doesn't create Firebase users
- **Deprecated API in Production**: Uses `google.accounts.id` which is deprecated by Google
- **Google-Only**: No provider federation, can't add Okta/SAML without major changes
- **JIT Provisioning in PostgreSQL**: Creates user record on first sign-in, but in PostgreSQL not Firebase

---

## Firebase Authentication Setup

### Prerequisites

1. **GCP Project**: Already created at `your-gcp-project-id`
2. **Firebase Project**: Linked to GCP project
3. **Google OAuth 2.0 Credentials**: Created in Google Cloud Console

### Firebase Configuration

#### 1. Enable Google Sign-In Provider

**Location**: Firebase Console → Authentication → Sign-in Method

**Steps**:
1. Navigate to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to Authentication → Sign-in method
4. Click "Google" in the list
5. Enable it and select a support email
6. Save

#### 2. Configure Authorized Domains

**Location**: Firebase Console → Authentication → Settings

**Configuration**:
```
Development: localhost:4200
Staging: staging-app.your-domain.com
Production: app.your-domain.com
```

#### 3. Create OAuth 2.0 Client IDs

**Location**: Google Cloud Console → Credentials

**Web Application Credentials**:
```
Authorized JavaScript origins:
  - http://localhost:4200
  - http://localhost:8080
  - https://staging-app.your-domain.com
  - https://app.your-domain.com

Authorized redirect URIs:
  - http://localhost:8080/auth/callback
  - https://api.your-domain.com/auth/callback
```

#### 4. Download Service Account Key

**Location**: Google Cloud Console → Service Accounts

**For Local Development**:
```bash
# Download key from service account details page
# Save to: backend/service-account-key.json
# Add to .gitignore
echo "service-account-key.json" >> backend/.gitignore
```

**For Production**:
- Store key in Google Secret Manager
- Configure Cloud Run to access it
- Never commit to repository

---

## Frontend Authentication Flow

### Firebase Setup in Angular

**File**: `frontend/src/main.ts`

```typescript
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

// Initialize Firebase
const firebaseConfig = {
  apiKey: 'YOUR_API_KEY',
  authDomain: 'your-project.firebaseapp.com',
  projectId: 'your-gcp-project-id',
  storageBucket: 'your-project.appspot.com',
  messagingSenderId: '123456789',
  appId: '1:123456789:web:abc123def456',
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
```

### Authentication Service

**File**: `frontend/src/app/common/services/auth.service.ts`

```typescript
import { Injectable } from '@angular/core';
import { Auth, signInWithPopup, GoogleAuthProvider, signOut, onAuthStateChanged, User } from 'firebase/auth';
import { Router } from '@angular/router';
import { BehaviorSubject, Observable } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private currentUserSubject = new BehaviorSubject<User | null>(null);
  public currentUser$ = this.currentUserSubject.asObservable();

  private isAuthenticatedSubject = new BehaviorSubject<boolean>(false);
  public isAuthenticated$ = this.isAuthenticatedSubject.asObservable();

  private idTokenSubject = new BehaviorSubject<string | null>(null);
  public idToken$ = this.idTokenSubject.asObservable();

  constructor(private auth: Auth, private router: Router) {
    this.initializeAuthListener();
  }

  /**
   * Initialize auth state listener
   * Fires whenever authentication state changes
   */
  private initializeAuthListener(): void {
    onAuthStateChanged(this.auth, async (user) => {
      this.currentUserSubject.next(user);
      this.isAuthenticatedSubject.next(!!user);

      if (user) {
        // Get fresh ID token
        const idToken = await user.getIdToken();
        this.idTokenSubject.next(idToken);
        console.log('User authenticated:', user.email);
      } else {
        this.idTokenSubject.next(null);
        console.log('User logged out');
      }
    });
  }

  /**
   * Sign in with Google
   * Opens OAuth dialog and creates Firebase user if new
   */
  async signInWithGoogle(): Promise<void> {
    try {
      const provider = new GoogleAuthProvider();
      // Add custom scope for user profile
      provider.addScope('profile');
      provider.addScope('email');

      const result = await signInWithPopup(this.auth, provider);
      console.log('Sign-in successful:', result.user.email);

      // Navigate to dashboard after successful sign-in
      this.router.navigate(['/dashboard']);
    } catch (error: any) {
      console.error('Sign-in error:', error);
      throw error;
    }
  }

  /**
   * Sign out user
   * Clears local state and redirects to login
   */
  async signOut(): Promise<void> {
    try {
      await signOut(this.auth);
      this.router.navigate(['/login']);
      console.log('User signed out');
    } catch (error) {
      console.error('Sign-out error:', error);
    }
  }

  /**
   * Get current ID token (JWT)
   * Used for API requests in Authorization header
   */
  async getIdToken(): Promise<string | null> {
    const user = this.auth.currentUser;
    if (!user) {
      return null;
    }

    try {
      // Force refresh to get latest token with current claims
      return await user.getIdToken(true);
    } catch (error) {
      console.error('Error getting ID token:', error);
      return null;
    }
  }

  /**
   * Check if user is authenticated
   */
  isAuthenticated(): boolean {
    return this.isAuthenticatedSubject.value;
  }

  /**
   * Get current user
   */
  getCurrentUser(): User | null {
    return this.currentUserSubject.value;
  }

  /**
   * Get custom claims from token
   * Contains user roles and workspace info
   */
  async getCustomClaims(): Promise<any> {
    const user = this.auth.currentUser;
    if (!user) {
      return null;
    }

    try {
      const tokenResult = await user.getIdTokenResult(true);
      return tokenResult.claims;
    } catch (error) {
      console.error('Error getting custom claims:', error);
      return null;
    }
  }
}
```

### Auth Interceptor

**File**: `frontend/src/app/auth.interceptor.ts`

```typescript
import { Injectable } from '@angular/core';
import {
  HttpInterceptor,
  HttpRequest,
  HttpHandler,
  HttpEvent,
} from '@angular/common/http';
import { Observable, from } from 'rxjs';
import { switchMap, catchError } from 'rxjs/operators';
import { AuthService } from './common/services/auth.service';

@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  constructor(private authService: AuthService) {}

  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    // Skip adding token to non-API requests
    if (!req.url.includes('/api/')) {
      return next.handle(req);
    }

    // Get ID token and add to Authorization header
    return from(this.authService.getIdToken()).pipe(
      switchMap((idToken) => {
        if (!idToken) {
          // No token - let request go through without auth
          return next.handle(req);
        }

        // Clone request and add Authorization header
        const authReq = req.clone({
          setHeaders: {
            Authorization: `Bearer ${idToken}`,
          },
        });

        return next.handle(authReq);
      }),
      catchError((error) => {
        console.error('Auth interceptor error:', error);
        throw error;
      })
    );
  }
}
```

**Register Interceptor in App Module**:

**File**: `frontend/src/app/app.config.ts`

```typescript
import { ApplicationConfig, importProvidersFrom } from '@angular/core';
import { provideHttpClient, withInterceptors, HTTP_INTERCEPTORS } from '@angular/common/http';
import { AuthInterceptor } from './auth.interceptor';

export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(
      withInterceptors([
        // Custom interceptors here
      ])
    ),
    {
      provide: HTTP_INTERCEPTORS,
      useClass: AuthInterceptor,
      multi: true,
    },
  ],
};
```

### Auth Guard

**File**: `frontend/src/app/auth.guard.ts`

```typescript
import { Injectable } from '@angular/core';
import { Router, CanActivate, ActivatedRouteSnapshot, RouterStateSnapshot } from '@angular/router';
import { Observable } from 'rxjs';
import { map, take } from 'rxjs/operators';
import { AuthService } from './common/services/auth.service';

@Injectable({ providedIn: 'root' })
export class AuthGuard implements CanActivate {
  constructor(private authService: AuthService, private router: Router) {}

  canActivate(
    route: ActivatedRouteSnapshot,
    state: RouterStateSnapshot
  ): Observable<boolean> {
    return this.authService.isAuthenticated$.pipe(
      take(1),
      map((isAuthenticated) => {
        if (isAuthenticated) {
          return true;
        }

        // Not authenticated - redirect to login
        this.router.navigate(['/login'], {
          queryParams: { returnUrl: state.url },
        });
        return false;
      })
    );
  }
}
```

**Usage in Routing**:

```typescript
const routes: Routes = [
  { path: 'login', component: LoginComponent },
  {
    path: 'dashboard',
    component: DashboardComponent,
    canActivate: [AuthGuard], // Protected route
  },
];
```

---

## Backend Authentication Flow

### Firebase Admin SDK Setup

**File**: `backend/src/config/firebase_admin.py`

```python
import firebase_admin
from firebase_admin import credentials, auth as firebase_auth
from google.auth import default as google_default
import os

class FirebaseAdminService:
    """Initialize and manage Firebase Admin SDK"""

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(FirebaseAdminService, cls).__new__(cls)
            cls._instance._initialize()
        return cls._instance

    def _initialize(self):
        """Initialize Firebase Admin SDK"""
        # Try to use service account key file first
        service_account_path = os.getenv('GOOGLE_APPLICATION_CREDENTIALS')

        if service_account_path and os.path.exists(service_account_path):
            # Use service account key
            cred = credentials.Certificate(service_account_path)
        else:
            # Use Application Default Credentials (ADC)
            # Works in Cloud Run with service account
            cred, _ = google_default()

        # Initialize Firebase Admin SDK
        firebase_admin.initialize_app(cred, {
            'projectId': os.getenv('PROJECT_ID'),
        })

    @staticmethod
    def get_auth_client():
        """Get Firebase Auth client"""
        return firebase_auth

    @staticmethod
    def verify_token(token: str) -> dict:
        """
        Verify Firebase ID token

        Args:
            token: Firebase ID token (JWT)

        Returns:
            Decoded token with user claims

        Raises:
            firebase_admin.auth.InvalidIdTokenError: Token is invalid
            firebase_admin.auth.ExpiredIdTokenError: Token is expired
        """
        try:
            decoded_token = firebase_auth.verify_id_token(token)
            return decoded_token
        except firebase_auth.InvalidIdTokenError as e:
            raise ValueError(f'Invalid token: {str(e)}')
        except firebase_auth.ExpiredIdTokenError as e:
            raise ValueError(f'Token expired: {str(e)}')

    @staticmethod
    def get_user(user_id: str):
        """Get Firebase user by UID"""
        return firebase_auth.get_user(user_id)

    @staticmethod
    def create_user(email: str, display_name: str = None) -> str:
        """
        Create Firebase user (for JIT provisioning)

        Args:
            email: User email
            display_name: Optional display name

        Returns:
            User UID
        """
        return firebase_auth.create_user(
            email=email,
            display_name=display_name,
            email_verified=True,  # Skip email verification for Google OAuth
        ).uid

    @staticmethod
    def set_custom_claims(user_id: str, claims: dict):
        """
        Set custom claims on Firebase user (e.g., roles)

        Args:
            user_id: Firebase user UID
            claims: Dictionary of custom claims
        """
        firebase_auth.set_custom_claims(user_id, claims)

    @staticmethod
    def get_custom_claims(user_id: str) -> dict:
        """Get custom claims for user"""
        user = firebase_auth.get_user(user_id)
        return user.custom_claims or {}


# Singleton instance
firebase_admin_service = FirebaseAdminService()
```

### OAuth2 Dependency

**File**: `backend/src/security/oauth2.py`

```python
from fastapi.security import HTTPBearer, HTTPAuthCredentials
from fastapi import Depends, HTTPException, status
from src.config.firebase_admin import firebase_admin_service
import logging

logger = logging.getLogger(__name__)

security = HTTPBearer()

async def get_current_user(credentials: HTTPAuthCredentials = Depends(security)) -> dict:
    """
    Dependency to verify Firebase ID token and extract user claims

    Args:
        credentials: HTTP Bearer token from request header

    Returns:
        Decoded token with user claims (uid, email, custom claims, etc.)

    Raises:
        HTTPException: 401 if token invalid/expired
    """
    token = credentials.credentials

    try:
        # Verify token with Firebase Admin SDK
        decoded_token = firebase_admin_service.verify_token(token)

        # Log successful authentication
        user_email = decoded_token.get('email', 'unknown')
        logger.info(f'User authenticated: {user_email}')

        return decoded_token

    except ValueError as e:
        logger.warning(f'Token verification failed: {str(e)}')
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f'Invalid authentication credentials: {str(e)}',
            headers={'WWW-Authenticate': 'Bearer'},
        )
    except Exception as e:
        logger.error(f'Unexpected auth error: {str(e)}')
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Authentication failed',
            headers={'WWW-Authenticate': 'Bearer'},
        )


async def get_current_user_email(current_user: dict = Depends(get_current_user)) -> str:
    """Extract email from decoded token"""
    return current_user.get('email')


async def get_current_user_uid(current_user: dict = Depends(get_current_user)) -> str:
    """Extract Firebase UID from decoded token"""
    return current_user.get('uid')
```

### Protected Endpoints

**File**: `backend/src/routes/images_controller.py`

```python
from fastapi import APIRouter, Depends, HTTPException, status
from src.security.oauth2 import get_current_user, get_current_user_email
from src.services.image_service import ImageService
from src.models.schemas import ImageRequest, ImageResponse
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix='/api/images', tags=['images'])
image_service = ImageService()

@router.post('', response_model=ImageResponse)
async def generate_image(
    request: ImageRequest,
    current_user: dict = Depends(get_current_user),
    user_email: str = Depends(get_current_user_email),
):
    """
    Generate image with Imagen 3.0

    Args:
        request: Image generation request
        current_user: Decoded Firebase token with all claims
        user_email: Extracted user email

    Returns:
        Generated image metadata
    """
    logger.info(f'User {user_email} requesting image generation')

    try:
        # Check if user has permission (optional, depends on workspace)
        # await check_user_workspace_permission(user_email, request.workspace_id)

        # Call service to generate image
        result = await image_service.generate_image(
            prompt=request.prompt,
            style=request.style,
            size=request.size,
            user_email=user_email,
            uid=current_user.get('uid'),
        )

        return result

    except ValueError as e:
        logger.error(f'Validation error: {str(e)}')
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        logger.error(f'Image generation error: {str(e)}')
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail='Failed to generate image',
        )

@router.get('/{image_id}', response_model=ImageResponse)
async def get_image(
    image_id: str,
    current_user: dict = Depends(get_current_user),
    user_email: str = Depends(get_current_user_email),
):
    """
    Get image details

    Verifies user owns the image before returning
    """
    try:
        result = await image_service.get_image(image_id, user_email)
        return result
    except PermissionError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='You do not have permission to access this resource',
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail='Image not found',
        )
```

---

## Authorization & RBAC

### Role Definitions

**File**: `backend/src/models/user_model.py`

```python
from enum import Enum
from typing import List

class UserRoleEnum(str, Enum):
    """User roles in the system"""
    ADMIN = 'admin'      # Full access to workspace
    EDITOR = 'editor'    # Can create/edit/delete media
    VIEWER = 'viewer'    # Read-only access

class UserModel:
    """User model with roles and permissions"""

    def __init__(
        self,
        id: str,
        email: str,
        roles: List[UserRoleEnum],
        workspace_id: str,
        display_name: str = None,
    ):
        self.id = id
        self.email = email
        self.roles = roles
        self.workspace_id = workspace_id
        self.display_name = display_name

    def has_role(self, role: UserRoleEnum) -> bool:
        """Check if user has specific role"""
        return role in self.roles

    def can_edit(self) -> bool:
        """Check if user can edit content"""
        return self.has_role(UserRoleEnum.ADMIN) or self.has_role(UserRoleEnum.EDITOR)

    def can_delete(self) -> bool:
        """Check if user can delete content"""
        return self.has_role(UserRoleEnum.ADMIN)

    def to_dict(self) -> dict:
        return {
            'id': self.id,
            'email': self.email,
            'roles': self.roles,
            'workspace_id': self.workspace_id,
            'display_name': self.display_name,
        }
```

### Role-Based Access Control Decorator

**File**: `backend/src/security/authorization.py`

```python
from fastapi import HTTPException, status, Depends
from functools import wraps
from src.security.oauth2 import get_current_user
from src.models.user_model import UserRoleEnum
from typing import List
import logging

logger = logging.getLogger(__name__)

def require_role(required_roles: List[UserRoleEnum]):
    """
    Decorator to check if user has required role

    Usage:
        @require_role([UserRoleEnum.ADMIN])
        async def admin_only_endpoint(current_user: dict = Depends(get_current_user)):
            pass
    """
    async def role_checker(current_user: dict = Depends(get_current_user)):
        user_roles = current_user.get('custom_claims', {}).get('roles', [])

        # Check if user has any of the required roles
        if not any(role in user_roles for role in required_roles):
            logger.warning(
                f'User {current_user.get("email")} lacks required roles: {required_roles}'
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f'This action requires one of these roles: {required_roles}',
            )

        return current_user

    return role_checker
```

**Usage**:

```python
from src.security.authorization import require_role

@router.delete('/{workspace_id}')
async def delete_workspace(
    workspace_id: str,
    current_user: dict = Depends(require_role([UserRoleEnum.ADMIN])),
):
    """Only admins can delete workspaces"""
    # Implementation
    pass
```

---

## Workspace-Level Permissions

### Permission Model

**File**: `backend/src/models/workspace_model.py`

```python
from typing import List, Optional
from datetime import datetime
from src.models.user_model import UserRoleEnum

class WorkspacePermissionModel:
    """Workspace membership and permissions"""

    def __init__(
        self,
        user_id: str,
        user_email: str,
        role: UserRoleEnum,
        joined_at: datetime,
    ):
        self.user_id = user_id
        self.user_email = user_email
        self.role = role
        self.joined_at = joined_at

    def can_edit_workspace(self) -> bool:
        """Can user edit workspace settings"""
        return self.role in [UserRoleEnum.ADMIN]

    def can_manage_members(self) -> bool:
        """Can user add/remove members"""
        return self.role in [UserRoleEnum.ADMIN]

    def can_view_analytics(self) -> bool:
        """Can user view workspace analytics"""
        return self.role in [UserRoleEnum.ADMIN, UserRoleEnum.EDITOR]

class WorkspaceModel:
    """Workspace with members and settings"""

    def __init__(
        self,
        id: str,
        name: str,
        owner_id: str,
        members: List[WorkspacePermissionModel],
    ):
        self.id = id
        self.name = name
        self.owner_id = owner_id
        self.members = members

    def get_user_role(self, user_id: str) -> Optional[UserRoleEnum]:
        """Get user's role in workspace"""
        for member in self.members:
            if member.user_id == user_id:
                return member.role
        return None

    def is_member(self, user_id: str) -> bool:
        """Check if user is member of workspace"""
        return any(m.user_id == user_id for m in self.members)
```

### Permission Check Dependency

**File**: `backend/src/security/workspace_permission.py`

```python
from fastapi import Depends, HTTPException, status
from src.security.oauth2 import get_current_user, get_current_user_uid
from src.services.workspace_service import WorkspaceService
from src.models.user_model import UserRoleEnum
import logging

logger = logging.getLogger(__name__)

workspace_service = WorkspaceService()

async def check_workspace_access(
    workspace_id: str,
    current_user: dict = Depends(get_current_user),
    user_uid: str = Depends(get_current_user_uid),
) -> dict:
    """
    Check if user has access to workspace

    Raises:
        HTTPException: 403 if user not member of workspace
    """
    # Get workspace and check membership
    workspace = await workspace_service.get_workspace(workspace_id)

    if not workspace.is_member(user_uid):
        logger.warning(
            f'User {current_user.get("email")} attempted access to unauthorized workspace {workspace_id}'
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='You do not have access to this workspace',
        )

    return workspace


async def check_workspace_edit_permission(
    workspace_id: str,
    workspace: dict = Depends(check_workspace_access),
    user_uid: str = Depends(get_current_user_uid),
) -> dict:
    """Check if user can edit workspace (admin role required)"""
    user_role = workspace.get_user_role(user_uid)

    if user_role != UserRoleEnum.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='Only workspace admins can perform this action',
        )

    return workspace
```

**Usage**:

```python
@router.patch('/{workspace_id}')
async def update_workspace(
    workspace_id: str,
    request: WorkspaceUpdateRequest,
    workspace: dict = Depends(check_workspace_edit_permission),
):
    """Update workspace (admin only)"""
    # Implementation
    pass
```

---

## JWT Token Details

### Token Structure

Firebase ID tokens are JWTs with the following structure:

```
Header:
{
  "alg": "RS256",
  "kid": "key-id",
  "typ": "JWT"
}

Payload (Claims):
{
  "iss": "https://securetoken.google.com/your-gcp-project-id",
  "aud": "your-gcp-project-id",
  "auth_time": 1642262400,
  "user_id": "firebase-user-uid",
  "sub": "firebase-user-uid",
  "iat": 1642262400,
  "exp": 1642266000,
  "email": "user@example.com",
  "email_verified": true,
  "firebase": {
    "identities": {
      "google.com": ["google-user-id"],
      "email": ["user@example.com"]
    },
    "sign_in_provider": "google.com"
  },
  "custom_claims": {
    "roles": ["editor", "viewer"],
    "workspace_id": "workspace-123"
  }
}

Signature:
HMACSHA256(
  base64UrlEncode(header) + "." +
  base64UrlEncode(payload),
  secret
)
```

### Token Expiration

- **Lifetime**: 1 hour (3600 seconds)
- **Refresh**: Automatically handled by Firebase SDK (frontend calls `getIdToken(true)`)
- **Backend**: Always verify token signature and expiration

### Custom Claims

Custom claims can be set on Firebase users to store application-specific data:

```python
# Set custom claims
firebase_admin_service.set_custom_claims(user_uid, {
    'roles': ['editor', 'viewer'],
    'workspace_id': 'workspace-123',
})

# Claims appear in ID token on next authentication
# Claims also cached for 5 minutes after setting
```

---

## Just-In-Time User Provisioning

### Concept

Users are created in Firestore automatically on their first sign-in with Google. This avoids manual user management.

### Implementation

**File**: `backend/src/services/user_service.py`

```python
from src.config.firebase_admin import firebase_admin_service
from src.repositories.firestore_repository import FirestoreRepository
from src.models.user_model import UserModel, UserRoleEnum
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class UserService:
    """User management and JIT provisioning"""

    def __init__(self):
        self.firestore = FirestoreRepository()
        self.firebase_admin = firebase_admin_service

    async def get_or_create_user(self, decoded_token: dict) -> UserModel:
        """
        Get existing user or create new one (JIT provisioning)

        Args:
            decoded_token: Decoded Firebase ID token with user claims

        Returns:
            UserModel instance
        """
        user_email = decoded_token.get('email')
        user_uid = decoded_token.get('uid')

        # Check if user exists in Firestore
        existing_user = await self.firestore.get_document('users', user_uid)

        if existing_user:
            logger.info(f'Returning existing user: {user_email}')
            return UserModel(
                id=user_uid,
                email=existing_user['email'],
                roles=[UserRoleEnum(r) for r in existing_user.get('roles', ['viewer'])],
                workspace_id=existing_user.get('workspace_id'),
                display_name=existing_user.get('display_name'),
            )

        # User doesn't exist - create new one
        logger.info(f'Creating new user via JIT: {user_email}')

        # Create user document
        user_data = {
            'email': user_email,
            'display_name': decoded_token.get('name', ''),
            'roles': ['viewer'],  # Default role
            'workspace_id': None,  # No workspace yet
            'avatar_uri': decoded_token.get('picture', ''),
            'created_at': datetime.utcnow().isoformat(),
            'last_login': datetime.utcnow().isoformat(),
        }

        await self.firestore.set_document('users', user_uid, user_data)

        # Set custom claims
        self.firebase_admin.set_custom_claims(user_uid, {
            'roles': ['viewer'],
            'provisioned_at': datetime.utcnow().isoformat(),
        })

        logger.info(f'User created successfully: {user_email}')

        return UserModel(
            id=user_uid,
            email=user_email,
            roles=[UserRoleEnum.VIEWER],
            workspace_id=None,
            display_name=user_data['display_name'],
        )

    async def update_last_login(self, user_uid: str):
        """Update last login timestamp"""
        await self.firestore.update_document('users', user_uid, {
            'last_login': datetime.utcnow().isoformat(),
        })

    async def assign_workspace(self, user_uid: str, workspace_id: str):
        """Assign user to default workspace"""
        await self.firestore.update_document('users', user_uid, {
            'workspace_id': workspace_id,
        })
```

### Integration in Protected Endpoints

```python
from src.services.user_service import UserService

user_service = UserService()

@router.post('/api/galleries')
async def create_gallery_item(
    request: GalleryRequest,
    current_user: dict = Depends(get_current_user),
):
    """Create gallery item (with JIT user provisioning)"""

    # Provision user if first login
    user = await user_service.get_or_create_user(current_user)

    # Update last login
    await user_service.update_last_login(user.id)

    # Continue with request processing
    # ...
```

### Admin User Auto-Configuration

When a user authenticates, the system checks if their email matches the configured `ADMIN_USER_EMAIL` environment variable. If it does:

- The system automatically assigns the `ADMIN` role if not already present
- This check occurs on **every login**, ensuring admins always retain access
- If an admin's role was accidentally removed, it will be restored on next login
- The admin email is configured via the `ADMIN_USER_EMAIL` environment variable

**Configuration**:
```python
# In your environment or Cloud Secret Manager
ADMIN_USER_EMAIL="your-admin@example.com"
```

**Implementation** (`backend/src/auth/auth_guard.py`):
```python
# Ensure the configured admin user always has admin role
if email == config_service.ADMIN_USER_EMAIL:
    if UserRoleEnum.ADMIN not in user_doc.roles:
        logger.info(f"Granting admin role to configured admin user: {email}")
        updated_roles = list(set(user_doc.roles) | {UserRoleEnum.ADMIN})
        await user_service.user_repo.update(user_doc.id, {"roles": updated_roles})
        user_doc.roles = [UserRoleEnum(role) if isinstance(role, str) else role for role in updated_roles]
```

**Why This Matters**: This ensures your configured administrator can always manage the system, even if their role is accidentally removed or if there's an issue with the initial provisioning.

---

## Security Best Practices

### 1. Token Storage

**Frontend**:
```typescript
// ❌ DON'T - Store in localStorage (XSS vulnerability)
localStorage.setItem('idToken', token);

// ✅ DO - Keep in memory or sessionStorage temporarily
// Firebase SDK handles this for you
// Only request token when needed via getIdToken()
```

**Why**: In-memory tokens are cleared on page refresh, reducing XSS exposure. Firebase SDK manages token lifecycle automatically.

### 2. Token Validation

**Backend**:
```python
# ✅ Always verify token signature and expiration
decoded_token = firebase_admin_service.verify_token(token)

# Includes:
# - Signature verification with Firebase public keys
# - Expiration check
# - Audience verification (must match PROJECT_ID)
# - Issuer verification (must be Firebase issuer)
```

### 3. HTTPS Only

**Infrastructure**:
- **Development**: http://localhost (OK for local testing)
- **Production**: HTTPS required (enforced by CDN)
- **Never**: Transmit tokens over HTTP in production

### 4. CORS Configuration

**Backend** (`main.py`):
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        'http://localhost:4200',
        'https://app.your-domain.com',
        'https://staging-app.your-domain.com',
    ],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)
```

### 5. Role-Based Access Control

```python
# ✅ Always check user role before sensitive operations
@router.delete('/{workspace_id}')
async def delete_workspace(
    workspace_id: str,
    current_user: dict = Depends(require_role([UserRoleEnum.ADMIN])),
):
    pass

# ❌ Never trust client-side role claims
# Always verify on backend
```

### 6. Workspace Isolation

```python
# ✅ Always check workspace membership
@router.get('/{workspace_id}/items')
async def get_workspace_items(
    workspace_id: str,
    workspace: dict = Depends(check_workspace_access),
):
    # User is confirmed member of workspace
    pass
```

### 7. Custom Claims Management

```python
# ✅ Set custom claims server-side only
firebase_admin_service.set_custom_claims(user_uid, {
    'roles': updated_roles,
})

# ❌ Never trust custom claims from frontend
# Always verify on backend after token verification
```

### 8. Refresh Token Strategy

**Frontend**:
```typescript
// Firebase SDK automatically handles:
// 1. Getting fresh token on each request
// 2. Refreshing expired tokens
// 3. Clearing invalid tokens

// No manual refresh token management needed
```

### 9. Secure Headers

**Backend**:
```python
# Add security headers
from fastapi.responses import JSONResponse

@app.middleware('http')
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000'
    return response
```

### 10. Logging & Monitoring

```python
# Log authentication events (not sensitive data)
logger.info(f'User {user_email} authenticated')
logger.warning(f'Failed auth attempt: invalid token')
logger.error(f'Auth error: {error_type}')

# ❌ Never log:
# - Full tokens
# - Passwords
# - API keys
# - Personal user data
```

---

## Troubleshooting

### Issue: "Invalid token" Error

**Cause**: Token expired, invalid, or doesn't match project

**Solution**:
1. Verify token is being sent in `Authorization: Bearer` header
2. Check token isn't expired (1 hour lifetime)
3. Verify PROJECT_ID in environment matches Firebase project
4. Check GOOGLE_TOKEN_AUDIENCE is correct OAuth client ID

**Frontend Debug**:
```typescript
// Check token
const token = await this.authService.getIdToken();
console.log('Token:', token); // Should be non-null

// Check custom claims
const claims = await this.authService.getCustomClaims();
console.log('Claims:', claims);
```

**Backend Debug**:
```python
# Enable detailed logging
import logging
logging.basicConfig(level=logging.DEBUG)

# Check decoded token
try:
    decoded = firebase_admin_service.verify_token(token)
    print('Decoded:', decoded)
except Exception as e:
    print('Error:', e)
```

### Issue: "CORS error" on API calls

**Cause**: Frontend and backend have mismatched origins

**Solution**:
1. Check CORS configuration includes frontend URL
2. Verify frontend URL in Firebase authorized domains
3. Ensure request includes credentials header

```typescript
// Frontend
this.http.post(url, data, {
  withCredentials: true, // Important for cookies
});
```

```python
# Backend
CORSMiddleware(
    allow_origins=['http://localhost:4200'],
    allow_credentials=True,
)
```

### Issue: User not provisioned after first login

**Cause**: JIT provisioning not running or Firestore error

**Solution**:
1. Check Firestore has read/write permissions
2. Verify service account has `firestore.admin` role
3. Check `users` collection exists in Firestore
4. Enable debug logging

```python
logger.setLevel(logging.DEBUG)
# Should see "Creating new user via JIT" in logs
```

### Issue: Custom claims not appearing in token

**Cause**: Claims cached for 5 minutes, or not set correctly

**Solution**:
1. Wait 5 minutes for cache to expire
2. Or force token refresh: `getIdToken(true)` in frontend
3. Verify custom claims were set: `firebase_auth.get_user(uid).custom_claims`

### Issue: 403 Forbidden on protected endpoint

**Cause**: User lacks required role or workspace access

**Solution**:
1. Check user has correct role assigned
2. Verify user is member of workspace
3. Check role-based decorator is correct

**Debug**:
```python
# Check user roles
claims = decoded_token.get('custom_claims', {})
print('User roles:', claims.get('roles'))

# Check workspace membership
workspace = await workspace_service.get_workspace(workspace_id)
print('Is member:', workspace.is_member(user_uid))
```

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Applies To**: Authentication & Authorization flows
- **Related Docs**: ENVIRONMENT_VARIABLES.md, API_REFERENCE.md, 02_DATA_FLOW_PATTERNS.md
