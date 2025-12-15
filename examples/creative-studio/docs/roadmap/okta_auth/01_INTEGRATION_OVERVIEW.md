# Okta Authentication Integration Roadmap

* [signed_url_validation_with_okta](https://share.google/aimode/qK0v08BCtkeUToAgU)

## Executive Summary

**STATUS**: Future implementation - This document outlines the planned integration of Okta authentication for Creative Studio.

**CURRENT STATE**: Creative Studio currently uses Google Identity Platform/Firebase Authentication (see ARCHITECTURE.md, COMPONENT_DIAGRAM.md, and INFRASTRUCTURE.md for current implementation details).

**PURPOSE**: This roadmap provides a comprehensive plan for integrating Okta as the authentication provider, replacing Google Identity Platform/Firebase Authentication. The integration will affect both **frontend (Angular)** and **backend (FastAPI)** components. Okta credentials (Client ID, Client Secret) must be securely stored in Google Secret Manager, not in code.

**IMPORTANT**: This is a future-state document. The current application architecture, documentation, and implementation remain unchanged. This roadmap is for planning and future execution only.

---

## Related Documentation

**For current implementation details, refer to:**
- **ARCHITECTURE.md** - Current system architecture and technology stack
- **COMPONENT_DIAGRAM.md** - Visual diagrams of all components and their interactions
- **INFRASTRUCTURE.md** - Infrastructure setup, Terraform configuration, and GCP services
- **02_DATA_FLOW_PATTERNS.md** - Data flow and component interactions in the current system

These documents describe the **present state** of Creative Studio. The Okta roadmap below describes the **future state** if this integration is approved and executed.

---

## Table of Contents

1. [Current Authentication Architecture](#current-authentication-architecture)
2. [Okta Integration Options](#okta-integration-options)
3. [Recommended Approach](#recommended-approach)
4. [Detailed Implementation Plan](#detailed-implementation-plan)
5. [Frontend Changes](#frontend-changes)
6. [Backend Changes](#backend-changes)
7. [Secrets Management](#secrets-management)
8. [Testing & Validation](#testing--validation)
9. [Migration Path](#migration-path)
10. [Rollback Plan](#rollback-plan)

---

## Current Authentication Architecture

### Frontend (Angular)
- **Location**: `frontend/src/app/common/services/auth.service.ts`
- **Current Flow**:
  1. User signs in with Google via Firebase Auth or Google Identity Platform
  2. Frontend receives an ID token (JWT)
  3. Token is stored in `localStorage` with expiry time
  4. Token is attached to API requests via `auth.interceptor.ts` with `Authorization: Bearer <token>` header
  5. User details synced from backend to `localStorage` on login

- **Key Files**:
  - `auth.service.ts`: Main authentication service
  - `auth.interceptor.ts`: Adds Bearer token to HTTP requests
  - `auth.guard.service.ts`: Route protection for authenticated pages
  - `environment.ts` / `environment.prod.ts`: Configuration (GOOGLE_CLIENT_ID, Firebase config)

### Backend (FastAPI)
- **Location**: `backend/src/auth/auth_guard.py`
- **Current Flow**:
  1. Receives request with `Authorization: Bearer <token>` header
  2. Validates token using:
     - Local: Firebase Admin SDK (`auth.verify_id_token()`)
     - Dev/Prod: Google Identity Platform (`id_token.verify_oauth2_token()`)
  3. Extracts user email, name, picture from token claims
  4. Performs Just-In-Time (JIT) user provisioning in Firestore
  5. Returns user document for API request processing

- **Key Files**:
  - `auth_guard.py`: Token validation & user provisioning
  - `config_service.py`: Configuration (GOOGLE_TOKEN_AUDIENCE, ALLOWED_ORGS)
  - `user_service.py`: User provisioning logic

### Configuration
- **Frontend**:
  - `GOOGLE_CLIENT_ID`: env variable or hardcoded in `environment.ts`
  - Firebase config: API key, auth domain, project ID, etc.

- **Backend**:
  - `GOOGLE_TOKEN_AUDIENCE`: env variable (OAuth 2.0 client ID for token audience)
  - `IDENTITY_PLATFORM_ALLOWED_ORGS`: Comma-separated list of allowed organizations

---

## Okta Integration Options

### Option A: Replace Completely (Recommended)
- **Pros**:
  - Single authentication provider (no Firebase dependency)
  - Stronger enterprise features (MFA, advanced policies, SSO)
  - Cleaner codebase, fewer dependencies
  - Okta handles token refresh automatically

- **Cons**:
  - Full rewrite of auth service
  - Need to handle user provisioning differently
  - Must test all auth flows thoroughly

### Option B: Use Firebase as Auth Layer with Okta as Provider
- **Pros**:
  - Minimal frontend changes
  - Firebase handles token management
  - Gradual migration possible

- **Cons**:
  - Added complexity (Okta → Firebase → Backend)
  - Extra latency for token validation
  - Still depends on Firebase
  - Higher costs

### Option C: Hybrid Approach (Okta + Custom JWT)
- **Pros**:
  - Okta handles authentication
  - Custom JWT for internal communication
  - Fine-grained control

- **Cons**:
  - Complex JWT generation and validation
  - More maintenance burden
  - Requires careful security implementation

**RECOMMENDATION**: **Option A - Complete Okta replacement** provides the best balance of simplicity, security, and enterprise features.

---

## Recommended Approach

### Overview
```
User (Browser)
    ↓
Angular Frontend (auth.service.ts)
    ↓
Okta Authorization Server
    ↓
Okta returns ID Token + Access Token
    ↓
Frontend stores tokens in localStorage
    ↓
Auth Interceptor attaches token to API requests
    ↓
FastAPI Backend (auth_guard.py)
    ↓
Validates token using Okta's public key
    ↓
Extracts claims, provisions user, returns 200 OK
    ↓
API request processed
```

### Key Changes

**Frontend**:
- Replace `GoogleAuthProvider` with Okta SDK
- Update token retrieval to use Okta flows (Authorization Code + PKCE)
- Implement refresh token rotation
- Update user profile sync endpoint

**Backend**:
- Replace Google token validation with Okta JWT validation
- Fetch and cache Okta public keys (JWKS)
- Update token claim extraction for Okta token structure
- Keep JIT user provisioning logic

**Secrets**:
- Store Okta Client ID, Client Secret in Google Secret Manager
- Load via environment variables in both frontend and backend

---

## Detailed Implementation Plan

### Phase 1: Okta Setup & Configuration (1-2 days)

1. **Create Okta Developer Account** (if not existing)
   - Visit [developer.okta.com](https://developer.okta.com)
   - Create organization
   - Create application (Web - Single Page Application)

2. **Configure Okta App**
   - **App Name**: `Creative Studio`
   - **App Type**: Single Page Application (SPA)
   - **Sign-in Redirect URIs**:
     - `http://localhost:4200/login/callback` (dev)
     - `https://your-domain.firebaseapp.com/login/callback` (prod)
   - **Sign-out Redirect URIs**:
     - `http://localhost:4200/login` (dev)
     - `https://your-domain.firebaseapp.com/login` (prod)
   - **Allowed Origins**:
     - `http://localhost:4200` (dev)
     - `https://your-domain.firebaseapp.com` (prod)

3. **Retrieve Okta Credentials**
   - Note the following from Okta Admin Console:
     - **Client ID**: Public identifier for your application
     - **Client Secret**: Confidential secret (for backend only)
     - **Okta Domain**: `https://your-org.okta.com` (or custom domain)
     - **Authorization Server URL**: `https://your-org.okta.com/oauth2/default`

4. **Create Authorization Server**
   - Navigate to Security → API → Authorization Servers
   - Use default server or create custom
   - Note the Authorization Server URL for token validation

5. **Create User Attributes** (optional but recommended)
   - Add custom attributes if needed (e.g., `department`, `team`)
   - Will be included in token claims

### Phase 2: Frontend Implementation (3-4 days)

#### Step 1: Install Okta SDK
```bash
cd frontend
npm install @okta/okta-angular @okta/okta-auth-js
```

#### Step 2: Update Environment Files
**File**: `frontend/src/environments/environment.ts`

```typescript
export const environment = {
  production: false,
  backendURL: 'http://localhost:8080/api',

  // Okta Configuration
  okta: {
    clientId: 'YOUR_OKTA_CLIENT_ID',           // Load from env var
    domain: 'https://your-org.okta.com',       // Load from env var
    redirectUri: 'http://localhost:4200/login/callback',
    postLogoutRedirectUri: 'http://localhost:4200/login',
    scopes: ['openid', 'profile', 'email'],
    pkce: true,  // Recommended for SPAs
  },

  // Keep for compatibility if needed
  firebase: {
    // Can be removed if fully migrating to Okta
    apiKey: '',
    // ...
  },
};
```

**File**: `frontend/src/environments/environment.prod.ts`

```typescript
export const environment = {
  production: true,
  backendURL: 'https://api.your-domain.com/api',

  okta: {
    clientId: 'YOUR_OKTA_CLIENT_ID',           // Load from env var
    domain: 'https://your-org.okta.com',       // Load from env var
    redirectUri: 'https://your-domain.firebaseapp.com/login/callback',
    postLogoutRedirectUri: 'https://your-domain.firebaseapp.com/login',
    scopes: ['openid', 'profile', 'email'],
    pkce: true,
  },

  firebase: {
    // ...
  },
};
```

#### Step 3: Update App Module
**File**: `frontend/src/app/app.module.ts`

```typescript
import { OktaAuth } from '@okta/okta-auth-js';
import { OktaAuthModule, OKTA_CONFIG } from '@okta/okta-angular';
import { environment } from '../environments/environment';

const oktaAuth = new OktaAuth({
  clientId: environment.okta.clientId,
  issuer: `${environment.okta.domain}/oauth2/default`,
  redirectUri: environment.okta.redirectUri,
  postLogoutRedirectUri: environment.okta.postLogoutRedirectUri,
  scopes: environment.okta.scopes,
  pkce: environment.okta.pkce,
});

@NgModule({
  imports: [
    // ...
    OktaAuthModule,
  ],
  providers: [
    { provide: OKTA_CONFIG, useValue: { oktaAuth } },
    // ... other providers
  ],
  // ...
})
export class AppModule { }
```

#### Step 4: Rewrite Auth Service
**File**: `frontend/src/app/common/services/auth.service.ts`

```typescript
import { Injectable, inject } from '@angular/core';
import { OktaAuth } from '@okta/okta-auth-js';
import { Router } from '@angular/router';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from '../../../environments/environment';
import { Observable, from, of, throwError } from 'rxjs';
import { switchMap, tap, catchError, map } from 'rxjs/operators';
import { UserService } from './user.service';
import { UserModel } from '../models/user.model';

const USER_DETAILS = 'USER_DETAILS';
const LOGIN_ROUTE = '/login';

@Injectable({
  providedIn: 'root',
})
export class AuthService {
  private oktaAuth: OktaAuth;
  private userService = inject(UserService);
  private httpClient = inject(HttpClient);
  private router = inject(Router);

  constructor(oktaAuth: OktaAuth) {
    this.oktaAuth = oktaAuth;
  }

  /**
   * Initiates Okta sign-in flow (Authorization Code + PKCE)
   */
  signInWithOkta(): Observable<string> {
    return from(this.oktaAuth.signInWithRedirect()).pipe(
      switchMap(() => this.getValidToken$()),
      switchMap(token => this.syncUserWithBackend$(token)),
      map(() => this.getToken()!),
      catchError(error => {
        console.error('Okta sign-in failed:', error);
        return throwError(() => new Error(`Sign-in failed: ${error}`));
      }),
    );
  }

  /**
   * Gets a valid, non-expired access token
   * If expired, automatically refreshes using refresh token
   */
  getValidToken$(): Observable<string> {
    return from(this.oktaAuth.getAccessToken()).pipe(
      switchMap(token => {
        if (token) return of(token);
        // If no token, user is not authenticated
        return throwError(() => new Error('Not authenticated'));
      }),
      catchError(() =>
        from(this.oktaAuth.token.getWithRedirect({})),
      ),
    );
  }

  /**
   * Gets the ID token (contains user claims)
   */
  getIdToken$(): Observable<string | undefined> {
    return from(this.oktaAuth.getIdToken());
  }

  /**
   * Syncs user profile with backend
   */
  private syncUserWithBackend$(token: string): Observable<UserModel> {
    const headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);
    return this.httpClient
      .get<UserModel>(`${environment.backendURL}/users/me`, { headers })
      .pipe(
        tap((userDetails: UserModel) => {
          localStorage.setItem(USER_DETAILS, JSON.stringify(userDetails));
          console.log('User profile synced with backend');
        }),
        catchError(error => {
          console.error('Failed to sync user with backend:', error);
          return throwError(() => new Error('User sync failed'));
        }),
      );
  }

  /**
   * Logs out the user from Okta and clears local storage
   */
  async logout(redirectRoute: string = LOGIN_ROUTE): Promise<void> {
    localStorage.removeItem(USER_DETAILS);
    localStorage.removeItem('showTooltip');
    await this.oktaAuth.signOut({
      postLogoutRedirectUri: environment.okta.postLogoutRedirectUri,
    });
    await this.router.navigateByUrl(redirectRoute);
  }

  /**
   * Checks if user is currently authenticated
   */
  async isLoggedIn(): Promise<boolean> {
    return this.oktaAuth.isAuthenticated();
  }

  /**
   * Gets the current user's claims from the ID token
   */
  async getUserClaims(): Promise<any> {
    const idToken = await this.oktaAuth.getIdToken();
    if (!idToken) return null;

    const decoded = this.oktaAuth.token.decode(idToken);
    return decoded;
  }

  /**
   * Gets the current access token
   */
  getToken(): string | undefined {
    return this.oktaAuth.getAccessToken().then(token => token);
  }
}
```

#### Step 5: Update Auth Interceptor
**File**: `frontend/src/app/auth.interceptor.ts`

```typescript
import { Injectable } from '@angular/core';
import {
  HttpRequest,
  HttpHandler,
  HttpEvent,
  HttpInterceptor,
  HttpErrorResponse,
} from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, switchMap } from 'rxjs/operators';
import { AuthService } from './common/services/auth.service';
import { from } from 'rxjs';

@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  constructor(private authService: AuthService) {}

  intercept(
    request: HttpRequest<unknown>,
    next: HttpHandler,
  ): Observable<HttpEvent<unknown>> {
    // Get the access token from Okta
    return from(this.authService.getValidToken$()).pipe(
      switchMap(token => {
        // Clone request and add Authorization header
        const authorizedRequest = request.clone({
          setHeaders: { Authorization: `Bearer ${token}` },
        });
        return next.handle(authorizedRequest);
      }),
      catchError((error: any) => {
        if (!(error instanceof HttpErrorResponse)) {
          console.error('Token retrieval failed, logging out:', error);
          this.authService.logout();
        }
        return throwError(() => error);
      }),
    );
  }
}
```

#### Step 6: Create Login/Callback Component
**File**: `frontend/src/app/auth/login/login.component.ts`

```typescript
import { Component, OnInit, inject } from '@angular/core';
import { OktaAuth } from '@okta/okta-auth-js';
import { AuthService } from '../../common/services/auth.service';
import { Router } from '@angular/router';

@Component({
  selector: 'app-login',
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.scss'],
})
export class LoginComponent implements OnInit {
  private oktaAuth = inject(OktaAuth);
  private authService = inject(AuthService);
  private router = inject(Router);

  isLoading = false;

  async ngOnInit() {
    // Check if we're in the callback (redirect back from Okta)
    if (this.oktaAuth.isLoginRedirect()) {
      this.isLoading = true;
      try {
        await this.oktaAuth.handleLoginRedirect();
        // Sync user with backend
        const token = await this.oktaAuth.getAccessToken();
        if (token) {
          await this.authService['syncUserWithBackend$'](token).toPromise();
        }
        await this.router.navigate(['/']);
      } catch (error) {
        console.error('Login callback failed:', error);
        this.isLoading = false;
      }
    }
  }

  signIn() {
    this.authService.signInWithOkta().subscribe({
      next: () => this.router.navigate(['/']),
      error: (err) => console.error('Sign-in error:', err),
    });
  }
}
```

**File**: `frontend/src/app/auth/login/login.component.html`

```html
<div class="login-container">
  <div class="login-card">
    <h1>Creative Studio</h1>
    <p>Sign in with your Okta account</p>

    <div *ngIf="isLoading" class="loading">
      <mat-spinner></mat-spinner>
      <p>Processing login...</p>
    </div>

    <button
      *ngIf="!isLoading"
      (click)="signIn()"
      class="sign-in-btn"
      mat-raised-button
      color="primary">
      Sign In with Okta
    </button>
  </div>
</div>
```

#### Step 7: Update Route Guards
**File**: `frontend/src/app/auth.guard.service.ts`

```typescript
import { Injectable, inject } from '@angular/core';
import {
  ActivatedRouteSnapshot,
  CanActivate,
  Router,
  RouterStateSnapshot,
  UrlTree,
} from '@angular/router';
import { Observable } from 'rxjs';
import { OktaAuth } from '@okta/okta-auth-js';
import { map, catchError } from 'rxjs/operators';
import { from } from 'rxjs';

@Injectable({
  providedIn: 'root',
})
export class AuthGuardService implements CanActivate {
  private oktaAuth = inject(OktaAuth);
  private router = inject(Router);

  canActivate(
    route: ActivatedRouteSnapshot,
    state: RouterStateSnapshot,
  ): Observable<boolean | UrlTree> {
    return from(this.oktaAuth.isAuthenticated()).pipe(
      map(isAuthenticated => {
        if (isAuthenticated) {
          return true;
        }
        // Not authenticated, redirect to login
        return this.router.createUrlTree(['/login']);
      }),
      catchError(() => {
        // Error checking auth, redirect to login
        return from(
          this.router.navigate(['/login']).then(() => false),
        );
      }),
    );
  }
}
```

---

### Phase 3: Backend Implementation (2-3 days)

#### Step 1: Install Okta JWT Verification Library
```bash
cd backend
pip install okta-jwt-verifier
```

#### Step 2: Update Config Service
**File**: `backend/src/config/config_service.py`

Add Okta configuration:

```python
class ConfigService(BaseSettings):
    """Configuration service with Okta support"""

    # ... existing config ...

    # --- Okta Configuration ---
    OKTA_DOMAIN: str = ""                    # e.g., https://your-org.okta.com
    OKTA_CLIENT_ID: str = ""                 # From Okta app
    OKTA_AUTHORIZATION_SERVER: str = "default"  # Usually "default"
    OKTA_API_TOKEN: str = ""                 # For admin operations (optional)

    # ... rest of config ...
```

#### Step 3: Create Okta Token Validator
**File**: `backend/src/auth/okta_validator.py`

```python
import logging
from typing import Dict, Optional
import requests
from functools import lru_cache
import json
from jwt import decode as jwt_decode
from jwt.exceptions import InvalidTokenError, DecodeError

from src.config.config_service import config_service

logger = logging.getLogger(__name__)

class OktaTokenValidator:
    """Validates Okta JWT tokens and manages public key caching"""

    def __init__(self):
        self.okta_domain = config_service.OKTA_DOMAIN
        self.client_id = config_service.OKTA_CLIENT_ID
        self.issuer = f"{self.okta_domain}/oauth2/{config_service.OKTA_AUTHORIZATION_SERVER}"
        self.jwks_uri = f"{self.issuer}/v1/keys"
        self._jwks_cache = None
        self._jwks_cache_ttl = 3600  # 1 hour

    def get_jwks(self) -> Dict:
        """Fetches and caches Okta's public keys (JWKS)"""
        if self._jwks_cache:
            return self._jwks_cache

        try:
            response = requests.get(self.jwks_uri, timeout=10)
            response.raise_for_status()
            self._jwks_cache = response.json()
            logger.info("JWKS fetched and cached from Okta")
            return self._jwks_cache
        except requests.RequestException as e:
            logger.error(f"Failed to fetch JWKS from Okta: {e}")
            raise

    def validate_token(self, token: str) -> Dict:
        """
        Validates the Okta JWT token and returns the decoded claims

        Args:
            token: The JWT token from the Authorization header

        Returns:
            Dictionary containing token claims

        Raises:
            InvalidTokenError: If token is invalid, expired, or claims don't match
        """
        try:
            # Decode without verification first to inspect headers
            unverified = jwt_decode(token, options={"verify_signature": False})
            logger.debug(f"Token claims (unverified): {unverified}")

            # Get the key ID from the token header
            headers = jwt_decode(token, options={"verify_signature": False},
                               return_header=True)
            kid = headers.get('kid')

            if not kid:
                raise InvalidTokenError("Token missing 'kid' header")

            # Get JWKS and find the matching key
            jwks = self.get_jwks()
            signing_key = None

            for key in jwks.get('keys', []):
                if key.get('kid') == kid:
                    signing_key = key
                    break

            if not signing_key:
                raise InvalidTokenError(f"Key with kid '{kid}' not found in JWKS")

            # Verify the token signature using the public key
            decoded = jwt_decode(
                token,
                key=json.dumps(signing_key),
                algorithms=["RS256"],
                audience=self.client_id,
                issuer=self.issuer,
                options={"verify_aud": True, "verify_iss": True},
            )

            logger.info(f"Token validated successfully for user: {decoded.get('email')}")
            return decoded

        except DecodeError as e:
            logger.error(f"Failed to decode token: {e}")
            raise InvalidTokenError(f"Invalid token format: {e}")
        except InvalidTokenError as e:
            logger.error(f"Token validation failed: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error validating token: {e}")
            raise InvalidTokenError(f"Token validation error: {e}")

# Create singleton instance
okta_validator = OktaTokenValidator()
```

#### Step 4: Update Auth Guard
**File**: `backend/src/auth/auth_guard.py`

Replace the existing implementation with Okta support:

```python
import logging
from typing import List

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jwt.exceptions import InvalidTokenError

from src.config.config_service import config_service
from src.auth.okta_validator import okta_validator
from src.users.user_model import UserModel, UserRoleEnum
from src.users.user_service import UserService

user_service = UserService()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")
logger = logging.getLogger(__name__)

def get_current_user(token: str = Depends(oauth2_scheme)) -> UserModel:
    """
    Validates the Okta token and performs Just-In-Time user provisioning

    Args:
        token: The JWT token from the Authorization header

    Returns:
        UserModel with user information

    Raises:
        HTTPException: If token is invalid or user provisioning fails
    """
    try:
        # Validate token using Okta validator
        decoded_token = okta_validator.validate_token(token)

        email = decoded_token.get("email")
        name = decoded_token.get("name", "")
        picture = decoded_token.get("picture", "")

        # Restrict by organization if configured
        if not email:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Token does not contain email claim",
            )

        # Check organization restriction (optional)
        if config_service.ALLOWED_ORGS:
            # Extract domain from email or use custom claim
            email_domain = email.split("@")[1] if "@" in email else ""
            org_from_token = decoded_token.get("org", "")

            if not (email_domain in config_service.ALLOWED_ORGS or
                    org_from_token in config_service.ALLOWED_ORGS):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=f"User organization not allowed",
                )

        # Just-In-Time user provisioning
        user_doc = user_service.create_user_if_not_exists(
            email=email,
            name=name,
            picture=picture,
        )

        if not user_doc:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Could not create or retrieve user profile",
            )

        if not user_doc.picture and picture:
            user_doc.picture = picture
            user_service.user_repo.update(user_doc.id, user_doc.model_dump())

        return user_doc

    except InvalidTokenError as e:
        logger.error(f"Token validation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired token: {e}",
        )
    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Authentication error: {e}",
        )


class RoleChecker:
    """Dependency that checks if the authenticated user has required roles"""

    def __init__(self, allowed_roles: List[UserRoleEnum]):
        self.allowed_roles = allowed_roles

    def __call__(self, user: UserModel = Depends(get_current_user)):
        """Checks user roles"""
        is_authorized = any(role in self.allowed_roles for role in user.roles)

        if not is_authorized:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )

        return user
```

#### Step 5: Update Main App
**File**: `backend/src/main.py`

Ensure CORS is configured for Okta:

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from src.config.config_service import config_service

app = FastAPI()

# Configure CORS for Okta redirects
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        config_service.FRONTEND_URL,
        "http://localhost:4200",
        "https://your-domain.firebaseapp.com",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ... rest of app setup ...
```

---

## Secrets Management

### Google Secret Manager Setup

#### Step 1: Create Secrets in Google Cloud Console

```bash
# Create Okta secrets
gcloud secrets create okta-client-id --replication-policy="automatic"
gcloud secrets create okta-client-secret --replication-policy="automatic"
gcloud secrets create okta-domain --replication-policy="automatic"

# Grant access to Cloud Run service account
gcloud secrets add-iam-policy-binding okta-client-id \
  --member=serviceAccount:cs-prod-run@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor

# Repeat for other secrets...
```

#### Step 2: Add Secrets to Secret Manager
```bash
echo -n "your-okta-client-id" | gcloud secrets versions add okta-client-id --data-file=-
echo -n "your-okta-client-secret" | gcloud secrets versions add okta-client-secret --data-file=-
echo -n "https://your-org.okta.com" | gcloud secrets versions add okta-domain --data-file=-
```

#### Step 3: Update Cloud Run Environment Variables

Use Terraform to reference secrets:

**File**: `infra/modules/cloud-run-service/main.tf`

```hcl
resource "google_cloud_run_v2_service" "backend" {
  name     = "creative-studio-backend"
  location = var.gcp_region

  template {
    containers {
      image = var.backend_image

      env {
        name  = "OKTA_DOMAIN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.okta_domain.id
            version = "latest"
          }
        }
      }

      env {
        name  = "OKTA_CLIENT_ID"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.okta_client_id.id
            version = "latest"
          }
        }
      }

      env {
        name  = "OKTA_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.okta_client_secret.id
            version = "latest"
          }
        }
      }

      # ... other env vars ...
    }
  }
}
```

#### Step 4: Frontend Secrets (Build-time)

For frontend, use Cloud Build substitutions:

**File**: `cloudbuild.yaml`

```yaml
steps:
  - name: 'gcr.io/cloud-builders/gke-deploy'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        gcloud secrets versions access latest --secret="okta-client-id" > /workspace/okta-client-id.txt
        gcloud secrets versions access latest --secret="okta-domain" > /workspace/okta-domain.txt
        export OKTA_CLIENT_ID=$(cat /workspace/okta-client-id.txt)
        export OKTA_DOMAIN=$(cat /workspace/okta-domain.txt)

        # Build with environment variables
        npm run build -- \
          --configuration=production \
          --define="OKTA_CLIENT_ID=$OKTA_CLIENT_ID" \
          --define="OKTA_DOMAIN=$OKTA_DOMAIN"

substitutions:
  _OKTA_CLIENT_ID: "placeholder"
  _OKTA_DOMAIN: "placeholder"
```

---

## Testing & Validation

### Frontend Testing

#### Unit Tests
```typescript
// auth.service.spec.ts
describe('AuthService with Okta', () => {
  let service: AuthService;
  let oktaAuth: jasmine.SpyObj<OktaAuth>;
  let httpClient: jasmine.SpyObj<HttpClient>;

  beforeEach(() => {
    const oktaAuthSpy = jasmine.createSpyObj('OktaAuth', [
      'signInWithRedirect',
      'signOut',
      'isAuthenticated',
      'getAccessToken',
      'getIdToken',
    ]);
    const httpClientSpy = jasmine.createSpyObj('HttpClient', ['get']);

    TestBed.configureTestingModule({
      providers: [
        AuthService,
        { provide: OktaAuth, useValue: oktaAuthSpy },
        { provide: HttpClient, useValue: httpClientSpy },
      ],
    });

    service = TestBed.inject(AuthService);
    oktaAuth = TestBed.inject(OktaAuth) as jasmine.SpyObj<OktaAuth>;
    httpClient = TestBed.inject(HttpClient) as jasmine.SpyObj<HttpClient>;
  });

  it('should retrieve valid token', (done) => {
    oktaAuth.getAccessToken.and.returnValue(Promise.resolve('token123'));

    service.getValidToken$().subscribe(token => {
      expect(token).toBe('token123');
      done();
    });
  });

  it('should sync user with backend', (done) => {
    const mockUser: UserModel = {
      id: '1',
      email: 'test@example.com',
      name: 'Test User',
      roles: [],
      picture: '',
      created_at: new Date(),
    };

    httpClient.get.and.returnValue(of(mockUser));

    service['syncUserWithBackend$']('token123').subscribe(user => {
      expect(user).toEqual(mockUser);
      done();
    });
  });
});
```

#### E2E Tests
```typescript
// auth.e2e.spec.ts
describe('Okta Authentication Flow', () => {
  beforeEach(() => {
    cy.visit('/login');
  });

  it('should display sign-in button', () => {
    cy.contains('Sign In with Okta').should('be.visible');
  });

  it('should redirect to Okta login', () => {
    cy.contains('Sign In with Okta').click();
    cy.url().should('include', 'okta.com');
  });

  it('should redirect back after login', () => {
    // Mock Okta callback
    cy.window().then((win) => {
      // Simulate Okta redirect with auth code
    });
    cy.url().should('include', '/login/callback');
  });
});
```

### Backend Testing

#### Unit Tests
```python
# tests/auth/test_okta_validator.py
import pytest
from unittest.mock import patch, MagicMock
from src.auth.okta_validator import OktaTokenValidator
from jwt.exceptions import InvalidTokenError

class TestOktaTokenValidator:

    @pytest.fixture
    def validator(self):
        with patch('src.auth.okta_validator.config_service'):
            return OktaTokenValidator()

    def test_valid_token(self, validator):
        """Test token validation with valid token"""
        valid_token = "eyJhbGciOiJSUzI1NiIsImtpZCI6ImtleTEifQ..."

        with patch.object(validator, 'get_jwks') as mock_jwks:
            mock_jwks.return_value = {
                'keys': [{
                    'kid': 'key1',
                    'kty': 'RSA',
                    'n': '...',
                    'e': 'AQAB',
                }]
            }

            with patch('jwt.decode') as mock_decode:
                mock_decode.return_value = {
                    'email': 'test@example.com',
                    'sub': '00u123',
                }

                claims = validator.validate_token(valid_token)
                assert claims['email'] == 'test@example.com'

    def test_invalid_token(self, validator):
        """Test token validation with invalid token"""
        invalid_token = "invalid.token.here"

        with pytest.raises(InvalidTokenError):
            validator.validate_token(invalid_token)

    def test_expired_token(self, validator):
        """Test token validation with expired token"""
        expired_token = "eyJhbGciOiJSUzI1NiJ9..."

        with patch('jwt.decode') as mock_decode:
            mock_decode.side_effect = Exception("Token expired")

            with pytest.raises(InvalidTokenError):
                validator.validate_token(expired_token)
```

#### Integration Tests
```python
# tests/integration/test_okta_auth_flow.py
import pytest
from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)

def test_protected_endpoint_without_token():
    """Should reject request without token"""
    response = client.get("/api/users/me")
    assert response.status_code == 403

def test_protected_endpoint_with_valid_token(mock_okta_token):
    """Should accept request with valid token"""
    headers = {"Authorization": f"Bearer {mock_okta_token}"}
    response = client.get("/api/users/me", headers=headers)
    assert response.status_code == 200

def test_protected_endpoint_with_invalid_token():
    """Should reject request with invalid token"""
    headers = {"Authorization": "Bearer invalid_token"}
    response = client.get("/api/users/me", headers=headers)
    assert response.status_code == 401
```

### Manual Testing Checklist

- [ ] Frontend: Sign in with Okta
- [ ] Frontend: Verify token stored in localStorage
- [ ] Frontend: Verify user profile loaded from backend
- [ ] Frontend: Make API request with token
- [ ] Backend: Receive token, validate it
- [ ] Backend: Extract claims from token
- [ ] Backend: Create/fetch user in Firestore
- [ ] Frontend: Sign out clears localStorage and session
- [ ] Frontend: Redirect to Okta logout URL
- [ ] Both: Token refresh works automatically
- [ ] Both: Expired token triggers re-login
- [ ] Both: Error handling for invalid tokens

---

## Migration Path

### Stage 1: Parallel Running (1 week)

**Goal**: Run both authentication systems simultaneously

1. Deploy Okta auth to **new feature branch**
2. Keep existing Firebase/Google auth **functional**
3. Add **feature flag** to switch between auth providers
4. Test Okta flow with **internal users only**
5. Gather feedback and fix issues

### Stage 2: Gradual Rollout (1-2 weeks)

1. Enable Okta for **beta users** (10%)
2. Monitor logs for errors
3. Gradually increase percentage
4. Disable Google auth option in UI

### Stage 3: Complete Migration (1 week)

1. Migrate all remaining users
2. Remove Google auth code
3. Clean up environment variables
4. Update documentation
5. Archive old auth modules

### Rollback Plan

If issues arise:

1. **Keep Git history** - Easy to revert commits
2. **Feature flag** - Quickly switch back to Firebase
3. **Database backup** - Restore user data if needed
4. **Load balancer** - Route traffic to old version if necessary

---

## Security Considerations

### Secrets
- **Never commit** Okta Client Secret to Git
- Use **Google Secret Manager** for all credentials
- Rotate secrets regularly
- Audit secret access logs

### Token Validation
- Always validate token **signature** against Okta JWKS
- Verify **issuer** matches your Okta domain
- Verify **audience** matches your Client ID
- Check token **expiration** (done automatically)

### CORS & Redirects
- Only allow **known redirect URIs** in Okta
- Validate **origin headers** in CORS middleware
- Use **HTTPS only** in production

### JIT Provisioning
- Validate email format before creating user
- Handle **race conditions** if multiple requests arrive simultaneously
- Log all user creation attempts
- Set default roles (not admin)

---

## Monitoring & Logging

### What to Monitor

**Frontend**:
- Sign-in success/failure rates
- Token refresh frequency
- CORS errors
- User profile sync failures

**Backend**:
- Token validation success/failure rates
- User provisioning success/failure rates
- Invalid token attempts (possible attacks)
- Latency for JWKS fetch and validation

### Logging Strategy

**Frontend** (`auth.service.ts`):
```typescript
logger.info(`User signed in: ${email}`);
logger.error(`Token validation failed: ${error}`);
logger.debug(`Token refreshed at ${new Date().toISOString()}`);
```

**Backend** (`auth_guard.py`):
```python
logger.info(f"Token validated for: {decoded_token.get('email')}")
logger.error(f"Token validation failed: {e}")
logger.warning(f"Organization not allowed: {org}")
```

### Dashboards

Create Datadog/Cloud Monitoring dashboards for:
- Sign-in success rate
- Token validation latency
- User provisioning latency
- Error rates by type

---

## FAQ

**Q: Can we use Firebase with Okta?**
A: Yes, but it adds complexity. Firebase → Okta → Backend validation chain. Not recommended.

**Q: Where do we store Client Secret?**
A: Google Secret Manager, loaded via environment variables. Never in code or .env files.

**Q: What about existing Firebase sessions?**
A: Invalidate them during migration. Users will need to log in again with Okta.

**Q: How long are Okta tokens valid?**
A: Default is 1 hour. Okta SDK handles automatic refresh with refresh tokens.

**Q: What if Okta is down?**
A: Users can't log in. Implement fallback or have incident response plan. Okta has 99.99% SLA.

**Q: Do we need to change database structure?**
A: No. User document structure stays the same. Okta claims map to existing fields.

**Q: Can we use Okta for authorization (roles)?**
A: Yes. Okta can issue custom claims in tokens. Or keep roles in Firestore (current approach).

---

## Summary

| Aspect | Details |
|--------|---------|
| **Scope** | Both frontend and backend |
| **Duration** | 2-4 weeks (including testing) |
| **Complexity** | Medium (rewrite auth, maintain security) |
| **Risk** | Low (gradual rollout, rollback plan) |
| **Benefits** | Enterprise SSO, MFA, stronger security |
| **Secrets Location** | Google Secret Manager |
| **Breaking Changes** | Users must re-login, clear localStorage |

---

## Document Information

- **Created**: December 2025
- **Version**: 1.0
- **Status**: Ready for implementation
- **Next Steps**: Review with team, create Jira epics, begin Phase 1
