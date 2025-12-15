# Implementation Guide: Disable Auto-Provisioning
## Step-by-Step Guide to Secure User Access

**Document Version**: 1.0
**Date**: December 15, 2025
**Duration**: 3-4 hours implementation + testing
**Complexity**: Low
**Files Modified**: 2

---

## Overview

This guide walks you through disabling Just-In-Time (JIT) auto-provisioning and implementing manual user creation via admin API.

**Result**: Only users explicitly created by administrators can access the system.

---

## Prerequisites

- Backend codebase access
- FastAPI understanding
- Database access for testing
- 3-4 hours of development time

---

## Step 1: Update Authentication Guard

### File: `backend/src/auth/auth_guard.py`

**Location**: Lines 97-128

**Current Code**:
```python
# Just-In-Time (JIT) User Provisioning:
# Create a user profile in our database on their first API call.
user_doc = await user_service.create_user_if_not_exists(
    email=email, name=name, picture=picture
)

if not user_doc:
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="Could not create or retrieve user profile.",
    )

if not user_doc.picture:
    user_doc.picture = picture
    # Update picture logic...
    if user_doc.id:
         await user_service.user_repo.update(user_doc.id, {"picture": picture})

return user_doc
```

**Replace With**:
```python
# User must exist in database (no auto-provisioning)
user_doc = await user_service.get_user_by_email(email)

if not user_doc:
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="User account does not exist. Please contact your administrator for access.",
    )

# Update picture if needed
if user_doc and not user_doc.picture:
    user_doc.picture = picture
    if user_doc.id:
        await user_service.user_repo.update(user_doc.id, {"picture": picture})

return user_doc
```

**What Changed**:
- ❌ Removed: `create_user_if_not_exists()` call
- ✅ Added: `get_user_by_email()` call
- ✅ Changed: Error to 403 (Forbidden) instead of auto-creating

---

## Step 2: Add Missing Service Method

### File: `backend/src/users/user_service.py`

**Location**: After `create_user_if_not_exists()` method (around line 66)

**Add This Method**:
```python
async def get_user_by_email(self, email: str) -> Optional[UserModel]:
    """
    Retrieves a user by their email.
    Returns None if user doesn't exist (no auto-provisioning).

    This method is used during authentication when auto-provisioning is disabled.
    """
    return await self.user_repo.get_by_email(email)
```

**Why Needed**:
- The `user_repo` already has `get_by_email()` method
- This wrapper provides consistency with service layer pattern
- Makes code more maintainable

---

## Step 3: Add Admin User Creation Endpoint

### File: `backend/src/users/user_controller.py`

**Location**: After existing endpoints

**Add This New Endpoint**:
```python
@router.post(
    "/api/admin/users",
    tags=["User Management"],
    dependencies=[Depends(RoleChecker(allowed_roles=[UserRoleEnum.ADMIN]))],
)
async def create_user(
    create_request: UserCreateDto,
    user_service: UserService = Depends(),
    current_user: UserModel = Depends(get_current_user),
) -> UserModel:
    """
    Create a new user manually. Admin only.

    This endpoint replaces auto-provisioning. Admins use this to grant
    access to new users instead of users auto-provisioning on first login.

    Parameters:
    - email: User's email address (must be unique)
    - name: User's display name
    - picture: User's profile picture URL (optional)
    - roles: List of roles to assign (default: ['user'])

    Response:
    - Returns created UserModel with assigned roles

    Errors:
    - 409: User already exists
    - 400: Invalid email format
    - 403: Insufficient permissions (not admin)

    Example Request:
    POST /api/admin/users
    {
        "email": "newuser@company.com",
        "name": "New User",
        "picture": "https://example.com/pic.jpg",
        "roles": ["user"]
    }

    Example Response:
    {
        "id": 42,
        "email": "newuser@company.com",
        "name": "New User",
        "picture": "https://example.com/pic.jpg",
        "roles": ["user"]
    }
    """

    # 1. Check if user already exists
    existing_user = await user_service.get_user_by_email(create_request.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"User with email {create_request.email} already exists.",
        )

    # 2. Prepare user data
    user_data = create_request.model_dump()

    # Use provided roles or default to USER
    if not user_data.get("roles"):
        user_data["roles"] = [UserRoleEnum.USER.value]
    else:
        # Convert enums to strings for database
        user_data["roles"] = [
            role.value if isinstance(role, UserRoleEnum) else role
            for role in user_data["roles"]
        ]

    # 3. Create user in database
    new_user = await user_service.user_repo.create(user_data)

    # 4. Log audit event
    logger.info(
        f"User {create_request.email} created by {current_user.email} "
        f"with roles: {user_data['roles']}"
    )

    return new_user
```

**Usage Example**:
```bash
# Create a regular user
curl -X POST http://localhost:8080/api/admin/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "alice@company.com",
    "name": "Alice Smith",
    "roles": ["user"]
  }'

# Create a creator user (can create templates)
curl -X POST http://localhost:8080/api/admin/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "bob@company.com",
    "name": "Bob Jones",
    "roles": ["user", "creator"]
  }'
```

---

## Step 4: Update UserCreateDto (if needed)

### File: `backend/src/users/dto/user_create_dto.py`

**Check that this DTO exists with roles field**:
```python
from typing import List, Optional
from pydantic import BaseModel
from src.users.user_model import UserRoleEnum

class UserCreateDto(BaseModel):
    email: str
    name: str
    picture: Optional[str] = None
    roles: Optional[List[UserRoleEnum]] = None
```

**If roles field is missing, add it**:
```python
from typing import List, Optional
from pydantic import BaseModel, Field
from src.users.user_model import UserRoleEnum

class UserCreateDto(BaseModel):
    email: str
    name: str
    picture: Optional[str] = None
    roles: Optional[List[UserRoleEnum]] = Field(
        default=None,
        description="Roles to assign. If not provided, defaults to ['user']"
    )
```

---

## Step 5: Testing

### Test 1: User NOT in Database

**Scenario**: Unauthenticated user tries to access API

```bash
# Get a valid Google token
TOKEN=$(gcloud auth application-default print-access-token)

# Try to call an API (user not in database)
curl -X POST http://localhost:8080/api/images/generate-images \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "test image"}'

# Expected Response (403 Forbidden):
{
  "detail": "User account does not exist. Please contact your administrator for access."
}
```

**✅ PASS**: Gets 403, not auto-provisioned

---

### Test 2: Create User via Admin Endpoint

**Scenario**: Admin creates a new user

```bash
# First, get admin token (user must already exist and have ADMIN role)
ADMIN_TOKEN=$(gcloud auth application-default print-access-token)

# Create new user
curl -X POST http://localhost:8080/api/admin/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@company.com",
    "name": "New User",
    "roles": ["user"]
  }'

# Expected Response (201 Created):
{
  "id": 42,
  "email": "newuser@company.com",
  "name": "New User",
  "picture": "",
  "roles": ["user"]
}
```

**✅ PASS**: User created successfully

---

### Test 3: Authenticated User Can Access API

**Scenario**: Created user now tries to access API

```bash
# User logs in with Google OAuth
# Gets token, calls API

curl -X POST http://localhost:8080/api/images/generate-images \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "beautiful sunset",
    "workspace_id": 1
  }'

# Expected Response (202 Accepted or 200 Success):
{
  "success": true,
  "data": {
    "id": "media-abc123",
    "status": "pending",
    ...
  }
}
```

**✅ PASS**: User can access API

---

### Test 4: Duplicate User Prevention

**Scenario**: Try to create same user twice

```bash
# First creation (succeeds)
curl -X POST http://localhost:8080/api/admin/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "alice@company.com",
    "name": "Alice",
    "roles": ["user"]
  }'
# Returns: 201 Created

# Second creation (should fail)
curl -X POST http://localhost:8080/api/admin/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "alice@company.com",
    "name": "Alice",
    "roles": ["user"]
  }'

# Expected Response (409 Conflict):
{
  "detail": "User with email alice@company.com already exists."
}
```

**✅ PASS**: Prevents duplicates

---

### Test 5: Non-Admin Cannot Create Users

**Scenario**: Regular user tries to create another user

```bash
# Non-admin token
USER_TOKEN=$(login_as_regular_user)

curl -X POST http://localhost:8080/api/admin/users \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "another@company.com",
    "name": "Another User",
    "roles": ["user"]
  }'

# Expected Response (403 Forbidden):
{
  "detail": "You do not have sufficient permissions to perform this action."
}
```

**✅ PASS**: Only admins can create users

---

## Step 6: Database Migration

### If Using Alembic for Migrations

**Optional**: No schema changes needed if auto-provisioning was just a code behavior

**But you might want to track**: Users that were auto-provisioned before

```bash
# Check if there's a way to identify auto-provisioned users
# (they might have null created dates or similar)

# No migration needed for this change
```

---

## Step 7: Documentation & Communication

### Update These Files

**1. docs/05-security/01_ACCESS_CONTROL_AND_RBAC.md**
- Add section on "User Provisioning" explaining manual creation
- Update with new endpoint documentation

**2. docs/03-backend/02_API_ENDPOINTS_REFERENCE.md**
- Add section for "/api/admin/users" endpoint
- Include examples and error responses

**3. docs/01-getting-started/01_QUICK_START.md**
- Update "User Setup" section
- Explain that users no longer auto-provision
- Provide admin user creation instructions

**4. Create: docs/ADMIN_GUIDE.md**
```markdown
# Administrator Guide

## Creating New Users

Users no longer auto-provision on first login.
Administrators must manually create users.

### To Create a User:

1. Get your admin token:
   ```bash
   gcloud auth application-default print-access-token
   ```

2. Call the user creation endpoint:
   ```bash
   curl -X POST https://api.yourdomain.com/api/admin/users \
     -H "Authorization: Bearer $YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "email": "user@company.com",
       "name": "John Doe",
       "roles": ["user"]
     }'
   ```

3. User receives notification (optional, implement later)

4. User can now login

## Creating a Creator

To let someone create templates:

```bash
curl -X POST https://api.yourdomain.com/api/admin/users \
  -H "Authorization: Bearer $YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "template-creator@company.com",
    "name": "Template Creator",
    "roles": ["user", "creator"]
  }'
```
```

---

## Step 8: Deployment Checklist

Before deploying to production:

- [ ] Code reviewed by another engineer
- [ ] All tests passing (unit + integration)
- [ ] Tested in staging environment
- [ ] Database backup created
- [ ] Admin users created and tested
- [ ] Documentation updated
- [ ] Team notified of change
- [ ] Error messages clear and helpful
- [ ] Logging configured for audit trail
- [ ] Monitoring alerts set up

---

## Rollback Plan

If something goes wrong:

### Quick Rollback (Last Resort)
```python
# In auth_guard.py, revert to:
user_doc = await user_service.create_user_if_not_exists(
    email=email, name=name, picture=picture
)
```

**But better**: Fix the real issue, don't revert

### Common Issues & Fixes

**Issue**: "User account does not exist" error for valid users

**Solution**:
1. Check if user exists in database: `SELECT * FROM users WHERE email = 'user@company.com'`
2. If not, create user via admin endpoint
3. If exists, check roles: `SELECT roles FROM users WHERE email = 'user@company.com'`

---

**Issue**: Admin can't create users

**Solution**:
1. Verify admin user has ADMIN role: `SELECT roles FROM users WHERE email = 'admin@company.com'`
2. Ensure admin user token is valid
3. Check logs for specific error

---

## Success Criteria

After deployment, verify:

- ✅ Unauthenticated users get 403 (not auto-provisioned)
- ✅ Admin can create users via API
- ✅ Created users can access the system
- ✅ Duplicates are prevented
- ✅ Non-admins cannot create users
- ✅ Audit logs show who created which users
- ✅ No cost incurred for invalid users

---

## Timeline

```
Day 1:
- Morning: Code changes (2-3 hours)
- Afternoon: Testing (2-3 hours)

Day 2:
- Morning: Code review (1 hour)
- Afternoon: Deploy to staging (1 hour)

Day 3:
- Test in staging (2-4 hours)
- Deploy to production (1 hour)

Day 4+:
- Monitor for issues
- Adjust based on feedback
```

---

## Cost Savings

**Before**: Unlimited potential costs
- Any user with Google account can provision
- Can create unlimited images/videos
- Potential $1000s in monthly costs

**After**: Controlled costs
- Only approved users get access
- Admin controls who can access
- Cost predictable and manageable

---

## Next Steps (Optional Enhancements)

After successful deployment:

1. **Email Notifications** (Week 2)
   - Send email when user created
   - Send email when user role changed

2. **Admin Dashboard** (Week 3)
   - UI to create users
   - UI to manage roles
   - UI to view user list

3. **Audit Logging** (Week 4)
   - Log all user creation events
   - Log all role changes
   - Log all access attempts

4. **Approval Workflow** (Week 5+)
   - Users request access
   - Admins approve
   - Automated notifications

---

**Ready to implement!**

Questions? Refer to 03_SECURITY_AND_COST_ANALYSIS.md for more details.

