# Okta Integration - Quick Reference

**Status**: Future Implementation Plan
**Document**: See `01_INTEGRATION_OVERVIEW.md` for full details
**Approval Required**: Yes - Before proceeding with implementation

---

## At a Glance

| Question | Answer |
|----------|--------|
| **Current Auth** | Google Identity Platform + Firebase Auth |
| **Planned Auth** | Okta (Complete replacement) |
| **Frontend Impact** | ✅ YES - auth.service.ts rewrite |
| **Backend Impact** | ✅ YES - Token validation logic change |
| **Database Changes** | ❌ NO - User structure stays the same |
| **Secrets Location** | Google Secret Manager (never in code) |
| **Timeline** | 2-4 weeks (setup, implementation, testing) |
| **Risk Level** | Low (staged rollout, rollback plan available) |

---

## Key Answers

### 1. Can We Do This Through Firebase?

**Option A (Recommended)**: Replace completely with Okta
- ✅ Cleaner, simpler architecture
- ✅ Single auth provider
- ✅ Okta handles token refresh automatically
- ⚠️ Full rewrite of auth service required

**Option B (Not Recommended)**: Use Firebase as layer for Okta
- ❌ Added complexity
- ❌ Extra latency
- ❌ Still depends on Firebase
- ❌ Higher costs

**RECOMMENDATION**: Option A - Complete Okta replacement

### 2. What Changes on Frontend vs Backend?

#### Frontend (Angular)
```
NOW:  Google/Firebase → Angular Service → API
THEN: Okta → OAuth2 PKCE → Angular Service → API
```

Changes needed:
- Replace `GoogleAuthProvider` with Okta SDK
- Rewrite `auth.service.ts`
- Update `auth.interceptor.ts` for Okta tokens
- Update login/logout flows
- Add redirect callback handler

#### Backend (FastAPI)
```
NOW:  Receives JWT → Validate with Google/Firebase → Extract claims
THEN: Receives JWT → Validate with Okta JWKS → Extract claims
```

Changes needed:
- Replace Google token validation with Okta JWT validation
- Fetch and cache Okta public keys (JWKS)
- Keep JIT user provisioning logic
- Update token claim extraction

### 3. Where Do We Store Client ID and Client Secret?

**NEVER:**
- ❌ In code
- ❌ In .env files
- ❌ In git repositories
- ❌ In environment.ts

**WHERE:**
- ✅ Google Secret Manager
- ✅ Loaded via environment variables at runtime
- ✅ Accessed by Cloud Run service account

**Setup:**
```bash
# Create secrets
gcloud secrets create okta-client-id --replication-policy="automatic"
gcloud secrets create okta-client-secret --replication-policy="automatic"
gcloud secrets create okta-domain --replication-policy="automatic"

# Grant access to Cloud Run service account
gcloud secrets add-iam-policy-binding okta-client-id \
  --member=serviceAccount:cs-prod-run@PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor
```

---

## Implementation Phases

### Phase 1: Okta Setup (1-2 days)
- Create Okta organization
- Configure SPA application
- Retrieve credentials (Client ID, Domain, etc.)
- Create Authorization Server
- Add secrets to Google Secret Manager

### Phase 2: Frontend Implementation (3-4 days)
- Install Okta SDK: `@okta/okta-angular`
- Update environment files
- Rewrite `auth.service.ts`
- Update `auth.interceptor.ts`
- Create login/callback component
- Update route guards

### Phase 3: Backend Implementation (2-3 days)
- Install JWT validation library: `okta-jwt-verifier`
- Update config service
- Create `okta_validator.py`
- Rewrite `auth_guard.py`
- Configure CORS for Okta

### Phase 4: Testing (1-2 weeks)
- Unit tests (Frontend & Backend)
- Integration tests
- E2E tests
- Manual testing checklist

### Phase 5: Migration (1-2 weeks)
- Stage 1: Parallel running (feature flag)
- Stage 2: Gradual rollout (10% → 50% → 100%)
- Stage 3: Complete migration
- Stage 4: Cleanup old code

---

## Security Checklist

- [ ] Okta Client Secret stored in Google Secret Manager
- [ ] Service account has permission to access secrets
- [ ] Okta token signature validated against JWKS
- [ ] Issuer verified (`https://your-org.okta.com/oauth2/default`)
- [ ] Audience verified (matches Client ID)
- [ ] Token expiration checked
- [ ] CORS configured for Okta redirects
- [ ] Redirect URIs whitelisted in Okta
- [ ] JIT user provisioning validates email format
- [ ] All user creation attempts logged

---

## Monitoring Points

### Frontend
- Sign-in success/failure rate
- Token refresh frequency
- CORS errors
- User profile sync failures

### Backend
- Token validation success/failure rate
- User provisioning latency
- JWKS fetch latency
- Invalid token attempts (potential attacks)

---

## Rollback Plan

If issues arise during migration:

1. **Feature Flag**: Quickly switch back to old auth provider
2. **Git Revert**: Easy to revert commits and redeploy
3. **Database**: No schema changes, no data migration needed
4. **Users**: May need to log in again with old provider

---

## Timeline Summary

```
Start Planning
    ↓
Phase 1: Setup (2 days)
    ↓
Phase 2: Frontend (4 days)
    ↓
Phase 3: Backend (3 days)
    ↓
Phase 4: Testing (2 weeks)
    ↓
Phase 5: Gradual Rollout (2 weeks)
    ↓
Complete Migration
```

**Total**: 2-4 weeks depending on testing thoroughness

---

## FAQ

**Q: Do existing users need to re-login?**
A: Yes, they'll need to log in again with Okta.

**Q: What if Okta is down?**
A: Users can't log in. Okta has 99.99% SLA.

**Q: Do we need to change how we store roles?**
A: No, we can keep roles in Firestore (current approach) or add to Okta claims.

**Q: Can we use Okta for multi-factor authentication?**
A: Yes, Okta supports MFA out of the box.

**Q: How often are Okta tokens refreshed?**
A: Default is 1 hour. Okta SDK handles automatic refresh.

---

## Next Steps

1. ✅ Review this quick reference
2. ⏭️ Read full roadmap: `01_INTEGRATION_OVERVIEW.md`
3. ⏭️ Get stakeholder approval
4. ⏭️ Create Jira epics for each phase
5. ⏭️ Schedule Phase 1 kickoff

---

**For detailed implementation steps, configuration examples, and code snippets, see `OKTA_INTEGRATION_ROADMAP.md`**
