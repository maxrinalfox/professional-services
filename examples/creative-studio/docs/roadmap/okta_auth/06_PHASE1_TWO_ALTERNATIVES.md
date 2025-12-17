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

## Alternative B: Implement Pure OAuth 2.0 OIDC

### What This Means

**Implement standard OAuth 2.0 / OIDC authentication without Firebase Authentication.**

- Direct OIDC integration with identity providers (Google, Okta, custom)
- PostgreSQL as single user directory
- Firestore for real-time metadata/sync only
- Standard OIDC PKCE flow (proven, portable)

### Implementation Approach

**Frontend Changes**:
1. Replace Firebase SDK + google.accounts.id with standard OIDC client
2. Implement provider selector UI (dropdown for Google, Okta, generic OIDC)
3. Use PKCE flow (proven secure for SPAs)
4. Tokens stored in secure HTTP-only cookies

**Backend Changes**:
1. **NEW**: Implement OIDC token validation (verify JWT signature from provider)
2. **Remove**: Firebase Admin SDK dependency (no longer needed)
3. **Keep**: Custom claims in JWT tokens
4. Create/update users in PostgreSQL (single source of truth)
5. Sync user metadata to Firestore for real-time features

**Database Changes**:
- **User directory**: PostgreSQL (single source of truth)
- **Metadata**: Firestore (real-time sync, permissions)
- **No Firebase Auth**: Completely removed

### Code Reference

**Working Example**: `/home/rinal/Desktop/temp/oauth_auth_pkce/`
- Direct OIDC integration
- Standard OAuth 2.0 PKCE flow
- Portable to any provider

### Timeline

- **Frontend**: 1-2 weeks (OIDC client + provider UI)
- **Backend**: 1-2 weeks (JWT validation + user creation)
- **Testing**: 1 week
- **Total**: 3-5 weeks

### Pros

✅ Standard OIDC (portable, works with any provider)
✅ Single user directory (PostgreSQL)
✅ No Firebase dependency
✅ Complete control over user data
✅ No vendor lock-in
✅ Works with any OIDC provider (Okta, Auth0, Keycloak, custom)
✅ Can support SAML if needed (add SAML adapter)
✅ Simpler data model (all user data in one place)

### Cons

❌ More code to write + maintain
❌ Must handle provider discovery + configuration
❌ Must implement token validation (verify signatures)
❌ Self-hosted responsibility (password resets, user verification, etc.)
❌ Longer implementation time
❌ Need to handle provider-specific claim mappings

### Phase 2 Impact

✅ Straightforward to add OIDC providers (add provider config)
✅ Okta: Configure as OIDC provider, map groups to roles
✅ Custom OIDC: Configure endpoint + scopes
✅ SAML support: Add SAML provider adapter layer

---

## Decision Matrix

| Aspect | Firebase | Pure OIDC |
|--------|----------|----------|
| **Learning Curve** | Medium (Firebase concepts) | Medium (OIDC concepts) |
| **Implementation Time** | 3-4 weeks | 3-5 weeks |
| **Multi-Provider** | ✅ Easy (Firebase federation) | ✅ Standard (OIDC protocol) |
| **Okta Support** | ✅ Via OIDC provider | ✅ Native OIDC |
| **SAML Support** | ⚠️ Not built-in | ✅ Can add adapter |
| **User Directory** | Firebase Auth | PostgreSQL |
| **Code Complexity** | Medium | High |
| **Maintenance** | Google (Firebase) | You (custom code) |
| **Cost** | Free → paid (50K+ users) | Free (pay for hosting) |
| **Vendor Lock-in** | ✅ Google/Firebase | ❌ None |
| **Data Control** | ⚠️ Split | ✅ Single source |
| **Enterprise Ready** | ✅ Yes | ✅ Yes |

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

### Choose **Pure OIDC** if:
- You need complete data control
- You want no vendor lock-in
- You need SAML support
- You prefer standard protocols over proprietary solutions
- You have internal/custom OIDC providers
- Team is familiar with OAuth/OIDC

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

### Pure OIDC: File Changes Required

**Frontend**:
- `src/app/login/login.component.ts` - Implement OIDC flow
- `src/app/common/services/auth.service.ts` - Replace Firebase with OIDC client lib
- `src/environments/environment.ts` - Add OIDC provider configs
- `src/index.html` - Remove Firebase script
- New file: `src/app/common/services/oidc.service.ts` - OIDC integration

**Backend**:
- `src/auth/` - New OIDC validation module
- `src/auth/firebase_client_service.py` - Remove (no longer needed)
- `src/auth/jwt_validator.py` - Implement JWT signature verification
- Keep: PostgreSQL user creation and management

---

## Phase 2 Readiness

### If You Choose Firebase (Phase 1)

Phase 2 will involve:
1. Configure Okta as OIDC provider in Firebase Console
2. Map Okta groups to Firebase custom claims
3. Update frontend: Add Okta to provider list
4. Update backend: Parse custom claims for roles
5. **Time**: 1-2 weeks

### If You Choose Pure OIDC (Phase 1)

Phase 2 will involve:
1. Configure Okta as OIDC provider in backend
2. Add provider discovery endpoint
3. Map Okta groups to PostgreSQL roles table
4. Update frontend: Add Okta to provider selector
5. **Time**: 1-2 weeks

---

## Recommendation

**For Creative Studio specifically:**

Choose **Pure OIDC** because:
1. You already have PostgreSQL for user data (don't need Firebase Auth)
2. You need to support custom/internal OIDC providers (for enterprise customers)
3. You want complete data control (important for SaaS)
4. No Firebase lock-in (more portable)
5. Simpler data model (single source of truth in PostgreSQL)

**However**: If you prefer Google-managed user infrastructure and don't mind firebase, **Firebase is valid too**.

---

## Next Steps

1. **Decide**: Which alternative fits your needs best?
2. **Review**: Reference implementations
   - Firebase: `/home/rinal/Desktop/temp/firebase_auth/`
   - OIDC: `/home/rinal/Desktop/temp/oauth_auth_pkce/`
3. **Plan**: Create implementation tickets based on choice
4. **Execute**: Phase 1 refactoring
5. **Then**: Phase 2 adds Okta + groups support

---

## Questions?

- **Firebase approach**: See Google Cloud docs + Angular Fire docs
- **OIDC approach**: See OAuth 2.0 PKCE spec + OIDC spec
- **Okta integration**: See Okta docs for both approaches
- **Reference code**: Check the demo apps mentioned above

