# Phase 1: Two Alternatives to Fix Authentication

**Status**: Decision Point
**Last Updated**: December 17, 2025
**Purpose**: Choose between two fundamentally different approaches to fix the current hybrid authentication system

---

## The Current Problem

Creative Studio has a **hybrid broken authentication implementation**:

- ✅ Imports Firebase SDK but doesn't use it properly
- ✅ Uses deprecated `google.accounts.id` API in production
- ❌ Only supports Google Sign-In
- ❌ Users stored in PostgreSQL, not Firebase Authentication
- ❌ Can't add Okta, SAML, or other OIDC providers without major refactoring

**You must choose ONE path to fix this. Phase 2 and 3 depend on your choice here.**

---

## Alternative A: Fix & Leverage Firebase Authentication

### What This Means

**Commit to using Firebase Authentication as the primary user directory.**

- Users created in Firebase Authentication
- Firestore for metadata + permissions
- PostgreSQL for application-specific data (workspaces, media items)
- Leverage Firebase's provider federation

### Implementation Approach

**Frontend Changes**:
1. Replace deprecated `google.accounts.id` with Firebase SDK's `signInWithPopup()`
2. Implement provider selector UI (dropdown for Google, Okta, custom OIDC)
3. Remove environment branching (local vs prod uses same code)
4. Let Firebase handle multi-provider federation

**Backend Changes**:
1. Keep Firebase Admin SDK for token validation ✅ (already doing this)
2. **NEW**: Create users in Firebase Authentication (currently not done)
3. Sync Firebase user metadata to Firestore (roles, workspace permissions)
4. Query Firebase Auth for user directory (instead of PostgreSQL)
5. Keep PostgreSQL for: workspaces, media items, templates (not user records)

**Database Changes**:
- **Move**: User directory from PostgreSQL → Firebase Authentication
- **Keep**: Application data (workspaces, media, etc.) in PostgreSQL
- **Use**: Firestore for user metadata and real-time sync

### Code Reference

**Working Example**: `/home/rinal/Desktop/temp/firebase_auth/`
- Users appear in Firebase Console
- Multi-provider support works
- Provider federation configured

### Timeline

- **Frontend**: 1-2 weeks (provider UI + remove google.accounts.id)
- **Backend**: 1 week (create users in Firebase Auth)
- **Testing**: 1 week
- **Total**: 3-4 weeks

### Pros

✅ Leverages Google-managed user directory
✅ Built-in multi-provider federation
✅ Automatic user provisioning
✅ Firebase Console shows all users
✅ Less code to maintain (Firebase handles provider logic)
✅ Better for enterprise (ready for Okta integration via Firebase OIDC)

### Cons

❌ Adds dependency on Firebase Authentication
❌ User data split across services (Firebase + PostgreSQL + Firestore)
❌ Complex data sync between Firebase and PostgreSQL
❌ Cost: Firebase Authentication has free tier but limits (50K users)
❌ Vendor lock-in to Firebase

### Phase 2 Impact

✅ Easy to add OIDC providers (Firebase config only)
✅ Okta integration straightforward (use OIDC + custom claims)
✅ Group/role sync from Okta to Firebase custom claims

---

## Alternative B: Implement Pure OAuth 2.0 Authorization Code Flow

### What This Means

**Implement standard OAuth 2.0 / OIDC Authentication Code Flow without Firebase Authentication.**

**Key Point**: Uses **backend-driven Authorization Code Flow** (NOT PKCE), where:
- Backend handles OAuth client credentials (`clientId` + `clientSecret`)
- Backend exchanges authorization code for tokens
- Tokens stored securely in backend (session, encrypted cookies)
- Frontend never handles raw tokens directly
- Much more secure than frontend-only PKCE approach

**Architecture**:
- Direct OIDC integration with identity providers (Google, Okta, custom)
- PostgreSQL as single user directory
- Firestore for real-time metadata/sync only
- OAuth 2.0 Authorization Code Flow with backend token management

### Implementation Approach

**Frontend Changes**:
1. Replace Firebase SDK + google.accounts.id with OIDC redirect (to backend)
2. Implement provider selector UI (dropdown for Google, Okta, generic OIDC)
3. Login flow: Frontend → Backend → OAuth Provider → Backend → Frontend
4. Frontend communicates with backend (not OIDC provider directly)
5. Tokens **NOT exposed** to frontend (stored securely in backend)

**Backend Changes**:
1. **NEW**: Implement OIDC authorization code exchange (using `clientSecret`)
2. **NEW**: Implement token validation and refresh (verify JWT signature from provider)
3. **NEW**: Implement secure session management (HTTP-only cookies or secure tokens)
4. **Remove**: Firebase Admin SDK dependency (no longer needed)
5. Create/update users in PostgreSQL (single source of truth)
6. Sync user metadata to Firestore for real-time features

**Database Changes**:
- **User directory**: PostgreSQL (single source of truth)
- **Metadata**: Firestore (real-time sync, permissions)
- **No Firebase Auth**: Completely removed
- **Session/Tokens**: Stored securely in backend (NOT in frontend)

### Code Reference

**Working Example**: `/home/rinal/Desktop/temp/oauth_auth_pkce/`
- Direct OIDC integration (OAuth 2.0 Authorization Code Flow)
- Backend handles `clientSecret` securely
- Works with any OIDC provider (Google, Okta, Auth0, etc.)
- Seamless SSO support
- Provider-agnostic configuration

### Timeline

- **Frontend**: 1-2 weeks (Login/callback UI, no token handling)
- **Backend**: 2-3 weeks (Auth code exchange, token management, session/cookie handling)
- **Testing**: 1 week
- **Total**: 4-6 weeks (slightly longer due to backend complexity)

### Pros

✅ **Most Secure**: Backend handles `clientSecret`, frontend never sees tokens
✅ **Standard OAuth 2.0 Authorization Code Flow**: Industry standard, proven secure
✅ **Works with any OIDC provider**: Google, Okta, Auth0, Keycloak, custom
✅ **Single user directory**: PostgreSQL is source of truth
✅ **No Firebase dependency**: Complete independence
✅ **Complete control over tokens**: Backend manages lifecycle, refresh, validation
✅ **No vendor lock-in**: Fully portable
✅ **Can support SAML**: Add SAML adapter layer
✅ **Seamless SSO**: Built-in support for silent authentication (prompt=none)
✅ **Better for enterprises**: Aligns with enterprise authentication patterns
✅ **Simpler data model**: All user data in one place

### Cons

❌ More code to write + maintain (especially backend complexity)
❌ Must handle OAuth 2.0 state management (`state` parameter)
❌ Must implement token refresh logic (background token refresh)
❌ Must handle provider discovery + configuration
❌ Must implement secure session/cookie management
❌ Longer implementation time than Firebase
❌ Need to handle provider-specific claim mappings
❌ Session timeout management more complex

### Phase 2 Impact

✅ Straightforward to add OIDC providers (add provider config)
✅ Okta: Configure as OIDC provider, map groups to roles
✅ Custom OIDC: Configure endpoint + scopes
✅ SAML support: Add SAML provider adapter layer

---

## Decision Matrix

| Aspect | Firebase | Pure OAuth 2.0 Auth Code |
|--------|----------|----------|
| **Learning Curve** | Medium (Firebase concepts) | Medium-High (OIDC + OAuth 2.0 concepts) |
| **Implementation Time** | 3-4 weeks | 4-6 weeks |
| **Security Level** | ✅ High (Firebase managed) | ✅✅ Highest (Backend-driven, no frontend tokens) |
| **Token Handling** | Firebase SDK on frontend | Backend only (HTTP-only cookies/secure session) |
| **Client Secret** | Not needed on frontend | **Required** - Backend only |
| **Multi-Provider** | ✅ Easy (Firebase federation) | ✅ Standard (OIDC protocol) |
| **Okta Support** | ✅ Via OIDC provider config | ✅ Native OIDC (no intermediate needed) |
| **SAML Support** | ⚠️ Not built-in | ✅ Can add adapter layer |
| **User Directory** | Firebase Authentication | PostgreSQL (single source of truth) |
| **Code Complexity** | Medium | High (backend token management) |
| **Maintenance** | Google (Firebase) | You (custom code) |
| **Cost** | Free → paid (50K+ users) | Free (pay for hosting) |
| **Vendor Lock-in** | ✅ Google/Firebase | ❌ None (fully portable) |
| **Data Control** | ⚠️ Split (Firebase + PostgreSQL) | ✅ Single source (PostgreSQL) |
| **Enterprise Ready** | ✅ Yes | ✅✅ Yes (aligns with enterprise patterns) |
| **Seamless SSO** | ⚠️ Requires configuration | ✅ Built-in (prompt=none support) |

---

## Complementary: Identity-Aware Proxy (IAP) Authorization Layer

### Important Distinction

**Phase 1 choices above are AUTHENTICATION** (answers: "Who are you?")

**IAP is AUTHORIZATION** (answers: "Can you access this service?")

**These are complementary, not mutually exclusive.**

### What is IAP?

Identity-Aware Proxy (IAP) provides infrastructure-layer access control:

- ✅ Intercepts all requests to Cloud Run
- ✅ Checks if user is in IAM group
- ✅ Only authorized users reach backend
- ✅ No application-level access control needed (though RBAC still recommended)

### When to Use IAP

Use IAP if:
- You need centralized access control (via IAM groups)
- You want infrastructure-layer filtering
- You need to scale beyond 100 users
- Your company manages users via Google Workspace / Cloud Identity groups
- You prefer infrastructure team to manage access vs. application code

**See**: `07_IAP_AUTHORIZATION_LAYER.md` for complete details, including:
- How IAP works with both Firebase and Pure OIDC
- Terraform configuration from secondary app
- Permission management comparison
- When IAP is sufficient vs. when you need application RBAC

**See**: `08_IAP_INTEGRATION_TROUBLESHOOTING.md` if you encounter:
- "Invalid bearer token. Invalid jwt audience." error
- JWT audience mismatches with IAP enabled
- Configuration issues when enabling IAP

---

## How to Choose

### Choose **Firebase** if:
- You want minimal code to maintain
- You're comfortable with Google/Firebase ecosystem
- You want Firebase Console user management
- You need automatic provider federation
- Users > 50K (after that, cost matters)

### Choose **Pure OAuth 2.0 Authorization Code** if:
- You need **highest security** (backend manages all tokens and secrets)
- You need complete data control (PostgreSQL single source of truth)
- You want no vendor lock-in (fully portable)
- You need SAML support (via adapter layer)
- You need **enterprise-grade authentication** (aligns with enterprise patterns)
- You prefer standard OAuth 2.0 over proprietary solutions
- You have internal/custom OIDC providers
- Team is familiar with OAuth 2.0 and OIDC
- You need seamless SSO with multiple providers

---

## Implementation Comparison

### Firebase: File Changes Required

**Frontend**:
- `src/app/login/login.component.ts` - Remove google.accounts.id branch
- `src/app/common/services/auth.service.ts` - Add provider selector, clean up
- `src/environments/environment.ts` - Add provider list config
- `src/index.html` - Keep Firebase script, remove Google script

**Backend**:
- `src/auth/firebase_client_service.py` - Add user creation in Firebase Auth
- `src/auth/auth_guard.py` - Update to query Firebase Auth instead of PostgreSQL
- Database schema - Remove or reduce users table (Firebase is source of truth)

---

### Pure OAuth 2.0 Authorization Code: File Changes Required

**Frontend** (Simpler - No Token Management):
- `src/app/login/login.component.ts` - Implement OAuth 2.0 login redirect (to backend)
- `src/app/auth/callback.component.ts` - Handle OAuth callback from backend
- `src/app/common/services/auth.service.ts` - Replace Firebase with backend calls
- `src/environments/environment.ts` - Add provider selector config
- `src/index.html` - Remove Firebase script, remove Google script
- **Important**: Frontend does NOT handle tokens directly

**Backend** (More Complex - Token Management):
- `src/auth/oauth_provider.py` - New OAuth 2.0 provider integration
  - Implement authorization code exchange
  - Implement token refresh logic
  - Handle provider discovery
- `src/auth/auth_guard.py` - Update to use backend session/tokens
  - Verify session validity
  - Refresh tokens if needed
  - Extract user info from backend session (not from JWT directly)
- `src/auth/session_manager.py` - New session/cookie management
  - Secure session storage
  - Token refresh strategy
  - Session timeout handling
- `src/auth/jwt_validator.py` - JWT signature verification from provider
- Keep: PostgreSQL user creation and management
- Remove: Firebase Admin SDK dependency

---

## Phase 2 Readiness

### If You Choose Firebase (Phase 1)

Phase 2 will involve:
1. Configure Okta as OIDC provider in Firebase Console
2. Map Okta groups to Firebase custom claims
3. Update frontend: Add Okta to provider list
4. Update backend: Parse custom claims for roles
5. **Time**: 1-2 weeks

### If You Choose Pure OAuth 2.0 Authorization Code (Phase 1)

Phase 2 will involve:
1. Add Okta as OIDC provider in backend configuration
2. Implement Okta-specific claim mapping (groups → roles)
3. Add Okta to provider selector UI (frontend)
4. Test seamless SSO with Okta (prompt=none support already built-in)
5. Map Okta groups to PostgreSQL roles table
6. **Time**: 1-2 weeks (simpler because backend already supports any OIDC provider)

---

## Recommendation

**For Creative Studio specifically:**

Choose **Pure OAuth 2.0 Authorization Code Flow** because:

1. **Security First**: Backend manages `clientSecret` and all tokens - frontend never exposed to credentials
2. **Enterprise Ready**: Aligns with enterprise authentication patterns (how Okta, Google Workspace, etc. work)
3. **PostgreSQL Native**: Already have PostgreSQL for user data (single source of truth)
4. **Multi-Provider Support**: Works with any OIDC provider (Okta, Auth0, Google, Keycloak, custom)
5. **No Vendor Lock-in**: Fully portable, not tied to Firebase ecosystem
6. **Seamless SSO**: Built-in support for silent authentication (prompt=none)
7. **Complete Control**: Manage token lifecycle, refresh, and validation
8. **Future-Proof**: Standard OAuth 2.0 (industry standard, not proprietary)
9. **Better for SaaS**: Single user directory in PostgreSQL (important for multi-tenant applications)

**Why not Firebase?**
- Firebase Authentication adds vendor lock-in
- Would split user data (Firebase + PostgreSQL)
- More complex for enterprise SSO scenarios
- Less control over token management

**However**: If you prefer simplified implementation and accept Google ecosystem lock-in, **Firebase is a valid alternative** (simpler but less secure and less enterprise-friendly).

---

## Next Steps

1. **Decide**: Which alternative fits your needs best?
   - Recommended: **Pure OAuth 2.0 Authorization Code Flow** (most secure, enterprise-ready)
   - Alternative: **Firebase** (simpler, but vendor lock-in)
2. **Review**: Reference implementations
   - Firebase: `/home/rinal/Desktop/temp/firebase_auth/`
   - **OAuth 2.0 Auth Code** (Recommended): `/home/rinal/Desktop/temp/oauth_auth_pkce/`
     - Shows backend-driven flow with `clientSecret`
     - Session management pattern
     - Token refresh logic
     - Seamless SSO support
3. **Plan**: Create implementation tickets based on choice
4. **Execute**: Phase 1 refactoring (4-6 weeks recommended approach)
5. **Then**: Phase 2 adds Okta + groups support (1-2 weeks)

---

## Questions?

- **Firebase approach**: See Google Cloud docs + Angular Fire docs
- **OIDC approach**: See OAuth 2.0 PKCE spec + OIDC spec
- **Okta integration**: See Okta docs for both approaches
- **Reference code**: Check the demo apps mentioned above

