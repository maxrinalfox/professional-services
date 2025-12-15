# Auto-Provisioning Security & Cost Analysis
## Critical Review and Solutions

**Document Version**: 1.0
**Date**: December 15, 2025
**Status**: Critical Issue Identified
**Severity**: 🔴 HIGH - Security Risk + Cost Control Issue

---

## Executive Summary

Creative Studio currently implements **Just-In-Time (JIT) Auto-Provisioning** that automatically grants **USER role** and associated permissions to **ANY user with a valid Google OAuth token**. This creates two critical problems:

### Problem 1: Cost Control Risk ⚠️
- **Auto-provisioned USER role** can create images, videos, and audio
- **Each generation calls Vertex AI APIs** (Imagen, Veo, Chirp)
- **Vertex AI is pay-per-use** (can cost $0.01 - $2.00+ per generation)
- **No resource quotas or spending limits** configured
- **Potential for runaway costs** if user generates bulk content

### Problem 2: Security Risk 🔐
- **No approval process** for user access
- **Anyone with Google account gains immediate access**
- **Auto-assigned permissions cannot be revoked without deleting user**
- **No audit trail** for who provisioned users
- **Difficult to restrict to specific organizations** if not configured

---

## Current Architecture

### How Auto-Provisioning Works Today

```
1. User tries to access API with Google OAuth token
                    ↓
2. get_current_user() dependency called (auth_guard.py:42)
                    ↓
3. Token verified by Firebase/Google OIDC
                    ↓
4. create_user_if_not_exists() called (user_service.py:35)
                    ↓
5. User NOT in database?
   YES → Create new user with:
         • roles = ["user"]
         • name & picture from OAuth token
   NO  → Return existing user
                    ↓
6. USER ROLE GRANTED IMMEDIATELY
   ✅ Can generate images, videos, audio
   ✅ Can upload source assets
   ✅ Can access public workspaces
   ✅ Can use templates
```

### Code Location

**File**: `backend/src/auth/auth_guard.py` (Line 97-101)

```python
# Just-In-Time (JIT) User Provisioning:
# Create a user profile in our database on their first API call.
user_doc = await user_service.create_user_if_not_exists(
    email=email, name=name, picture=picture
)
```

**Service**: `backend/src/users/user_service.py` (Line 35-65)

```python
async def create_user_if_not_exists(
    self, email: str, name: str, picture: Optional[str]
) -> UserModel:
    # Check if exists
    existing_user = await self.user_repo.get_by_email(email)
    if existing_user:
        return existing_user

    # Create with USER role
    user_data["roles"] = [UserRoleEnum.USER]
    return await self.user_repo.create(user_data)
```

---

## Cost Impact Analysis

### Worst-Case Scenario

**Assumptions**:
- Attacker or test user gains access
- Generates 100 images per day
- Each image generation costs ~$0.02

**Monthly Cost**:
```
100 images/day × 30 days × $0.02/image = $60/month per user

If 10 bad actors:
10 users × $60 = $600/month (unbudgeted)

If 100 scenarios:
100 × $60 = $6,000/month (significant cost)
```

### Video Generation (Higher Cost)

**Assumptions**:
- Veo API: ~$2.00 per generation (more expensive than images)
- Only 10 generations per day due to longer processing

**Monthly Cost**:
```
10 videos/day × 30 days × $2.00/video = $600/month per user

If 5 bad actors:
5 users × $600 = $3,000/month
```

### Cumulative Risk

**Real Scenario**: Compromised OAuth token or rogue testing

```
Month 1: $0 (nobody knows about it)
Month 2: $5,000 (someone starts testing)
Month 3: $15,000 (multiple users testing features)
Month 4: $50,000+ (unchecked growth)
```

---

## Security Impact Analysis

### Current Vulnerabilities

#### 1. Open Access
**Risk**: Anyone with valid Google account can access
**Impact**: No control over who uses the system

```
Scenario:
- Startup shares API URL in GitHub
- Gets accidentally public
- Anyone can call API
- AUTO-PROVISIONED with USER role
- Immediately can generate content
```

**Mitigation**: ALLOWED_ORGS exists but not enforced by default

---

#### 2. No Approval Workflow
**Risk**: Users created without administrative review

```
Current Flow:
1. User logs in
2. User created in DB
3. User has permissions
(All automatic, no approval)

Better Flow:
1. User logs in
2. User created but DISABLED
3. Admin approves
4. User gains permissions
```

**Current Code**: No approval mechanism exists

---

#### 3. Permission Escalation
**Risk**: USER role permissions can't be easily revoked

**Scenario**:
```
1. User provisioned with USER role
2. Later needs to be restricted
3. Only option: delete user entirely
4. User data (media, workspaces) deleted too
```

**Better Approach**: Disable user without deleting

---

#### 4. Audit Trail Gap
**Risk**: No logging of auto-provisioning events

**Missing**:
- Who was auto-provisioned
- When they were provisioned
- From which IP/location
- How many API calls they made

---

## Solution Options

### Option 1: Disable Auto-Provisioning (Recommended) ⭐⭐⭐⭐⭐

**Approach**: Require manual user creation by admins

**Implementation**:
```python
# In auth_guard.py, INSTEAD of auto-creating:
user_doc = await user_service.create_user_if_not_exists(...)

# DO THIS:
user_doc = await user_service.get_user_by_email(email)

if not user_doc:
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="User account not found. Contact administrator for access."
    )

return user_doc
```

**Pros**:
- ✅ Complete control over who gets access
- ✅ Prevents accidental exposure
- ✅ No runaway costs
- ✅ Clear audit trail
- ✅ Easy to implement (2 lines changed)

**Cons**:
- ❌ Requires admin to manually create users
- ❌ Workflow change for onboarding
- ❌ More operational overhead

**Timeline**: Immediate (2-hour change)
**Cost**: Low (minimal development)
**Effort**: Low (change 2 lines + add API endpoint)

---

### Option 2: Auto-Provision with Disabled Role ⭐⭐⭐⭐

**Approach**: Auto-create users but with NO permissions by default

**Implementation**:

```python
# Add new role to system
class UserRoleEnum(str, Enum):
    DISABLED = "disabled"  # NEW
    USER = "user"
    CREATOR = "creator"
    ADMIN = "admin"

# In user_service.py, change default:
# BEFORE:
user_data["roles"] = [UserRoleEnum.USER]

# AFTER:
user_data["roles"] = [UserRoleEnum.DISABLED]
```

**Admin API Endpoint**:
```python
@router.post("/api/admin/users/{user_id}/enable")
async def enable_user(
    user_id: int,
    current_user: UserModel = Depends(
        RoleChecker([UserRoleEnum.ADMIN])
    ),
):
    """Enable a disabled user, granting USER role"""
    return await user_service.update_user_role(
        user_id,
        UserUpdateRoleDto(roles=[UserRoleEnum.USER])
    )
```

**Permission Check**:
```python
# In all protected endpoints:
if UserRoleEnum.DISABLED in user.roles:
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Your account is pending approval."
    )
```

**Pros**:
- ✅ Maintains JIT convenience
- ✅ Users see error (not 404)
- ✅ Admin can easily enable/disable
- ✅ No data deletion needed
- ✅ Good audit trail

**Cons**:
- ❌ Still creates database entries for everyone
- ❌ More complex (adds DISABLED role)
- ❌ Admin must actively enable users

**Timeline**: 4-6 hours
**Cost**: Low-Medium
**Effort**: Medium

---

### Option 3: Resource Quotas & Rate Limiting ⭐⭐⭐

**Approach**: Keep auto-provisioning but limit what each role can do

**Implementation**:

```python
# Add quotas to roles
class UserQuota:
    USER = {
        "monthly_images": 100,
        "monthly_videos": 10,
        "monthly_api_calls": 1000,
        "daily_cost_limit": $10.00,
    }
    CREATOR = {
        "monthly_images": 1000,
        "monthly_videos": 100,
        "monthly_api_calls": 10000,
        "daily_cost_limit": $50.00,
    }
    ADMIN = {
        "monthly_images": None,  # Unlimited
        "monthly_videos": None,
        "monthly_api_calls": None,
        "daily_cost_limit": None,
    }
```

**Enforcement**:
```python
@router.post("/api/images/generate-images")
async def generate_images(
    image_request: CreateImagenDto,
    current_user: UserModel = Depends(get_current_user),
):
    # Check quota
    usage = await quota_service.get_user_usage(current_user.id)
    quota = get_quota_for_role(current_user.roles)

    if usage.images >= quota["monthly_images"]:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Monthly image limit ({quota['monthly_images']}) reached"
        )
```

**Pros**:
- ✅ Limits runaway costs
- ✅ Keeps auto-provisioning convenience
- ✅ Fair resource distribution
- ✅ Good for multi-tenant

**Cons**:
- ❌ Still allows access to unauthorized users
- ❌ More complex implementation
- ❌ Harder to change quotas mid-month
- ❌ Doesn't solve security issue

**Timeline**: 8-12 hours
**Cost**: Medium
**Effort**: Hard

---

### Option 4: Whitelist-Based Access ⭐⭐⭐⭐

**Approach**: Only allow specific email domains/users

**Implementation**:

```python
# Add to config
class ConfigService:
    ALLOWED_EMAILS = set([
        "alice@company.com",
        "bob@company.com",
        "charlie@company.com",
    ])

    ALLOWED_DOMAINS = set([
        "company.com",
        "partner.com",
    ])
```

**In auth_guard.py**:
```python
email = decoded_token.get("email")

# Check email whitelist
if not (email in config_service.ALLOWED_EMAILS
        or any(email.endswith(f"@{domain}")
               for domain in config_service.ALLOWED_DOMAINS)):
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Your email is not authorized to access this application."
    )

# THEN do auto-provisioning
user_doc = await user_service.create_user_if_not_exists(...)
```

**Pros**:
- ✅ Simple to implement
- ✅ Only authorized organizations/emails
- ✅ Keeps auto-provisioning convenience
- ✅ Can be changed in environment variables

**Cons**:
- ❌ Still auto-provisions with USER role
- ❌ Still has cost/permission issues
- ❌ Only solves security partially

**Timeline**: 2-3 hours
**Cost**: Low
**Effort**: Low

---

## Recommended Solution: Hybrid Approach 🎯

**Combine Options 1 + 4 + 3**

### Phase 1 (Immediate): Disable Auto-Provisioning
```python
# auth_guard.py
user_doc = await user_service.get_user_by_email(email)
if not user_doc:
    raise HTTPException(403, "User not found. Contact admin.")
```

**Benefits**:
- ✅ Closes security gap immediately
- ✅ Prevents cost runaway
- ✅ Takes 2 hours to implement
- ✅ No breaking changes needed

---

### Phase 2 (Short-term): Add Whitelist
```python
# Allow specific domains to auto-provision with DISABLED role
if email_domain in ALLOWED_DOMAINS:
    auto_provision_with_disabled_role()
else:
    raise HTTPException(403, "Domain not allowed")
```

**Benefits**:
- ✅ Convenience for internal users
- ✅ Safe (disabled role until approved)
- ✅ Better UX

---

### Phase 3 (Medium-term): Add Quotas
```python
# Implement usage tracking and quotas
enforce_monthly_quotas()
enforce_daily_spending_limits()
```

**Benefits**:
- ✅ Cost control
- ✅ Resource fairness
- ✅ Early warning system

---

### Phase 4 (Long-term): Add Approval Workflow
```python
# Admin dashboard to approve new users
# Email notifications
# User status tracking
```

**Benefits**:
- ✅ Enterprise-ready
- ✅ Clear audit trail
- ✅ Fine-grained control

---

## Implementation Plan: Phase 1

### Files to Change

**1. `backend/src/auth/auth_guard.py`** (Lines 97-101)

```python
# BEFORE:
user_doc = await user_service.create_user_if_not_exists(
    email=email, name=name, picture=picture
)

if not user_doc:
    raise HTTPException(...)

# AFTER:
user_doc = await user_service.get_user_by_email(email)

if not user_doc:
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="User account does not exist. Please contact your administrator for access.",
    )

# If user exists, update picture if needed
if user_doc and not user_doc.picture:
    user_doc.picture = picture
    if user_doc.id:
        await user_service.user_repo.update(user_doc.id, {"picture": picture})
```

**2. Add User Creation Endpoint** (`backend/src/users/user_controller.py`)

```python
@router.post("/api/admin/users", dependencies=[admin_only])
async def create_user(
    create_request: UserCreateDto,
    user_service: UserService = Depends(),
    current_user: UserModel = Depends(get_current_user),
):
    """
    Create a new user manually. Admin only.
    This replaces auto-provisioning.
    """
    # Check if user already exists
    existing = await user_service.get_user_by_email(create_request.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"User with email {create_request.email} already exists.",
        )

    # Create user with initial role
    user_data = create_request.model_dump()
    user_data["roles"] = create_request.roles or [UserRoleEnum.USER]

    new_user = await user_service.user_repo.create(user_data)

    # Log audit event
    logger.info(
        f"User {create_request.email} created by {current_user.email} "
        f"with roles: {user_data['roles']}"
    )

    return new_user
```

**3. Add Get User by Email** (`backend/src/users/user_service.py`)

```python
async def get_user_by_email(self, email: str) -> Optional[UserModel]:
    """Get user by email without auto-creating"""
    return await self.user_repo.get_by_email(email)
```

---

## Migration Path

### For Existing Users
```
Option A: Keep existing users as-is
Option B: Require re-approval (stronger security)
Option C: Move to DISABLED role until re-approved
```

### For New Users Post-Change
```
1. User tries to login
2. Firebase/Google OIDC verified
3. Check if in user database
4. If NO → HTTP 403 with message
5. User contacts admin
6. Admin creates user in application
7. User gets enabled with appropriate role
8. User can now access
```

### Admin Workflow
```
1. Admin receives user access request
2. Admin verifies identity
3. Admin checks organization/domain
4. Admin creates user via API
5. User gets email notification (TBD)
6. User can now login
```

---

## Configuration Options

### Option A: Strict (Security-First)
```
ENABLE_AUTO_PROVISIONING=false
ALLOWED_ORGS=["company.com"]
DEFAULT_ROLE="disabled"
REQUIRE_APPROVAL=true
```

**For**: Enterprise, Financial, Healthcare

---

### Option B: Balanced (Recommended)
```
ENABLE_AUTO_PROVISIONING=true
AUTO_PROVISION_ROLE="disabled"
ALLOWED_ORGS=["company.com", "partner.com"]
ALLOWED_EMAILS=["admin@company.com"]
```

**For**: Most organizations

---

### Option C: Open (Development-Only)
```
ENABLE_AUTO_PROVISIONING=true
AUTO_PROVISION_ROLE="user"
ALLOWED_ORGS=[]
DEFAULT_QUOTA="unlimited"
```

**For**: Development, Testing only

---

## Cost-Benefit Analysis

### Option 1: Disable Auto-Provisioning

| Aspect | Cost | Benefit | Effort |
|--------|------|---------|--------|
| Development | 1 hour | Closes security gap | Low |
| Testing | 2 hours | Prevents cost runaway | Low |
| Deployment | 30 min | Immediate protection | Low |
| **Operational** | **Medium** | **Controls access** | **Medium** |

**ROI**: High (prevents potential $1000s in costs)

---

## Recommended Action Plan

### ✅ IMMEDIATE (This Week)
1. **Decision**: Choose between disable or whitelist + disabled role
2. **Code Change**: Implement Phase 1 (2-3 hours development)
3. **Testing**: Test in dev/staging (4 hours)
4. **Communication**: Inform team of new user creation process

### ✅ SHORT-TERM (Next 2 Weeks)
1. **Documentation**: Write user onboarding guide
2. **Admin Tool**: Create user management dashboard
3. **Monitoring**: Set up alerts for failed authentications
4. **Cleanup**: Review and archive auto-provisioned test accounts

### ✅ MEDIUM-TERM (Next Month)
1. **Quotas**: Implement usage tracking
2. **Approval**: Build formal approval workflow
3. **Notifications**: Add email notifications
4. **Audit**: Create audit log of user activities

---

## Risk Assessment

### If You Do Nothing

**Financial Risk**: 🔴 HIGH
- Potential runaway costs ($1000s-$10000s)
- No spending controls
- Difficult to predict expenses

**Security Risk**: 🔴 HIGH
- Anyone with Google account gains access
- No audit trail
- Difficult to revoke access
- No ability to restrict by organization

**Operational Risk**: 🟡 MEDIUM
- Difficult to manage growing user base
- No approval workflow
- No user lifecycle management

---

### If You Implement Solution

**Financial Risk**: 🟢 LOW
- Spending limits enforced
- Quota system prevents overuse
- Cost predictable

**Security Risk**: 🟢 LOW
- Only approved users get access
- Complete audit trail
- Easy to revoke access
- Organization-based restrictions

**Operational Risk**: 🟢 LOW
- Clear user onboarding process
- Admin controls everything
- Easy to track user lifecycle

---

## Comparison Table

| Aspect | Current | Phase 1 | Phase 3 | Phase 4 |
|--------|---------|---------|---------|---------|
| **Cost Control** | ❌ None | ✅ Access only | ✅✅ Quotas | ✅✅ Full |
| **Security** | ❌ Open | ✅ Controlled | ✅ Good | ✅✅ Enterprise |
| **User Experience** | ✅ Easy | ⚠️ Requires approval | ✅ Good | ✅ Excellent |
| **Operational** | ⚠️ Unmanaged | ✅ Manual | ✅ Managed | ✅✅ Automated |
| **Effort** | - | 2-3 hours | 20 hours | 40 hours |
| **Cost** | - | $100-200 | $500-1000 | $2000+ |

---

## Decision Framework

**Choose Option 1 (Disable Auto-Provisioning) IF:**
- ✅ You want maximum security
- ✅ Cost control is critical
- ✅ You have small user base
- ✅ You can manage manual approvals

**Choose Option 2 (Disabled Role) IF:**
- ✅ You want to enable internal users only
- ✅ You want whitelist + safety
- ✅ You want better UX than Option 1

**Choose Option 4 (Whitelist) IF:**
- ✅ You want simplicity
- ✅ You have defined organization domains
- ✅ You accept some risk

**Choose Hybrid (All options) IF:**
- ✅ You're enterprise
- ✅ You need both security AND convenience
- ✅ You have budget for full solution

---

## Conclusion

**Current auto-provisioning is a significant risk** for both security and cost control. The recommended approach is:

1. **Phase 1 (ASAP)**: Disable auto-provisioning (2-3 hours)
2. **Phase 2 (Soon)**: Add whitelisting (optional for convenience)
3. **Phase 3 (This month)**: Implement quotas (cost control)
4. **Phase 4 (Next month)**: Build approval workflow (enterprise-ready)

**Minimum action**: Implement Phase 1 immediately to close the security/cost gap.

---

**Status**: Ready for implementation
**Approval Required**: Engineering Lead + Finance (due to cost implications)
**Timeline**: Can be deployed within 1 week with proper planning

