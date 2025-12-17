# Known Issues & Blockers

**Status**: Current Issues Affecting Application & Roadmap
**Last Updated**: December 17, 2025
**Priority**: Critical

---

## 🚨 CRITICAL ISSUES (BLOCKING)

These issues prevent enterprise features and must be resolved.

### 1. **Hybrid Broken Authentication System**

**Status**: 🔴 CRITICAL - Blocks all auth roadmap work
**Severity**: BLOCKING
**Affects**: Phase 1, 2, 3 of authentication roadmap

#### The Problem

The application has a **hybrid authentication implementation** that is fundamentally broken:

**Frontend Issues**:
- ❌ Production uses **deprecated `google.accounts.id` API** (Google is phasing this out)
- ❌ Local development uses Firebase SDK (inconsistent with production)
- ❌ Different code paths for local vs production
- ❌ No provider selector UI
- ❌ Hardcoded to Google only
- ❌ Cannot add Okta, SAML, or other OIDC providers

**Backend Issues**:
- ❌ Users created in **PostgreSQL**, NOT Firebase Authentication
- ❌ Firebase Admin SDK only validates tokens, doesn't create users
- ❌ User data split across: PostgreSQL (users), Firestore (metadata)
- ❌ Cannot leverage Firebase provider federation
- ❌ Cannot implement proper OIDC flows

**Architecture Issues**:
- ❌ Firebase SDK imported but its user management features not used
- ❌ No clear single source of truth for user data
- ❌ Cannot migrate to multi-provider without complete rewrite
- ❌ Each provider would require custom code changes

#### Current State (As-Is)

```
User clicks "Sign In"
    ↓
Production: google.accounts.id (deprecated) → Gets token
Local Dev: Firebase SDK → Gets token
    ↓
Token sent to backend
    ↓
Backend verifies token signature with Firebase Admin SDK
    ↓
Extract email from token
    ↓
Query PostgreSQL for user (NOT Firebase Auth!)
    ↓
Create user in PostgreSQL if not found (JIT)
    ↓
Query Firestore for roles/permissions
    ↓
Return response

Issue: Users only in PostgreSQL, cannot add new providers
```

#### Why This Blocks Enterprise Features

1. **Cannot Add Okta**:
   - Okta provides ID tokens, but no user in Firebase Auth
   - Would need to bypass Firebase entirely
   - Would break existing Google-only flow

2. **Cannot Add SAML**:
   - Same issue as Okta

3. **Cannot Implement Proper OAuth 2.0**:
   - Too much Firebase SDK scattered throughout code
   - Would need to remove Firebase entirely

4. **Cannot Use Firebase's Multi-Provider Federation**:
   - Users not in Firebase Authentication directory
   - Provider federation only works with Firebase users

#### Solution

**Choose ONE path (Phase 1)**:
- **Option A**: Fix & Leverage Firebase (3-4 weeks)
  - Create users in Firebase Authentication
  - Use Firebase provider federation
  - More Google-dependent

- **Option B**: Replace with Pure OAuth 2.0 OIDC (3-5 weeks)
  - Remove Firebase SDK from frontend
  - Implement standard OIDC flow
  - Users in PostgreSQL (single source of truth)
  - Works with any provider

**See**: `docs/roadmap/okta_auth/06_PHASE1_TWO_ALTERNATIVES.md`

---

### 2. **API Endpoint Error Responses**

**Status**: 🟡 MEDIUM - Inconsistent error handling
**Severity**: Important
**Affects**: API reliability, debugging

#### The Problem

- ❌ Some endpoints return 500 on invalid input (should be 400)
- ❌ Error messages inconsistent across endpoints
- ❌ Some endpoints expose internal error details
- ❌ Missing validation for required fields
- ❌ Pydantic models not enforcing all constraints

#### Impact

- Harder to debug client-side errors
- Inconsistent API behavior
- Security concern (exposing internals)
- Poor developer experience

#### Solution

- Add comprehensive request validation
- Standardize error response format
- Document expected errors per endpoint
- Add pre-request validation in Pydantic models

---

### 3. **Data Consistency Across User Storage**

**Status**: 🟡 MEDIUM - Data split across services
**Severity**: Important (related to auth issue)
**Affects**: User management, data integrity

#### The Problem

User data is split across THREE systems with no single source of truth:

```
User Data Stored In:
├─ PostgreSQL (users table)
│  └─ email, roles[], name, picture
│
├─ Firestore (user collection)
│  └─ workspace permissions, user roles, metadata
│
└─ NOT in Firebase Authentication (should be here?)
   └─ (unused)
```

#### Issues This Causes

- ❌ User role updates must be done in two places
- ❌ Deleting user requires deleting from PostgreSQL + Firestore
- ❌ No consistency guarantee across systems
- ❌ Workspace membership updates complex
- ❌ If PostgreSQL/Firestore get out of sync, undefined behavior

#### Example Problem Scenario

```
1. User added to workspace
2. Update PostgreSQL workspace_members table ✓
3. Update Firestore user roles ✗ (Fails)
→ User can now see workspace data but permissions are wrong
```

#### Solution

- Define single source of truth
- Synchronize writes across both databases
- Implement transactional updates where possible
- Document sync strategy

---

## ⚠️ HIGH PRIORITY ISSUES

### 4. **Frontend Component Performance**

**Status**: 🟡 MEDIUM - Potential memory leaks
**Severity**: Important
**Affects**: User experience

#### The Problem

- ⚠️ Some components may not unsubscribe from RxJS observables
- ⚠️ Large lists (media gallery) not virtualized
- ⚠️ Image loading not optimized (no lazy loading)
- ⚠️ Firestore listeners may not be cleaned up on component destroy

#### Impact

- Memory usage increases over time
- Slow performance on large media collections
- Battery drain on mobile devices
- Increased bandwidth usage

#### Solution

- Audit RxJS subscriptions (use `takeUntil` or `async` pipe)
- Implement virtual scrolling for galleries
- Add image lazy loading + compression
- Unsubscribe from Firestore listeners on destroy

---

### 5. **Backend Database Query Performance**

**Status**: 🟡 MEDIUM - Missing indexes
**Severity**: Important
**Affects**: Response times

#### The Problem

- ⚠️ No composite indexes on common query patterns
- ⚠️ Workspace queries might be N+1 (fetching members individually)
- ⚠️ Media item queries not optimized for filtering
- ⚠️ Firestore queries not optimized for common paths

#### Impact

- Slow API responses for large workspaces
- High database load
- Poor user experience at scale
- Increased cost (Firestore billing)

#### Solution

- Add missing database indexes
- Optimize SQLAlchemy queries (joins, select specific columns)
- Add query result caching
- Profile Firestore queries

---

### 6. **Error Handling in Video Processing**

**Status**: 🟡 MEDIUM - Limited retry logic
**Severity**: Important
**Affects**: Video generation reliability

#### The Problem

- ⚠️ Video processing errors not properly retried
- ⚠️ No exponential backoff strategy
- ⚠️ Failed videos don't notify user properly
- ⚠️ No webhook support for async job completion

#### Impact

- Users think video generation just "hung"
- No clear error feedback
- Unreliable async operations
- Poor visibility into long-running tasks

#### Solution

- Implement retry logic with exponential backoff
- Add job status webhooks
- Clear error notifications to frontend
- Timeout handling for long-running operations

---

## 📋 MEDIUM PRIORITY ISSUES

### 7. **Firestore Security Rules Gaps**

**Status**: 🟡 MEDIUM - Potential authorization issues
**Severity**: Important
**Affects**: Data security

#### The Problem

- ⚠️ Some Firestore rules may allow unintended access
- ⚠️ Rate limiting may not be enforced
- ⚠️ Batch operations not restricted
- ⚠️ No audit logging of Firestore writes

#### Solution

- Comprehensive security rule audit
- Add rate limiting rules
- Enable Firestore audit logging
- Test rules in dev environment

---

### 8. **Missing Environment Variable Documentation**

**Status**: 🟡 MEDIUM - Configuration issues
**Severity**: Important
**Affects**: Onboarding, deployment

#### The Problem

- ⚠️ Not all environment variables documented
- ⚠️ Default values not specified
- ⚠️ Optional vs required flags unclear
- ⚠️ Example .env.template might be out of date

#### Solution

- Maintain updated `.env.template` with all variables
- Document default values
- Specify required vs optional
- Add validation for required vars at startup

---

## 🔵 LOW PRIORITY ISSUES

### 9. **Documentation Inconsistencies**

**Status**: 🟢 LOW - Being fixed
**Severity**: Minor
**Affects**: Developer experience

#### Issues Fixed (December 17, 2025)

- ✅ Authentication documentation was inaccurate (now corrected)
- ✅ Missing E2E testing guide references (added)
- ✅ Roadmap structure confusing (reorganized)
- ✅ Firebase authentication claims misleading (corrected)

#### Remaining Issues

- ⚠️ API documentation could have more examples
- ⚠️ Some architecture diagrams outdated
- ⚠️ Database schema documentation needs refresh
- ⚠️ Deployment guide missing some steps

#### Solution

- Ongoing documentation updates
- Regular reviews with implementation
- Automated checks for broken links

---

### 10. **Logging Could Be More Structured**

**Status**: 🟢 LOW - Nice-to-have
**Severity**: Minor
**Affects**: Operations, debugging

#### The Problem

- ⚠️ Logs not all in structured JSON format
- ⚠️ Inconsistent field naming across logs
- ⚠️ Hard to filter by context/user/workspace

#### Solution

- Standardize logging format
- Add context propagation
- Use structured logging library

---

## 🔗 Related Documentation

### For Critical Issues (Authentication)
- **See**: `docs/roadmap/okta_auth/06_PHASE1_TWO_ALTERNATIVES.md`
- **See**: `docs/roadmap/okta_auth/03_CURRENT_AUTHENTICATION_ISSUES.md`
- **See**: `docs/03-backend/03_AUTHENTICATION_FLOW.md`

### For Architecture Issues
- **See**: `docs/02-architecture/01_SYSTEM_DESIGN.md`
- **See**: `docs/roadmap/IMPLEMENTATION_STRATEGY_MASTER_INDEX.md`

### For API Issues
- **See**: `docs/03-backend/02_API_ENDPOINTS_REFERENCE.md`

### For Performance Issues
- **See**: `docs/07-operations/01_LOGGING_AND_DEBUGGING.md`
- **See**: `docs/07-operations/02_MONITORING_AND_ALERTS.md`

---

## 📊 Issue Priority Matrix

| Issue | Severity | Effort | Impact | Priority | Roadmap |
|-------|----------|--------|--------|----------|---------|
| Hybrid Authentication | Critical | 3-5 weeks | Complete blocker | 🔴 P0 | Phase 1 |
| Data Consistency | High | 2 weeks | Data integrity | 🟠 P1 | Phase 1 |
| API Error Responses | Medium | 1 week | Developer experience | 🟡 P2 | - |
| Query Performance | Medium | 2 weeks | Scalability | 🟡 P2 | - |
| Video Processing | Medium | 1 week | Reliability | 🟡 P2 | - |
| Firestore Security | Medium | 1 week | Security | 🟡 P2 | - |
| Component Performance | Medium | 2 weeks | UX | 🟡 P2 | - |
| Documentation | Low | Ongoing | Onboarding | 🟢 P3 | - |

---

## 🛠️ Working Around Issues

### Temporary Workaround #1: Adding a New OIDC Provider

**Current State**: Cannot easily add Okta/SAML/custom OIDC

**Temporary Workaround**:
1. Fork authentication flow
2. Add provider-specific logic in backend
3. Would require multiple code changes
4. Not maintainable long-term

**Proper Solution**: Complete Phase 1 refactoring

---

### Temporary Workaround #2: User Provisioning & Access Control

**Current State**:
- External application = any Google user can login (no control)
- Internal application = manually add up to 100 users in GCP (operational burden)

**Better Temporary Approach: Use Identity-Aware Proxy (IAP)**:

1. Keep application external (allow any Google user to sign in)
2. Deploy backend on Cloud Run with IAP enabled
3. Add users to IAM groups (managed by identity team, not application)
4. Only users in authorized IAM group can reach backend
5. Application user provisioning still happens, but infrastructure controls access

**Advantages**:
- ✅ No manual user limit (100+ users supported)
- ✅ Scales with company directory
- ✅ Delegated to identity/security team
- ✅ Infrastructure-layer control (more robust)
- ✅ Works with both Firebase and Pure OIDC approaches

**Implementation**:
- Enable IAP in Terraform (see secondary app: `/vertex-ai-creative-studio/main.tf`)
- Create IAM groups in Cloud Identity
- Grant group members `roles/iap.httpsResourceAccessor` role

**See**: `docs/roadmap/okta_auth/07_IAP_AUTHORIZATION_LAYER.md` for complete details including Terraform configuration

---

## 🚀 Action Items

### Immediate (This Month)
- [ ] Make architectural decision: Firebase vs Pure OIDC (Phase 1)
- [ ] Plan Phase 1 implementation tickets
- [ ] Document specific Firestore security rule gaps
- [ ] Update .env.template with all variables

### Near-Term (Next Month)
- [ ] Complete Phase 1 authentication refactoring
- [ ] Fix API error handling
- [ ] Optimize database queries
- [ ] Add proper retry logic for video processing

### Medium-Term (Q2)
- [ ] Implement Phase 2 (OIDC + groups)
- [ ] Audit and fix component performance
- [ ] Comprehensive security review
- [ ] Load testing and performance tuning

### Long-Term (Q3+)
- [ ] Implement Phase 3 (auto-provisioning)
- [ ] Structured logging upgrade
- [ ] Advanced analytics and monitoring

---

## 📞 Getting Help

- **Authentication Issues**: See `docs/roadmap/okta_auth/`
- **API Issues**: See `docs/03-backend/02_API_ENDPOINTS_REFERENCE.md`
- **Architecture**: See `docs/02-architecture/`
- **Performance**: See `docs/07-operations/02_MONITORING_AND_ALERTS.md`
- **Troubleshooting**: See `docs/07-operations/03_TROUBLESHOOTING_GUIDE.md`

---

**Last Reviewed**: December 17, 2025
**Next Review**: January 31, 2026 (or when Phase 1 starts)
