# Authentication Options: Quick Start Guide

**TL;DR**: Use **Option A (Firebase + OIDC Fallback)** for a 24-day implementation with full group/role support.

---

## The Challenge

Current setup (Google OAuth only):
- ❌ Can't support enterprise SSO (Okta, Entra, Keycloak)
- ❌ No user groups/directory integration
- ❌ Manual role assignment required
- ❌ Not enterprise-ready

**Goal**: Add enterprise OIDC support + automatic group-to-role mapping

---

## Three Approaches Compared

### Quick Comparison

| Aspect | Option A (⭐ Recommended) | Option B | Current |
|--------|-------------|----------|---------|
| **Implementation Time** | **24 days** | 58 days | - |
| **Code Changes** | **20%** | 80% | - |
| **Risk Level** | **Low** | High | - |
| **Firebase Kept** | ✅ **Yes** | ❌ No | ✅ Yes |
| **Group Support** | ✅ **Yes** | ✅ Yes | ❌ No |
| **Effort** | **120 hrs** | 250+ hrs | - |

---

## Option A: Firebase + OIDC Fallback

### What It Is

Keep Firebase, add Okta/Entra/Keycloak as optional OIDC providers:

```
User → Google OAuth OR OIDC → Firebase Auth → Roles from Groups → App
```

### Why It Wins

1. **Minimal Changes**: Only 20% of code affected
2. **Fast**: 24 days vs 58 days
3. **Safe**: Google Sign-In still works (fallback)
4. **Enterprise**: Full group/role support
5. **Proven**: Firebase handles multiple providers natively

### How It Works

**At Login**:
1. User chooses provider (Google / Okta / Entra)
2. Firebase handles OAuth callback
3. Backend calls OIDC `/userinfo` to get groups
4. Groups mapped to roles automatically
5. Roles stored in Firebase custom claims + Firestore

**Example Flow**:
```
User signs in with Okta
  → Firebase verifies token
  → Backend calls Okta /userinfo
  → Gets groups: ['okta_admins', 'okta_creators']
  → Maps to roles: ['admin', 'creator']
  → Stores in Firebase custom claims
  → User has admin + creator roles
```

---

## Implementation Roadmap

### Timeline (4 Weeks)

```
Week 1: Preparation & Backend Setup
┌─────────┬──────────────────┐
│ Day 1-2 │ Get OIDC creds   │
│ Day 3-4 │ Build OIDC svc   │ ← Start here
│ Day 5   │ Build group map  │
└─────────┴──────────────────┘

Week 2: Backend + Frontend Setup
┌─────────┬──────────────────┐
│ Day 6-7 │ Role sync API    │
│ Day 8-10│ Frontend update  │
└─────────┴──────────────────┘

Week 3: Testing
┌─────────┬──────────────────┐
│ Day 11-15│ Full E2E tests  │
│ Day 16  │ Security review  │
└─────────┴──────────────────┘

Week 4: Deploy
┌─────────┬──────────────────┐
│ Day 17-20│ Staging test    │
│ Day 21-24│ Prod rollout    │
└─────────┴──────────────────┘
```

### Effort Breakdown

- **Backend**: 50 hours (OIDC service, role mapping, API)
- **Frontend**: 30 hours (auth service, UI, provider selection)
- **Testing**: 25 hours (unit, integration, E2E)
- **DevOps/Ops**: 15 hours (setup, monitoring, runbooks)

**Total**: ~120 hours (2-3 weeks for a team of 2-3 developers)

---

## Phase 1: Backend (Weeks 1-2, 50 hours)

### Files to Create

1. **`src/auth/oidc_service.py`** (200 lines)
   - Fetch OIDC provider config
   - Get user info from provider
   - Extract groups (provider-specific)

2. **`src/auth/group_role_mapper.py`** (100 lines)
   - Map groups → roles (configurable)
   - Support Okta, Entra, Keycloak

3. **`src/routes/auth_controller.py`** - Add endpoint:
   - `POST /api/auth/sync-roles` (50 lines)
   - Verify token → Get groups → Sync roles → Return response

### Files to Modify

1. **`backend/.env`** - Add:
   ```env
   OKTA_ISSUER_URL=https://your-org.okta.com
   ENTRA_TENANT_ID=xxx
   ```

2. **`requirements.txt`** - Add:
   ```
   python-jose[cryptography]>=3.3.0
   httpx>=0.24.0
   ```

### Phase 1 Output

✅ Backend can:
- Discover OIDC provider config
- Fetch user groups from Okta/Entra/Keycloak
- Map groups to roles
- Store roles in Firebase custom claims
- Fallback gracefully if provider unavailable

---

## Phase 2: Frontend (Week 2, 30 hours)

### Files to Create

1. **UI Components**:
   - `auth/login.component.ts` - Provider selector (50 lines new code)
   - `auth/login.component.html` - Multi-provider UI
   - `auth/login.component.scss` - Styling

### Files to Modify

1. **`src/app/common/services/auth.service.ts`** (100 lines added):
   - Add `signInWithOIDC(providerId)` method
   - Add `syncUserRolesFromOIDC()` method
   - Add `refreshRoles()` method
   - Expose `roles$` and `groups$` observables

2. **`src/app/auth/login.component.ts`**:
   - Show provider buttons (Google, Okta, Entra)
   - Handle provider selection
   - Call `authService.signInWithProvider()`

### Phase 2 Output

✅ Frontend can:
- Show multiple sign-in options
- Sign in with Google (existing)
- Sign in with Okta/Entra (new)
- Call `/api/auth/sync-roles` after OIDC signin
- Display user's roles and groups
- Refresh roles on demand

---

## Phase 3: Testing (Week 3, 25 hours)

### Unit Tests

```python
# test_group_role_mapper.py
test_okta_admin_group()
test_entra_design_team()
test_multiple_groups()
test_unknown_group_defaults_to_user()
test_custom_mapping()
```

### Integration Tests

```python
# test_sync_roles_endpoint.py
test_sync_roles_with_okta()
test_sync_roles_with_entra()
test_sync_roles_with_keycloak()
test_sync_roles_failure_fallback()
```

### E2E Tests

- [ ] Sign in with Google → works
- [ ] Sign in with Okta → roles appear
- [ ] Sign in with Entra → groups appear
- [ ] Change group in OIDC → refresh gets new roles
- [ ] OIDC provider down → fallback to cached roles

---

## Phase 4: Deployment (Week 4, 15 hours)

### Pre-Deployment

- [ ] Security review complete
- [ ] All tests passing
- [ ] Staging deployment successful
- [ ] Monitoring alerts configured

### Canary Rollout

1. **Day 1-2**: Deploy to 10% of users (canary)
   - Monitor auth failure rate
   - Check role sync success rate
   - Verify no performance degradation

2. **Day 3-4**: Roll to 50% of users
   - Verify same metrics
   - Gather feedback from beta users

3. **Day 5+**: Full rollout to 100%
   - Continue monitoring
   - Support for any issues

---

## What Changes for Users

### Before
- ✅ Sign in with Google
- ❌ No SSO for enterprise directories
- ❌ Roles assigned manually by admin

### After
- ✅ Sign in with Google (unchanged)
- ✅ Sign in with Okta (NEW)
- ✅ Sign in with Entra ID (NEW)
- ✅ Roles auto-synced from directory (NEW)
- ✅ Groups visible in app (NEW)

**User Experience**: Click their preferred sign-in method, auto-provisioned

---

## What Changes for Developers

### New Code Locations

```
Backend:
  src/auth/oidc_service.py           ← New
  src/auth/group_role_mapper.py      ← New
  src/routes/auth_controller.py      ← Modified (add endpoint)
  tests/test_oidc_service.py         ← New
  tests/test_group_role_mapper.py    ← New

Frontend:
  src/app/common/services/auth.service.ts     ← Modified
  src/app/auth/login.component.*              ← Modified
```

### New Concepts

- OIDC Discovery (standard, but new to team)
- Group-to-Role Mapping (configuration-driven)
- Federated Identity (Firebase with OIDC)

---

## Configuration: Group-to-Role Mapping

### Example Setup

**Environment Variable or Config File**:
```python
GROUP_ROLE_MAPPINGS = {
    # Okta
    'okta_admins': ['admin'],
    'okta_creators': ['creator'],
    'okta_users': ['user'],

    # Azure Entra ID
    'entra_admins': ['admin'],
    'entra_design_team': ['creator'],

    # Generic
    'admins': ['admin'],
    'designers': ['creator'],
}
```

### Admin Tasks

**First Time**:
1. Get list of groups in OIDC provider (e.g., Okta)
2. Decide which Creative Studio role each group should map to
3. Add mapping to config

**Ongoing**:
- New group created in OIDC → Add mapping in config
- Group renamed → Update mapping

---

## Common Questions

### Q: Will Google Sign-In still work?

**A**: Yes! 100% backward compatible. Google users see "Sign in with Google" button.

### Q: What if OIDC provider is down?

**A**: User can:
1. Fall back to Google Sign-In (if they have Google account)
2. Use cached roles from previous login (Firestore)

### Q: Who manages group memberships?

**A**: OIDC provider admins (Okta/Entra admins), not Creative Studio admins.

### Q: How often are roles refreshed?

**A**:
- **On Login**: Always sync groups from OIDC provider
- **Optional**: Scheduled background job (hourly/daily) to refresh all users

### Q: What if a user's group changes?

**A**:
- Changes appear automatically next time they sign in
- Admins can manually trigger `/api/auth/refresh-roles` endpoint

### Q: Does this work with Keycloak (self-hosted)?

**A**: Yes! Keycloak is fully OIDC-compliant, same as Okta/Entra.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────┐
│         Sign In Page (Frontend)             │
│                                             │
│  [Google] [Okta] [Entra] [Keycloak]       │
└────────────────┬────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
┌───────────────┐  ┌──────────────────┐
│ Google OAuth  │  │ OIDC Provider    │
│               │  │ (Okta/Entra/KC)  │
└───────┬───────┘  └────────┬─────────┘
        │                   │
        └────────┬──────────┘
                 ▼
        ┌──────────────────┐
        │ Firebase Auth    │
        │ (Unified Auth)   │
        └────────┬─────────┘
                 │
        ┌────────▼──────────┐
        │ Backend Service   │
        │                   │
        │ 1. Get groups     │ ← Okta/Entra
        │ 2. Map to roles   │
        │ 3. Set in Firebase│
        │ 4. Store in DB    │
        └────────┬──────────┘
                 │
        ┌────────▼──────────┐
        │ Firebase Rules    │
        │ + Firestore DB    │
        └───────────────────┘
```

---

## Success Criteria

### After Implementation

✅ **Users can sign in with**:
- Google (existing)
- Okta (new)
- Azure Entra ID (new)
- (Optional) Keycloak (new)

✅ **Roles automatically synced**:
- From Okta groups to Creative Studio roles
- From Entra ID groups to Creative Studio roles
- Updated on every login

✅ **No breaking changes**:
- Existing Google users unaffected
- Current roles system preserved
- Firestore queries unchanged

✅ **Monitoring in place**:
- Auth success rate: >99.5%
- Role sync latency: <500ms
- Alerts on failures

---

## Next Steps

### This Week

1. **Review this document** (10 min read)
2. **Review Architecture Comparison** (30 min read)
   - File: `01_AUTHENTICATION_COMPARISON.md`
3. **Get approval** from architecture team
4. **Get OIDC credentials** from provider

### Next Week

5. **Start backend implementation** (Phase 1)
   - Follow: `02_FIREBASE_OIDC_IMPLEMENTATION_GUIDE.md`
   - Start with OIDC service

### Weeks 2-4

6. **Frontend + Testing + Deployment**

---

## Files to Read

| Document | Time | For Whom | Contains |
|----------|------|----------|----------|
| **This** | 10 min | Everyone | Overview & decision |
| `01_AUTHENTICATION_COMPARISON.md` | 45 min | Architects | Full comparison |
| `02_FIREBASE_OIDC_IMPLEMENTATION_GUIDE.md` | 90 min | Developers | Step-by-step code |
| `README.md` | 30 min | Leads | Project overview |

---

## Support

### Questions?

- **Technical**: See Phase-specific guides
- **Architecture**: See Comparison document
- **Implementation**: See Implementation Guide

### Getting Help

1. Check the relevant guide
2. Search for your question in troubleshooting sections
3. Ask in team Slack #authentication channel

---

**Ready to proceed?** Start with reading `01_AUTHENTICATION_COMPARISON.md`.
