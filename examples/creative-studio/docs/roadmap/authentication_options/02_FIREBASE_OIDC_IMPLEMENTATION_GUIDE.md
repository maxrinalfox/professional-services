# Firebase + OIDC Implementation Guide

**Document Version**: 1.0
**Last Updated**: December 17, 2025
**Status**: Ready for Implementation

---

## Overview

This guide provides step-by-step implementation instructions for adding OIDC provider support (Okta, Azure Entra ID, Keycloak) to the existing Firebase Authentication setup while maintaining full backward compatibility with Google Sign-In.

---

## Table of Contents

1. [Prerequisites & Setup](#prerequisites--setup)
2. [Phase 1: Firebase OIDC Configuration](#phase-1-firebase-oidc-configuration)
3. [Phase 2: Backend Implementation](#phase-2-backend-implementation)
4. [Phase 3: Frontend Implementation](#phase-3-frontend-implementation)
5. [Phase 4: Testing & Validation](#phase-4-testing--validation)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites & Setup

### Required Credentials

Obtain from your OIDC provider:

**For Okta**:
- Organization URL (e.g., `https://company.okta.com`)
- Client ID (from "API" → "Authorization Servers")
- Client Secret
- Groups domain claim (typically `groups`)

**For Azure Entra ID (Microsoft)**:
- Tenant ID
- Application ID (Client ID)
- Client Secret
- Group claims configuration

**For Keycloak**:
- Issuer URL (e.g., `https://keycloak.example.com/realms/master`)
- Client ID
- Client Secret
- Realm configuration for groups

### Project Dependencies

Add to backend `requirements.txt`:
```
python-jose[cryptography]>=3.3.0
pydantic-settings>=2.0.0
httpx>=0.24.0  # Async HTTP client
redis>=5.0.0   # Token caching (optional)
```

Add to frontend `package.json`:
```json
{
  "devDependencies": {
    "jwt-decode": "^4.0.0"
  }
}
```

---

## Phase 1: Firebase OIDC Configuration

### Step 1: Add OIDC Provider to Firebase Console

**Location**: Firebase Console → Select Project → Authentication → Sign-in Method

**For Okta**:

1. Click "Add new provider" → OIDC
2. Fill in:
   - **Provider ID**: `oidc.okta`
   - **Display name**: `Okta SSO`
   - **Client ID**: From Okta API credentials
   - **Client Secret**: From Okta
   - **Issuer URL**: `https://your-org.okta.com`
3. Click "Save"

**For Azure Entra ID**:

1. Click "Add new provider" → OIDC
2. Fill in:
   - **Provider ID**: `oidc.entra`
   - **Display name**: `Microsoft Entra ID`
   - **Client ID**: Application ID from Azure Portal
   - **Client Secret**: From Azure App Registration
   - **Issuer URL**: `https://login.microsoftonline.com/{tenant-id}/v2.0`
3. Click "Save"

**For Keycloak**:

1. Click "Add new provider" → OIDC
2. Fill in:
   - **Provider ID**: `oidc.keycloak`
   - **Display name**: `Keycloak`
   - **Client ID**: From Keycloak client settings
   - **Client Secret**: From Keycloak
   - **Issuer URL**: `https://keycloak.example.com/realms/your-realm`
3. Click "Save"

### Step 2: Verify Firebase Configuration

```bash
# Test Firebase can reach OIDC provider's .well-known config
curl https://your-org.okta.com/.well-known/openid-configuration

# Should return JSON with endpoints:
# - authorization_endpoint
# - token_endpoint
# - userinfo_endpoint
# - jwks_uri
```

---

## Phase 2: Backend Implementation

### Step 1: Create OIDC Service

**File**: `backend/src/auth/oidc_service.py`

```python
import httpx
import logging
from typing import Dict, List, Optional
from datetime import datetime, timedelta
from functools import lru_cache
import json

logger = logging.getLogger(__name__)


class OIDCDiscoveryCache:
    """Cache OIDC provider discovery metadata"""

    _cache = {}
    _cache_expiry = {}

    @classmethod
    async def get_config(cls, issuer_url: str) -> Dict:
        """Get and cache OIDC provider configuration"""

        # Check if cached and not expired
        if issuer_url in cls._cache:
            if datetime.utcnow() < cls._cache_expiry.get(issuer_url, datetime.min):
                return cls._cache[issuer_url]

        try:
            discovery_url = f"{issuer_url.rstrip('/')}/.well-known/openid-configuration"

            async with httpx.AsyncClient() as client:
                response = await client.get(discovery_url, timeout=10.0)
                response.raise_for_status()

            config = response.json()

            # Cache for 24 hours
            cls._cache[issuer_url] = config
            cls._cache_expiry[issuer_url] = datetime.utcnow() + timedelta(hours=24)

            logger.info(f"Cached OIDC config from {issuer_url}")
            return config

        except Exception as e:
            logger.error(f"Failed to fetch OIDC discovery config: {str(e)}")
            raise


class OIDCService:
    """Handle OIDC provider operations"""

    def __init__(self):
        self.discovery_cache = OIDCDiscoveryCache()

    async def get_oidc_config(self, issuer_url: str) -> Dict:
        """Get OIDC provider configuration"""
        return await self.discovery_cache.get_config(issuer_url)

    async def get_user_info(
        self,
        access_token: str,
        issuer_url: str,
    ) -> Dict:
        """
        Fetch user information from OIDC provider's userinfo endpoint

        Args:
            access_token: OAuth access token
            issuer_url: OIDC provider issuer URL

        Returns:
            Dictionary with user info including groups
        """

        try:
            config = await self.get_oidc_config(issuer_url)
            userinfo_endpoint = config.get('userinfo_endpoint')

            if not userinfo_endpoint:
                raise ValueError("OIDC provider does not expose userinfo_endpoint")

            async with httpx.AsyncClient() as client:
                response = await client.get(
                    userinfo_endpoint,
                    headers={'Authorization': f'Bearer {access_token}'},
                    timeout=10.0
                )
                response.raise_for_status()

            user_info = response.json()
            logger.info(f"Retrieved user info for: {user_info.get('email')}")

            return user_info

        except Exception as e:
            logger.error(f"Failed to get user info: {str(e)}")
            raise

    def extract_groups(self, user_info: Dict, provider_type: str) -> List[str]:
        """
        Extract groups from user info based on provider type

        Different providers store groups differently:
        - Okta: 'groups' claim in userinfo or id_token
        - Azure AD/Entra: 'groups' claim (OID list) or 'wids' (directory role IDs)
        - Keycloak: nested in resource_access or via 'groups' claim
        """

        groups = []

        if provider_type == 'okta':
            # Okta groups endpoint would be better but userinfo may have groups
            groups = user_info.get('groups', [])

        elif provider_type == 'entra':
            # Azure AD uses 'groups' claim (requires group claims configured)
            groups = user_info.get('groups', [])
            # Could also use wids for directory roles
            directory_roles = user_info.get('wids', [])
            groups.extend(directory_roles)

        elif provider_type == 'keycloak':
            # Keycloak can expose groups in different ways
            # Method 1: Direct groups claim
            groups = user_info.get('groups', [])

            # Method 2: Nested in resource access
            resource_access = user_info.get('resource_access', {})
            client_roles = resource_access.get('account', {}).get('roles', [])
            groups.extend(client_roles)

        else:
            # Generic fallback
            groups = user_info.get('groups', [])

        return list(set(groups))  # Remove duplicates

    async def get_user_groups(
        self,
        access_token: str,
        issuer_url: str,
        provider_type: str = 'generic',
    ) -> List[str]:
        """
        Get user groups from OIDC provider

        Args:
            access_token: OAuth access token
            issuer_url: OIDC provider issuer URL
            provider_type: 'okta', 'entra', 'keycloak', or 'generic'

        Returns:
            List of group identifiers/names
        """

        try:
            user_info = await self.get_user_info(access_token, issuer_url)
            groups = self.extract_groups(user_info, provider_type)

            logger.info(f"Extracted {len(groups)} groups: {groups}")
            return groups

        except Exception as e:
            logger.error(f"Failed to get user groups: {str(e)}")
            return []  # Return empty list as fallback

    async def get_direct_group_memberships(
        self,
        user_id: str,
        access_token: str,
        issuer_url: str,
        provider_type: str,
    ) -> List[str]:
        """
        Get groups directly from provider's groups endpoint
        (More reliable than extracting from user info)

        Provider-specific implementations:
        - Okta: GET /api/v1/users/{userId}/groups
        - Entra: GET /me/memberOf (Microsoft Graph)
        - Keycloak: GET /admin/realms/{realm}/users/{userId}/groups
        """

        try:
            if provider_type == 'okta':
                return await self._get_okta_groups(user_id, access_token, issuer_url)

            elif provider_type == 'entra':
                return await self._get_entra_groups(access_token)

            elif provider_type == 'keycloak':
                return await self._get_keycloak_groups(user_id, access_token, issuer_url)

            else:
                logger.warning(f"No direct group endpoint for provider: {provider_type}")
                return []

        except Exception as e:
            logger.error(f"Failed to get direct groups: {str(e)}")
            return []

    async def _get_okta_groups(
        self,
        user_id: str,
        access_token: str,
        issuer_url: str,
    ) -> List[str]:
        """Get groups from Okta Groups API"""

        url = f"{issuer_url.rstrip('/')}/api/v1/users/{user_id}/groups"

        async with httpx.AsyncClient() as client:
            response = await client.get(
                url,
                headers={'Authorization': f'Bearer {access_token}'},
                timeout=10.0
            )
            response.raise_for_status()

        groups = response.json()
        return [g['profile']['name'] for g in groups]

    async def _get_entra_groups(self, access_token: str) -> List[str]:
        """Get groups from Azure AD / Microsoft Graph"""

        # Note: Requires delegated permissions in Azure AD
        # Alternative: Use /me/transitiveMemberOf to get all groups recursively

        url = "https://graph.microsoft.com/v1.0/me/memberOf"

        async with httpx.AsyncClient() as client:
            response = await client.get(
                url,
                headers={'Authorization': f'Bearer {access_token}'},
                timeout=10.0
            )
            response.raise_for_status()

        data = response.json()
        groups = [item.get('displayName') for item in data.get('value', [])]
        return groups

    async def _get_keycloak_groups(
        self,
        user_id: str,
        access_token: str,
        issuer_url: str,
    ) -> List[str]:
        """Get groups from Keycloak Admin API"""

        # Requires admin API access
        url = f"{issuer_url.rstrip('/')}/admin/realms/master/users/{user_id}/groups"

        async with httpx.AsyncClient() as client:
            response = await client.get(
                url,
                headers={'Authorization': f'Bearer {access_token}'},
                timeout=10.0
            )
            response.raise_for_status()

        groups = response.json()
        return [g['name'] for g in groups]
```

### Step 2: Create Group-to-Role Mapping Service

**File**: `backend/src/auth/group_role_mapper.py`

```python
import logging
from typing import List, Dict
from enum import Enum

logger = logging.getLogger(__name__)


class UserRole(str, Enum):
    """Creative Studio system-level roles"""
    USER = "user"
    CREATOR = "creator"
    ADMIN = "admin"


class GroupRoleMapping:
    """
    Map external OIDC groups to Creative Studio roles

    This is configuration-driven to support different OIDC providers
    and organizational structures.
    """

    # Default mappings - can be overridden via environment or database
    DEFAULT_MAPPINGS = {
        # Okta group mappings
        'okta_admins': [UserRole.ADMIN],
        'okta_creators': [UserRole.CREATOR],
        'okta_users': [UserRole.USER],

        # Azure AD / Entra ID mappings
        'entra_admins': [UserRole.ADMIN],
        'entra_app_admins': [UserRole.ADMIN],
        'entra_design_team': [UserRole.CREATOR],
        'entra_users': [UserRole.USER],

        # Keycloak mappings
        'keycloak_admins': [UserRole.ADMIN],
        'keycloak_designers': [UserRole.CREATOR],
        'keycloak_users': [UserRole.USER],

        # Generic fallback
        'admins': [UserRole.ADMIN],
        'designers': [UserRole.CREATOR],
        'developers': [UserRole.CREATOR],
    }

    @classmethod
    def get_roles_from_groups(
        cls,
        groups: List[str],
        custom_mappings: Dict[str, List[UserRole]] = None,
    ) -> List[UserRole]:
        """
        Convert OIDC groups to Creative Studio roles

        Args:
            groups: List of group identifiers from OIDC provider
            custom_mappings: Optional custom group→role mappings

        Returns:
            List of Creative Studio roles
        """

        # Use custom mappings if provided, otherwise defaults
        mappings = custom_mappings or cls.DEFAULT_MAPPINGS

        roles = set()

        for group in groups:
            if group in mappings:
                mapped_roles = mappings[group]
                roles.update(mapped_roles)
                logger.info(f"Group '{group}' mapped to roles: {mapped_roles}")
            else:
                logger.debug(f"No mapping found for group: {group}")

        # Default to USER role if no matching groups
        if not roles:
            roles.add(UserRole.USER)
            logger.info(f"No group mappings found, defaulting to: {UserRole.USER}")

        return sorted(list(roles))

    @classmethod
    def supports_group_extraction(cls, provider_type: str) -> bool:
        """Check if provider supports group extraction"""

        return provider_type in ['okta', 'entra', 'keycloak', 'generic']

    @classmethod
    def get_recommended_scopes(cls, provider_type: str) -> List[str]:
        """Get recommended OAuth scopes for provider"""

        scopes_by_provider = {
            'okta': ['openid', 'profile', 'email', 'groups'],
            'entra': ['openid', 'profile', 'email'],  # Groups via token
            'keycloak': ['openid', 'profile', 'email', 'groups'],
            'google': ['openid', 'profile', 'email'],
        }

        return scopes_by_provider.get(provider_type, ['openid', 'profile', 'email'])
```

### Step 3: Create Role Sync Endpoint

**File**: `backend/src/routes/auth_controller.py` (new endpoint)

```python
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthCredentials
from pydantic import BaseModel
from typing import List

import logging

from src.config.firebase_admin import firebase_admin_service
from src.services.firestore_service import FirestoreService
from src.auth.oidc_service import OIDCService
from src.auth.group_role_mapper import GroupRoleMapping
from datetime import datetime

logger = logging.getLogger(__name__)

router = APIRouter(prefix='/api/auth', tags=['auth'])

security = HTTPBearer()
oidc_service = OIDCService()
firestore_service = FirestoreService()


class SyncRolesRequest(BaseModel):
    """Request to sync roles from OIDC provider"""
    provider_id: str  # 'oidc.okta', 'oidc.entra', etc.
    issuer_url: str  # OIDC provider issuer URL


class SyncRolesResponse(BaseModel):
    """Response after syncing roles"""
    success: bool
    roles: List[str]
    groups: List[str]
    synced_at: str
    message: str = ""


@router.post('/sync-roles', response_model=SyncRolesResponse)
async def sync_roles_from_oidc(
    request: SyncRolesRequest,
    credentials: HTTPAuthCredentials = Depends(security),
):
    """
    Sync user roles from OIDC provider to Firebase custom claims

    This endpoint is called after OIDC authentication to:
    1. Extract groups from OIDC provider
    2. Map groups to Creative Studio roles
    3. Update Firebase custom claims with roles
    4. Store roles in Firestore for quick lookup

    Args:
        request: Contains provider_id and issuer_url
        credentials: Firebase ID token from frontend

    Returns:
        Synced roles and groups
    """

    token = credentials.credentials

    try:
        # Step 1: Verify Firebase ID token
        decoded_token = firebase_admin_service.verify_token(token)
        user_id = decoded_token.get('uid')
        user_email = decoded_token.get('email')

        logger.info(f"Syncing roles for user: {user_email} from {request.provider_id}")

        # Step 2: Determine provider type
        provider_type = request.provider_id.replace('oidc.', '').lower()

        # Step 3: Get user groups from OIDC provider
        groups = await oidc_service.get_user_groups(
            access_token=decoded_token.get('access_token'),  # May not be available
            issuer_url=request.issuer_url,
            provider_type=provider_type,
        )

        # Step 4: Map groups to roles
        roles = GroupRoleMapping.get_roles_from_groups(groups)

        # Step 5: Update Firebase custom claims
        # Custom claims appear in ID token after next refresh
        firebase_admin_service.set_custom_claims(user_id, {
            'roles': roles,
            'groups': groups,
            'provider_id': request.provider_id,
            'synced_at': datetime.utcnow().isoformat(),
        })

        logger.info(f"Set Firebase custom claims for {user_email}: {roles}")

        # Step 6: Update Firestore for quick lookup (no token refresh needed)
        firestore_service.update_document('users', user_id, {
            'roles': roles,
            'groups': groups,
            'role_source': 'oidc_sync',
            'oidc_provider': request.provider_id,
            'last_role_sync': datetime.utcnow().isoformat(),
        })

        logger.info(f"Updated Firestore user document for {user_email}")

        return SyncRolesResponse(
            success=True,
            roles=roles,
            groups=groups,
            synced_at=datetime.utcnow().isoformat(),
            message=f"Synced {len(roles)} roles from {len(groups)} groups",
        )

    except ValueError as e:
        logger.error(f"Token verification failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}",
        )

    except Exception as e:
        logger.error(f"Role sync failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to sync roles: {str(e)}",
        )


@router.post('/refresh-roles', response_model=SyncRolesResponse)
async def refresh_roles(
    request: SyncRolesRequest,
    credentials: HTTPAuthCredentials = Depends(security),
):
    """
    Manually refresh roles from OIDC provider

    Called when user explicitly requests refresh or scheduled refresh runs.
    Useful if group memberships changed outside of login.
    """

    token = credentials.credentials

    try:
        decoded_token = firebase_admin_service.verify_token(token)
        user_id = decoded_token.get('uid')

        # Same logic as sync_roles but triggered manually
        provider_type = request.provider_id.replace('oidc.', '').lower()

        groups = await oidc_service.get_user_groups(
            access_token=decoded_token.get('access_token'),
            issuer_url=request.issuer_url,
            provider_type=provider_type,
        )

        roles = GroupRoleMapping.get_roles_from_groups(groups)

        firebase_admin_service.set_custom_claims(user_id, {
            'roles': roles,
            'groups': groups,
            'last_refresh': datetime.utcnow().isoformat(),
        })

        firestore_service.update_document('users', user_id, {
            'roles': roles,
            'groups': groups,
            'last_role_refresh': datetime.utcnow().isoformat(),
        })

        return SyncRolesResponse(
            success=True,
            roles=roles,
            groups=groups,
            synced_at=datetime.utcnow().isoformat(),
            message="Roles refreshed successfully",
        )

    except Exception as e:
        logger.error(f"Role refresh failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to refresh roles: {str(e)}",
        )
```

---

## Phase 3: Frontend Implementation

### Step 1: Update Auth Service for OIDC

**File**: `frontend/src/app/common/services/auth.service.ts` (updated)

```typescript
import { Injectable } from '@angular/core';
import {
  Auth,
  signInWithPopup,
  GoogleAuthProvider,
  OAuthProvider,
  signOut,
  onAuthStateChanged,
  User,
  UserCredential,
} from 'firebase/auth';
import { Router } from '@angular/router';
import { BehaviorSubject, Observable } from 'rxjs';
import { HttpClient } from '@angular/common/http';
import { ToastrService } from 'ngx-toastr';

interface AuthProvider {
  id: string;
  name: string;
  icon: string;
  type: 'google' | 'oidc';
}

interface SyncRolesResponse {
  success: boolean;
  roles: string[];
  groups: string[];
  synced_at: string;
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private currentUserSubject = new BehaviorSubject<User | null>(null);
  public currentUser$ = this.currentUserSubject.asObservable();

  private isAuthenticatedSubject = new BehaviorSubject<boolean>(false);
  public isAuthenticated$ = this.isAuthenticatedSubject.asObservable();

  private rolesSubject = new BehaviorSubject<string[]>([]);
  public roles$ = this.rolesSubject.asObservable();

  private groupsSubject = new BehaviorSubject<string[]>([]);
  public groups$ = this.groupsSubject.asObservable();

  // Available authentication providers
  providers: AuthProvider[] = [
    {
      id: 'google.com',
      name: 'Google',
      icon: 'google',
      type: 'google',
    },
    {
      id: 'oidc.okta',
      name: 'Okta SSO',
      icon: 'okta',
      type: 'oidc',
    },
    {
      id: 'oidc.entra',
      name: 'Microsoft Entra ID',
      icon: 'microsoft',
      type: 'oidc',
    },
  ];

  constructor(
    private auth: Auth,
    private http: HttpClient,
    private router: Router,
    private toastr: ToastrService
  ) {
    this.initializeAuthListener();
  }

  /**
   * Initialize auth state listener
   */
  private initializeAuthListener(): void {
    onAuthStateChanged(this.auth, async (user) => {
      this.currentUserSubject.next(user);
      this.isAuthenticatedSubject.next(!!user);

      if (user) {
        const idToken = await user.getIdToken();
        this.loadUserRoles(user, idToken);
      } else {
        this.rolesSubject.next([]);
        this.groupsSubject.next([]);
      }
    });
  }

  /**
   * Sign in with provider
   */
  async signInWithProvider(providerId: string): Promise<void> {
    try {
      if (providerId === 'google.com') {
        await this.signInWithGoogle();
      } else if (providerId.startsWith('oidc.')) {
        await this.signInWithOIDC(providerId);
      }
    } catch (error: any) {
      console.error('Sign-in error:', error);
      this.toastr.error(
        `Sign-in failed: ${error.message}`,
        'Authentication Error'
      );
      throw error;
    }
  }

  /**
   * Sign in with Google
   */
  private async signInWithGoogle(): Promise<void> {
    const provider = new GoogleAuthProvider();
    provider.addScope('profile');
    provider.addScope('email');

    const result = await signInWithPopup(this.auth, provider);
    console.log('Google sign-in successful');

    // Navigate to dashboard
    this.router.navigate(['/dashboard']);
  }

  /**
   * Sign in with OIDC provider
   */
  private async signInWithOIDC(providerId: string): Promise<void> {
    const provider = new OAuthProvider(providerId);

    // Add scopes based on provider
    const scopes = this.getScopes(providerId);
    scopes.forEach((scope) => {
      try {
        provider.addScope(scope);
      } catch (error) {
        console.warn(`Could not add scope "${scope}":`, error);
      }
    });

    // Configure custom parameters for provider
    this.configureProvider(provider, providerId);

    const result = await signInWithPopup(this.auth, provider);
    console.log('OIDC sign-in successful');

    // Sync roles from OIDC provider
    const user = result.user;
    const idToken = await user.getIdToken(true);

    await this.syncUserRolesFromOIDC(providerId, idToken);

    // Navigate to dashboard
    this.router.navigate(['/dashboard']);
  }

  /**
   * Get recommended scopes for provider
   */
  private getScopes(providerId: string): string[] {
    const scopeMap: { [key: string]: string[] } = {
      'oidc.okta': ['openid', 'profile', 'email', 'groups'],
      'oidc.entra': ['openid', 'profile', 'email'],
      'oidc.keycloak': ['openid', 'profile', 'email', 'groups'],
    };

    return scopeMap[providerId] || ['openid', 'profile', 'email'];
  }

  /**
   * Configure provider-specific settings
   */
  private configureProvider(provider: OAuthProvider, providerId: string): void {
    if (providerId === 'oidc.entra') {
      // Azure AD specific settings
      provider.setCustomParameters({
        'tenant': 'common', // Use 'common' for multi-tenant or specific tenant ID
      });
    }

    // Add any other provider-specific configuration here
  }

  /**
   * Sync user roles from OIDC provider
   */
  private async syncUserRolesFromOIDC(
    providerId: string,
    idToken: string
  ): Promise<void> {
    try {
      // Get issuer URL from provider configuration
      const issuerUrl = this.getIssuerUrl(providerId);

      const response = await this.http
        .post<SyncRolesResponse>('/api/auth/sync-roles', {
          provider_id: providerId,
          issuer_url: issuerUrl,
        })
        .toPromise();

      if (response?.success) {
        this.rolesSubject.next(response.roles || []);
        this.groupsSubject.next(response.groups || []);

        console.log('Roles synced:', response.roles);
        console.log('Groups synced:', response.groups);

        this.toastr.success(
          `Synced ${response.roles?.length || 0} roles from OIDC provider`
        );
      }
    } catch (error: any) {
      console.error('Failed to sync roles:', error);
      this.toastr.warning(
        'Could not sync roles from OIDC provider (using defaults)'
      );
      // Fall back to loading roles from token
      this.loadRolesFromToken();
    }
  }

  /**
   * Get issuer URL for OIDC provider
   */
  private getIssuerUrl(providerId: string): string {
    // Load from environment or configuration
    const issuerUrls: { [key: string]: string } = {
      'oidc.okta': 'https://your-org.okta.com',
      'oidc.entra': 'https://login.microsoftonline.com/your-tenant-id/v2.0',
      'oidc.keycloak': 'https://keycloak.example.com/realms/your-realm',
    };

    return issuerUrls[providerId] || '';
  }

  /**
   * Load user roles from token claims
   */
  private loadRolesFromToken(): void {
    const user = this.auth.currentUser;
    if (!user) return;

    user.getIdTokenResult(true).then((idTokenResult) => {
      const claims = idTokenResult.claims as any;
      const roles = claims.roles || [];
      const groups = claims.groups || [];

      this.rolesSubject.next(roles);
      this.groupsSubject.next(groups);
    });
  }

  /**
   * Load user roles (from token claims or Firestore)
   */
  private async loadUserRoles(user: User, idToken: string): Promise<void> {
    const idTokenResult = await user.getIdTokenResult(true);
    const claims = idTokenResult.claims as any;

    const roles = claims.roles || ['user'];
    const groups = claims.groups || [];

    this.rolesSubject.next(roles);
    this.groupsSubject.next(groups);
  }

  /**
   * Check if user has role
   */
  hasRole(role: string): boolean {
    const roles = this.rolesSubject.value;
    return roles.includes(role);
  }

  /**
   * Check if user has any of multiple roles
   */
  hasAnyRole(roles: string[]): boolean {
    const userRoles = this.rolesSubject.value;
    return roles.some((role) => userRoles.includes(role));
  }

  /**
   * Manually refresh roles
   */
  async refreshRoles(): Promise<void> {
    const user = this.auth.currentUser;
    if (!user) return;

    try {
      const idToken = await user.getIdToken(true);
      const providerId = this.getCurrentProviderID(user);

      if (providerId?.startsWith('oidc.')) {
        await this.syncUserRolesFromOIDC(providerId, idToken);
      } else {
        this.loadRolesFromToken();
      }

      this.toastr.success('Roles refreshed');
    } catch (error) {
      console.error('Failed to refresh roles:', error);
      this.toastr.error('Failed to refresh roles');
    }
  }

  /**
   * Get current provider ID
   */
  private getCurrentProviderID(user: User): string | undefined {
    return user.providerData[0]?.providerId;
  }

  /**
   * Sign out
   */
  async signOut(): Promise<void> {
    try {
      await signOut(this.auth);
      this.router.navigate(['/login']);
    } catch (error) {
      console.error('Sign-out error:', error);
    }
  }

  /**
   * Get current user
   */
  getCurrentUser(): User | null {
    return this.currentUserSubject.value;
  }

  /**
   * Get current roles
   */
  getRoles(): string[] {
    return this.rolesSubject.value;
  }
}
```

### Step 2: Update Login Component

**File**: `frontend/src/app/auth/login.component.ts` (updated)

```typescript
import { Component, OnInit } from '@angular/core';
import { AuthService } from '../common/services/auth.service';
import { Router } from '@angular/router';

interface Provider {
  id: string;
  name: string;
  icon: string;
  type: 'google' | 'oidc';
  description?: string;
}

@Component({
  selector: 'app-login',
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.scss'],
})
export class LoginComponent implements OnInit {
  providers: Provider[] = [
    {
      id: 'google.com',
      name: 'Google',
      icon: 'assets/icons/google.svg',
      type: 'google',
      description: 'Sign in with your Google account',
    },
    {
      id: 'oidc.okta',
      name: 'Okta SSO',
      icon: 'assets/icons/okta.svg',
      type: 'oidc',
      description: 'Sign in with your Okta account',
    },
    {
      id: 'oidc.entra',
      name: 'Microsoft Entra ID',
      icon: 'assets/icons/microsoft.svg',
      type: 'oidc',
      description: 'Sign in with your Microsoft account',
    },
  ];

  loading = false;
  selectedProvider: string | null = null;

  constructor(
    private authService: AuthService,
    private router: Router
  ) {}

  ngOnInit(): void {
    // If already authenticated, go to dashboard
    this.authService.isAuthenticated$.subscribe((isAuth) => {
      if (isAuth) {
        this.router.navigate(['/dashboard']);
      }
    });
  }

  async signIn(providerId: string): Promise<void> {
    this.loading = true;
    this.selectedProvider = providerId;

    try {
      await this.authService.signInWithProvider(providerId);
    } catch (error) {
      console.error('Sign-in failed:', error);
    } finally {
      this.loading = false;
      this.selectedProvider = null;
    }
  }

  getProviderIcon(provider: Provider): string {
    return provider.icon;
  }
}
```

### Step 3: Update Login Template

**File**: `frontend/src/app/auth/login.component.html` (updated)

```html
<div class="login-container">
  <div class="login-card">
    <div class="login-header">
      <h1>Creative Studio</h1>
      <p>Sign in to your account</p>
    </div>

    <div class="provider-selector">
      <div class="providers-grid">
        <ng-container *ngFor="let provider of providers">
          <button
            class="provider-button"
            [class.loading]="loading && selectedProvider === provider.id"
            [disabled]="loading"
            (click)="signIn(provider.id)"
            type="button"
          >
            <img [src]="getProviderIcon(provider)" [alt]="provider.name" class="provider-icon" />

            <div class="provider-info">
              <span class="provider-name">{{ provider.name }}</span>
              <span class="provider-desc" *ngIf="provider.description">
                {{ provider.description }}
              </span>
            </div>

            <div class="spinner" *ngIf="loading && selectedProvider === provider.id">
              <mat-spinner diameter="20"></mat-spinner>
            </div>

            <mat-icon class="arrow-icon">arrow_forward</mat-icon>
          </button>
        </ng-container>
      </div>
    </div>

    <div class="login-footer">
      <p>By signing in, you agree to our Terms of Service and Privacy Policy</p>
    </div>
  </div>
</div>
```

---

## Phase 4: Testing & Validation

### Unit Tests

**File**: `backend/tests/test_group_role_mapping.py`

```python
import pytest
from src.auth.group_role_mapper import GroupRoleMapping, UserRole


class TestGroupRoleMapping:
    """Test group to role conversion"""

    def test_okta_admin_group(self):
        """Test Okta admin group mapping"""
        groups = ['okta_admins']
        roles = GroupRoleMapping.get_roles_from_groups(groups)

        assert UserRole.ADMIN in roles

    def test_entra_design_team(self):
        """Test Entra design team mapping"""
        groups = ['entra_design_team']
        roles = GroupRoleMapping.get_roles_from_groups(groups)

        assert UserRole.CREATOR in roles

    def test_multiple_groups(self):
        """Test mapping multiple groups"""
        groups = ['okta_admins', 'okta_creators']
        roles = GroupRoleMapping.get_roles_from_groups(groups)

        assert UserRole.ADMIN in roles
        assert UserRole.CREATOR in roles

    def test_unknown_group_defaults_to_user(self):
        """Test unknown group defaults to USER role"""
        groups = ['unknown_group']
        roles = GroupRoleMapping.get_roles_from_groups(groups)

        assert UserRole.USER in roles

    def test_custom_mapping(self):
        """Test custom group mappings"""
        custom_mappings = {
            'custom_admins': [UserRole.ADMIN],
            'custom_editors': [UserRole.CREATOR],
        }

        groups = ['custom_admins']
        roles = GroupRoleMapping.get_roles_from_groups(groups, custom_mappings)

        assert UserRole.ADMIN in roles
```

### Integration Tests

**File**: `backend/tests/test_sync_roles_endpoint.py`

```python
import pytest
from unittest.mock import patch, AsyncMock
from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)


@pytest.mark.asyncio
async def test_sync_roles_endpoint():
    """Test /api/auth/sync-roles endpoint"""

    # Mock Firebase token verification
    mock_token = {
        'uid': 'test-user-123',
        'email': 'test@example.com',
        'access_token': 'mock-access-token',
    }

    with patch('src.config.firebase_admin.firebase_admin_service.verify_token') as mock_verify:
        mock_verify.return_value = mock_token

        # Mock OIDC service to return groups
        with patch('src.auth.oidc_service.OIDCService.get_user_groups') as mock_groups:
            mock_groups.return_value = ['okta_admins', 'okta_creators']

            response = client.post(
                '/api/auth/sync-roles',
                json={
                    'provider_id': 'oidc.okta',
                    'issuer_url': 'https://company.okta.com',
                },
                headers={'Authorization': 'Bearer mock-token'},
            )

    assert response.status_code == 200
    data = response.json()
    assert data['success'] is True
    assert 'admin' in data['roles']
    assert 'creator' in data['roles']
    assert len(data['groups']) == 2
```

### Manual Testing Checklist

- [ ] Sign in with Google - verify works
- [ ] Sign in with Okta - verify redirects to Okta
- [ ] Sign in with Entra ID - verify redirects to Azure
- [ ] After Okta sign-in - verify roles appear in token
- [ ] After Entra sign-in - verify groups appear in token
- [ ] Change group membership in OIDC provider
- [ ] Call /api/auth/refresh-roles endpoint
- [ ] Verify new roles appear in token
- [ ] Sign out - verify session cleared
- [ ] Test with multiple providers in same app

---

## Troubleshooting

### Issue: "OIDC provider not found" in Firebase Console

**Solution**:
1. Verify provider ID is correct (e.g., `oidc.okta`)
2. Check client credentials are valid
3. Verify issuer URL matches provider configuration
4. Test discovery URL manually: `https://issuer/.well-known/openid-configuration`

### Issue: "Failed to get groups from OIDC provider"

**Solution**:
1. Verify access token has `groups` scope
2. Check OIDC provider's /userinfo endpoint returns groups claim
3. Verify provider type in backend matches actual provider
4. Check token hasn't expired

### Issue: Roles not appearing in custom claims

**Solution**:
1. Call `/api/auth/sync-roles` endpoint after sign-in
2. Wait 5 minutes for Firebase cache to expire
3. Force token refresh: `user.getIdToken(true)`
4. Check Firestore document updated (fallback storage)

---

**Next Steps**: Proceed to Phase 4 (Testing & Validation) once all code is deployed to staging environment.
