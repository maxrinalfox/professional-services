# Bug Report: Hybrid Broken Authentication System

**Bug ID**: BUG-002
**Status**: 🔴 Open
**Severity**: Critical
**Component**: Backend / Frontend / Authentication
**Reported**: December 17, 2025
**Assigned**: Unassigned

---

## Summary

The application uses a fundamentally broken hybrid authentication system that mixes Firebase SDK with custom PostgreSQL user management, preventing enterprise features like OIDC providers (Okta, SAML) and proper OAuth 2.0 flows.

---

## Detailed Description

### Current Architecture

The application has two conflicting authentication approaches running simultaneously:

#### Frontend Issues
- **Production**: Uses deprecated `google.accounts.id` API (Google phasing this out)
- **Local Dev**: Uses Firebase SDK (inconsistent)
- **Result**: Different code paths for same feature
- **Limitation**: Hardcoded to Google only, no provider selector UI

#### Backend Issues
- **User Storage**: PostgreSQL (NOT Firebase Authentication)
- **Firebase Role**: Only validates tokens, doesn't manage users
- **User Data Split**:
  - PostgreSQL: `users` table (email, roles, name, picture)
  - Firestore: `user` collection (workspace permissions, metadata)
  - Firebase Auth: Not used (wasted)

#### Architecture Issues
- Firebase SDK imported but user management features unused
- No single source of truth for user data
- Cannot leverage Firebase provider federation
- Each new provider requires custom code changes

### Current Flow

```
User Login
    ↓
Production: google.accounts.id → Token
Local Dev: Firebase SDK → Token
    ↓
Send token to backend
    ↓
Backend validates signature (Firebase Admin SDK)
    ↓
Extract email from token claims
    ↓
Query PostgreSQL for user (NOT Firebase Auth!)
    ↓
Create user in PostgreSQL if not exists (JIT provisioning)
    ↓
Query Firestore for workspace roles/permissions
    ↓
Return response with user data

Problem: Users only in PostgreSQL
         Cannot add new providers without complete rewrite
```

### Why This Blocks Enterprise Features

1. **Cannot Add Okta**
   - Okta issues ID tokens
   - But no user in Firebase Authentication
   - Would need to bypass Firebase entirely
   - Breaks existing Google-only flow

2. **Cannot Add SAML**
   - Same limitations as Okta
   - No provider federation support

3. **Cannot Implement Proper OAuth 2.0**
   - Firebase SDK scattered throughout code
   - Would need to remove Firebase completely
   - Too many integration points

4. **Cannot Use Firebase Provider Federation**
   - Users not in Firebase Authentication directory
   - Provider federation only works with Firebase users
   - Creates duplicate user management logic

---

## Root Cause

**Original Design Decision**: Firebase was chosen for convenience, but:
- Only Firebase tokens validated (Firebase Admin SDK)
- User management still done in PostgreSQL (legacy)
- No proper OIDC/OAuth 2.0 implementation
- Result: Worst of both worlds (coupled to Firebase, locked into Google)

---

## How to Replicate

### Attempt to Add Okta Provider

1. Try to implement Okta OAuth 2.0 flow
2. User authenticates with Okta
3. Receive Okta ID token
4. Attempt to create user in system
5. **Result**: Code path breaks because:
   - Firebase Admin SDK can't validate Okta tokens
   - User management is PostgreSQL-only
   - No OIDC endpoint integration
   - Would require rewriting auth layer

### Expected vs Actual

**Expected**: Easy provider switching (Firebase → Okta)
**Actual**: Complete rewrite required (Firebase + PostgreSQL → Pure OIDC)

---

## Impact Assessment

### Affected Users
- Enterprise customers wanting SSO with Okta/SAML
- Organizations using non-Google identity providers
- Any multi-provider setup

### Severity
- **Scope**: Complete blocker for enterprise authentication roadmap
- **Business Impact**: Cannot support enterprise security requirements
- **Technical Impact**: Architecture prevents all multi-provider work
- **Timeline**: Blocks Phase 2 and Phase 3 of planned roadmap

### Effort to Fix
- **Option A**: Leverage Firebase properly (3-4 weeks)
- **Option B**: Replace with Pure OIDC (3-5 weeks)

---

## Solution Options

### Option A: Fix & Leverage Firebase (Recommended for Google-heavy orgs)
**Effort**: 3-4 weeks
**Cost**: Medium
**Complexity**: High

**Approach**:
1. Migrate users from PostgreSQL to Firebase Authentication
2. Use Firebase provider federation for multi-provider support
3. Remove custom PostgreSQL user management
4. Use Firebase Admin SDK for user provisioning
5. Migrate workspace/roles data to Firestore only

**Pros**:
- Leverages existing Firebase infrastructure
- Built-in provider federation (Google, GitHub, Facebook, etc.)
- Firebase handles OIDC token validation
- Reduces custom auth code
- Firebase Console for user management

**Cons**:
- More Google-dependent
- Firebase quotas/limits apply
- Still needs custom OIDC provider integration (Okta, SAML)
- Cost increases with user count (Firebase Auth billing)

**Files Affected**:
- `backend/src/auth/` - rewrite token validation
- `backend/bootstrap/` - migrate user creation
- `frontend/src/auth/` - use Firebase SDK consistently
- Database migrations - migrate users to Firebase

---

### Option B: Replace with Pure OAuth 2.0 OIDC (Recommended for multi-provider orgs)
**Effort**: 3-5 weeks
**Cost**: Medium-High
**Complexity**: Very High

**Approach**:
1. Remove Firebase SDK from frontend/backend
2. Implement standard OIDC flows
3. Support any OIDC provider (Google, Okta, Auth0, etc.)
4. Users stored in PostgreSQL (single source of truth)
5. Implement PKCE, refresh tokens, JWT validation

**Pros**:
- Works with ANY OIDC provider
- No Firebase dependency
- More flexible and portable
- Industry standard (not vendor-locked)
- Easier to migrate to other systems later

**Cons**:
- More complex implementation
- Need to implement OIDC from scratch
- More testing required
- More security considerations
- No Firebase Console user management

**Files Affected**:
- `backend/src/auth/` - complete rewrite
- `frontend/src/auth/` - complete rewrite
- Remove: Firebase Admin SDK, Firebase SDK
- Add: OIDC library (authlib, python-jose, etc.)

---

### Option C: Temporary Hybrid Workaround
**Effort**: 1-2 weeks
**Cost**: Low
**Not Recommended**: Technical debt

**Approach**:
1. Add provider-specific logic branches
2. Support both Google and Okta in same codebase
3. Custom OIDC validation per provider

**Pros**:
- Quick fix
- Can onboard some Okta customers

**Cons**:
- Becomes unmaintainable fast
- Each provider adds code complexity
- Not scalable
- High technical debt
- Not a real solution

---

## Recommendation

**Implement Option B (Pure OAuth 2.0 OIDC)** because:

1. **Future-proof**: Works with ANY provider (Google, Okta, Auth0, Azure AD, custom)
2. **Flexible**: Not locked into Firebase ecosystem
3. **Enterprise-ready**: Industry standard, no vendor lock-in
4. **Portable**: Easier to migrate systems later
5. **Long-term**: Supports multi-tenant enterprise scenarios

**Timeline**:
- Phase 1 (Weeks 1-2): Design OIDC flow, choose library
- Phase 2 (Weeks 2-4): Implement backend OIDC validation
- Phase 3 (Week 4-5): Implement frontend OAuth flow
- Phase 4: Testing, security review

---

## Technical Details

### Affected Files

**Frontend**:
- `frontend/src/app/auth/` - All auth components
- `frontend/src/app/login/` - Login page
- `frontend/src/main.ts` - Firebase initialization (remove)
- `frontend/src/environments/` - Auth config

**Backend**:
- `backend/src/auth/` - Token validation, user creation
- `backend/src/users/` - User service
- `backend/src/config/` - Auth configuration
- `backend/bootstrap/` - User seeding
- `backend/requirements.txt` - Firebase SDK (remove)

**Database**:
- `backend/alembic/versions/` - User migration scripts
- Firestore collections may need restructuring

### Current Code Patterns

**Backend Token Validation** (firebase_admin):
```python
# Current (Firebase only)
decoded_token = auth.verify_id_token(token)
email = decoded_token['email']
```

**Frontend Login** (Mixed):
```javascript
// Production: google.accounts.id
google.accounts.id.initialize({ client_id: ... });

// Local: Firebase SDK
signInWithPopup(auth, googleProvider)
```

---

## Testing

### Pre-Migration Testing
1. Document all auth flows currently working
2. Verify Google authentication works
3. Test token validation with actual Firebase tokens
4. Verify workspace/role assignment

### Post-Migration Testing (Option B)

**OAuth 2.0 Flow Testing**:
1. Test with Google OIDC provider
2. Test with Okta OIDC provider
3. Test with Auth0 OIDC provider
4. Test PKCE flow
5. Test refresh token handling
6. Test token expiration/refresh
7. Test multiple providers same user
8. Test workspace permissions after auth

**Security Testing**:
1. CSRF protection
2. Token validation
3. Refresh token security
4. Session management
5. Logout/token revocation

**Integration Testing**:
1. API access after auth
2. Workspace access control
3. Role-based permissions
4. Admin features

---

## Related Issues

- **BUG-003**: Data Consistency Across User Storage (depends on auth system)
- **BUG-002**: Related to user provisioning and roles

---

## Dependencies

- Blocks: Okta integration, SAML support, multi-provider roadmap
- Blocked by: User migration planning, OIDC provider selection
- Related: User data consistency, role management

---

## Timeline

- **Reported**: December 17, 2025
- **Expected Start**: After Phase 1 planning
- **Expected Duration**: 3-5 weeks (Option B recommended)
- **Status**: Waiting for architecture decision

---

## References

- [See also: Troubleshooting Guide](../07-operations/03_TROUBLESHOOTING_GUIDE.md) - Authentication troubleshooting
- [See also: Architecture](../02-architecture/01_SYSTEM_DESIGN.md) - Current system design
- [See also: API Endpoints](../03-backend/02_API_ENDPOINTS_REFERENCE.md) - Auth endpoints

---

## Decision Log

### Decision Required
- [ ] Choose Option A or Option B (or custom hybrid)
- [ ] Assign implementation team
- [ ] Plan Phase 1 detailed implementation

### Checklist for Resolution

- [ ] Architecture decision made (A or B)
- [ ] Implementation plan created
- [ ] User migration strategy defined (if Option A)
- [ ] OIDC provider list finalized (if Option B)
- [ ] Security review of design
- [ ] Testing plan created
- [ ] Frontend implementation complete
- [ ] Backend implementation complete
- [ ] User data migration complete
- [ ] All tests passing
- [ ] Security testing passed
- [ ] Documentation updated
- [ ] Deployment completed

---
