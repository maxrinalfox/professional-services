# Pre-Implementation Research Checklist
## Must-Complete Tasks Before Decision

**Status**: Research Phase Active
**Timeline**: Complete within 1 day
**Owner**: Engineering Lead
**Deliverable**: Research findings document

---

## Phase 1: Database State Analysis (1-2 hours)

### 1.1 Current User Count

**Task**: Connect to production database and run analysis

```bash
# Step 1: Connect to production database
# (Using your preferred database client)

# Step 2: Run these queries
```

**Query 1: User Overview**
```sql
SELECT
  COUNT(*) as total_users,
  COUNT(CASE WHEN created_at > NOW() - INTERVAL '30 days' THEN 1 END) as created_last_30_days,
  COUNT(CASE WHEN created_at > NOW() - INTERVAL '7 days' THEN 1 END) as created_last_7_days,
  COUNT(CASE WHEN created_at > NOW() - INTERVAL '1 day' THEN 1 END) as created_today
FROM users;
```

**Expected Output**:
```
total_users | created_last_30_days | created_last_7_days | created_today
        150 |                   42 |                  12 |              3
```

**What to Document**:
- [ ] Total users in system
- [ ] New users per week
- [ ] New users per day
- [ ] Growth trend (accelerating or stable?)

---

**Query 2: Email Domain Distribution**
```sql
SELECT
  SUBSTRING(email FROM '@' + 1) as domain,
  COUNT(*) as user_count,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM users), 1) as percentage
FROM users
GROUP BY SUBSTRING(email FROM '@' + 1)
ORDER BY user_count DESC;
```

**Expected Output**:
```
domain        | user_count | percentage
company.com   |         85 |       56.7
gmail.com     |         42 |       28.0
test@test.com |          8 |        5.3
other.com     |         15 |       10.0
```

**What to Document**:
- [ ] Primary domain (should be company domain)
- [ ] Percentage of legitimate users
- [ ] Percentage of external/test users
- [ ] Domains that shouldn't have access

---

**Query 3: User Activity Analysis**
```sql
SELECT
  email,
  roles,
  created_at,
  updated_at,
  DATEDIFF(day, created_at, NOW()) as days_since_created,
  CASE
    WHEN updated_at IS NULL OR DATEDIFF(day, updated_at, NOW()) > 30
    THEN 'INACTIVE'
    ELSE 'ACTIVE'
  END as status
FROM users
ORDER BY updated_at DESC
LIMIT 50;
```

**Expected Output**:
```
email              | roles        | created_at | updated_at | status
alice@company.com  | [user]       | 2025-10-01 | 2025-12-14 | ACTIVE
bob@gmail.com      | [user]       | 2025-06-15 | 2025-05-20 | INACTIVE
test@test.com      | [user]       | 2025-11-01 | 2025-11-02 | INACTIVE
```

**What to Document**:
- [ ] Active vs. inactive user ratio
- [ ] Last 20 active users (are they legitimate?)
- [ ] Inactive users (can these be deleted?)
- [ ] Suspicious accounts (test, fake emails, etc.)

---

### 1.2 Workspace Impact Analysis

**Query 4: Workspace Ownership**
```sql
SELECT
  u.email,
  COUNT(w.id) as workspace_count,
  STRING_AGG(w.name, ', ') as workspace_names
FROM users u
LEFT JOIN workspaces w ON u.id = w.owner_id
WHERE w.id IS NOT NULL
GROUP BY u.id, u.email
ORDER BY workspace_count DESC;
```

**Expected Output**:
```
email              | workspace_count | workspace_names
alice@company.com  |               5 | Project A, Project B, ...
bob@company.com    |               3 | Marketing, ...
```

**What to Document**:
- [ ] Users who own workspaces (they should NOT be deleted)
- [ ] Single points of failure (users owning critical workspaces)
- [ ] Workspace orphaning risk

---

**Query 5: Workspace Membership**
```sql
SELECT
  u.email,
  COUNT(wm.workspace_id) as workspace_memberships,
  COUNT(CASE WHEN wm.role = 'admin' THEN 1 END) as admin_in_workspaces,
  COUNT(CASE WHEN wm.role = 'editor' THEN 1 END) as editor_in_workspaces
FROM users u
LEFT JOIN workspace_members wm ON u.id = wm.user_id
WHERE wm.workspace_id IS NOT NULL
GROUP BY u.id, u.email
ORDER BY workspace_memberships DESC
LIMIT 20;
```

**Expected Output**:
```
email               | workspace_memberships | admin_in_workspaces | editor_in_workspaces
alice@company.com   |                    10 |                   3 |                    7
bob@company.com     |                     5 |                   1 |                    4
```

**What to Document**:
- [ ] Users with high workspace memberships (core users, must not be deleted)
- [ ] Users with admin roles (power users)
- [ ] Users with only editor access (lower priority)

---

### 1.3 Media/Gallery Analysis

**Query 6: Content Ownership**
```sql
SELECT
  u.email,
  COUNT(g.id) as media_count,
  MAX(g.created_at) as last_media_created
FROM users u
LEFT JOIN galleries g ON u.id = g.created_by_user_id
WHERE g.id IS NOT NULL
GROUP BY u.id, u.email
ORDER BY media_count DESC
LIMIT 20;
```

**Expected Output**:
```
email               | media_count | last_media_created
alice@company.com   |         145 |      2025-12-14
bob@company.com     |          32 |      2025-12-13
charlie@gmail.com   |           8 |      2025-11-01
```

**What to Document**:
- [ ] Active content creators (must retain)
- [ ] Orphaned media (users with content but no workspace)
- [ ] Test data (easily identifiable for deletion)

---

## Checklist Section 1 Complete

- [ ] Query 1: Total user count and growth rate documented
- [ ] Query 2: Email domain distribution analyzed
- [ ] Query 3: Activity status (active vs. inactive) determined
- [ ] Query 4: Workspace owners identified (DO NOT DELETE)
- [ ] Query 5: Users with workspace memberships listed
- [ ] Query 6: Content owners and media counts documented

**Estimated Time**: 1-2 hours
**Status**: ☐ Not Started | ☐ In Progress | ☐ Complete

---

## Phase 2: Code Dependency Audit (1-2 hours)

### 2.1 Auto-Provisioning Dependencies

**Task**: Find all places in code that depend on auto-provisioning behavior

```bash
# Search for create_user_if_not_exists usage
grep -r "create_user_if_not_exists" backend/src/ --include="*.py"

# Search for get_current_user dependency
grep -r "get_current_user" backend/src/ --include="*.py" | head -20

# Search for assumptions about user existence
grep -r "HTTPException.*404" backend/src/ --include="*.py"
```

**Files to Check**:
```
backend/src/
├─ auth/auth_guard.py .................... [ALREADY IDENTIFIED]
├─ users/user_service.py ................. [ALREADY IDENTIFIED]
├─ users/user_controller.py .............. [CHECK FOR USER CREATION ROUTES]
├─ images/imagen_controller.py ........... [CHECK: does it assume user exists?]
├─ videos/veo_controller.py .............. [CHECK: does it assume user exists?]
├─ audios/audio_controller.py ............ [CHECK: does it assume user exists?]
├─ source_assets/source_asset_controller.py [CHECK: does it assume user exists?]
├─ media_templates/media_template_controller.py [CHECK: does it assume user exists?]
├─ workspaces/workspace_service.py ....... [ALREADY PARTIALLY IDENTIFIED]
└─ galleries/gallery_controller.py ....... [CHECK: does it handle missing creator?]
```

**Checklist for Each File**:
- [ ] Does it call get_current_user?
- [ ] Does it assume current_user is non-null?
- [ ] Does it handle 403/permission errors?
- [ ] Are error messages clear?
- [ ] Any direct database queries assuming user exists?

**Document Findings**:
- [ ] Files that need NO changes
- [ ] Files that need error message improvements
- [ ] Files that need defensive code (null checks)
- [ ] Risk assessment (1-5 scale) for each file

---

### 2.2 Workspace Invitation Impact

**Task**: Test workspace invitation flow with non-existent user

```bash
# In your test environment:
1. Try to invite user@doesnotexist.com to a workspace
2. Check: Does it fail gracefully or silently?
3. Check: Is error message clear?
4. Document: What endpoint is /api/workspaces/{id}/invites?
```

**Test Steps**:
```
1. Login as admin user (system-level ADMIN role)
2. Create a test workspace
3. Try to invite nonexistent@user.com
4. Expected: HTTP 404 with clear message
5. Current: ??? (need to test and document)
```

**Checklist**:
- [ ] Invitation endpoint found and documented
- [ ] Tested with non-existent user
- [ ] Error message is clear (or needs improvement)
- [ ] Code location identified for fix (if needed)

---

### 2.3 Integration Test Dependencies

**Task**: Identify integration tests that depend on auto-provisioning

```bash
# Find integration tests
find . -name "*test*.py" -o -name "*spec*.py" | grep -i integration

# Search for test setup that might depend on auto-provisioning
grep -r "get_current_user\|create_user_if_not_exists" backend/tests/ --include="*.py"

# Look for mocking patterns
grep -r "mock.*user\|patch.*user" backend/tests/ --include="*.py"
```

**Checklist**:
- [ ] Integration tests directory identified
- [ ] Tests that create temporary users found
- [ ] Tests that mock get_current_user found
- [ ] Risk assessment: How many tests will break?

---

## Checklist Section 2 Complete

- [ ] All code files depending on auto-provisioning identified
- [ ] Workspace invitation flow tested
- [ ] Error handling assessed for each component
- [ ] Integration tests reviewed
- [ ] Comprehensive impact assessment completed

**Estimated Time**: 1-2 hours
**Status**: ☐ Not Started | ☐ In Progress | ☐ Complete

---

## Phase 3: System Component Verification (1-2 hours)

### 3.1 Email Service Readiness

**Task**: Verify email service is configured and working

```bash
# Check email configuration
grep -r "email_service\|EmailService\|SMTP" backend/src/config/ --include="*.py"

# Check for email service
find . -path "*/email*" -name "*.py" | head -5
```

**Checklist**:
- [ ] EmailService class exists
- [ ] SMTP/Email provider configured
- [ ] Can send test email
- [ ] Email templates for welcome exist or need to be created
- [ ] Response time acceptable for user experience

**If Not Ready**:
- Option A: Send emails in background job (no user wait)
- Option B: No email (admin notifies manually)
- Option C: Use password reset email (generic but works)

---

### 3.2 Super-Admin Token Verification

**Task**: Verify emergency access mechanism

```bash
# Check if SUPER_ADMIN_TOKEN is documented
grep -r "SUPER_ADMIN_TOKEN\|super.admin\|emergency" backend/src/ --include="*.py"

# Check environment variables
grep -r "SUPER_ADMIN" backend/.env* 2>/dev/null || echo "Not in repo (good!)"

# Check if implemented in auth_guard.py
grep -A 5 "SUPER_ADMIN_TOKEN" backend/src/auth/auth_guard.py
```

**Checklist**:
- [ ] SUPER_ADMIN_TOKEN mechanism exists
- [ ] Documented where to find it
- [ ] Tested that it works
- [ ] Emergency procedure documented
- [ ] Rotation policy defined

**If Not Found**:
- [ ] Create SUPER_ADMIN_TOKEN mechanism
- [ ] Add environment variable
- [ ] Document recovery procedure
- [ ] Test it works

---

### 3.3 Database Connection Verification

**Task**: Ensure you can connect to production database

```bash
# Test connection
# Using your database client:
SELECT NOW() as connection_test;
```

**Checklist**:
- [ ] Can connect to production database
- [ ] Have backup procedure in place
- [ ] Know how to run manual queries
- [ ] Have rollback plan if queries fail

---

## Checklist Section 3 Complete

- [ ] Email service status verified
- [ ] Super-admin token verified or flagged for creation
- [ ] Database connectivity confirmed
- [ ] Emergency procedures documented

**Estimated Time**: 1-2 hours
**Status**: ☐ Not Started | ☐ In Progress | ☐ Complete

---

## Phase 4: Frontend Analysis (30-60 minutes)

### 4.1 Error Handling for 403 "User Not Found"

**Task**: Check how frontend handles authentication errors

```bash
# Find Angular error handling
grep -r "403\|HTTPError\|Forbidden" frontend/src/ --include="*.ts" | head -20

# Find auth interceptor
find frontend/src/ -name "*auth*.ts" -o -name "*interceptor*.ts" | head -10
```

**Checklist**:
- [ ] Error interceptor exists and handles 403
- [ ] User-friendly error message shown
- [ ] Login page can display help text
- [ ] Admin contact info displayable

**If No Error Handling**:
- [ ] Create error interceptor for 403 "user not found"
- [ ] Show helpful message on login page
- [ ] Provide admin contact information

---

### 4.2 Login Flow Verification

**Task**: Trace complete login flow to understand failure points

**Steps**:
1. User clicks login
2. Google OAuth window appears
3. User authenticates with Google
4. Frontend gets OAuth token
5. Frontend calls API with token
6. Backend validates token
7. Backend checks if user exists
8. IF NO: Return 403 "User does not exist"
9. Frontend should: Show error message

**Checklist**:
- [ ] Login flow traced end-to-end
- [ ] 403 response handling identified
- [ ] Error message display location identified
- [ ] Help text / admin contact visible to user

---

## Checklist Section 4 Complete

- [ ] Frontend error handling assessed
- [ ] Login flow traced
- [ ] User experience during error identified
- [ ] Improvement needs documented

**Estimated Time**: 30-60 minutes
**Status**: ☐ Not Started | ☐ In Progress | ☐ Complete

---

## Phase 5: Synthesis & Decision Support (30-60 minutes)

### 5.1 Create Summary Document

**Task**: Compile all research findings into decision support document

**Document Should Include**:
- [ ] Total users: [NUMBER]
- [ ] Active users: [NUMBER]
- [ ] Inactive users: [NUMBER]
- [ ] Primary domain: [DOMAIN]
- [ ] Workspace owners at risk: [NAMES]
- [ ] Content creators (high-value users): [NAMES]
- [ ] Code changes needed: [COUNT]
- [ ] Risk assessment: [LOW/MEDIUM/HIGH]
- [ ] Recommended option: [1/2/3/4]
- [ ] Recommended migration path: [PATH 1/2/3]

**Format**: 1-2 page summary for leadership

---

### 5.2 Risk Assessment

**Create Risk Matrix**:

| Risk | Probability | Severity | Mitigation |
|------|-------------|----------|-----------|
| Existing users lose access | [LOW/MED/HIGH] | [LOW/MED/HIGH] | [PATH 1/2/3] |
| Code breaks | [LOW/MED/HIGH] | [LOW/MED/HIGH] | [CODE AUDIT] |
| Email service fails | [LOW/MED/HIGH] | [LOW/MED/HIGH] | [FALLBACK] |
| Admin lockout | [LOW/MED/HIGH] | [LOW/MED/HIGH] | [SUPER-TOKEN] |

---

## Checklist Section 5 Complete

- [ ] Summary document created
- [ ] Risk matrix populated
- [ ] Decision recommendation clear
- [ ] Findings shared with team

**Estimated Time**: 30-60 minutes
**Status**: ☐ Not Started | ☐ In Progress | ☐ Complete

---

## Total Research Phase Timeline

```
Phase 1: Database Analysis ........... 1-2 hours
Phase 2: Code Audit ................. 1-2 hours
Phase 3: System Verification ........ 1-2 hours
Phase 4: Frontend Analysis .......... 0.5-1 hour
Phase 5: Synthesis .................. 0.5-1 hour
                          TOTAL = 4-9 hours
```

**Can be completed in 1-2 days**

---

## After Research: Decision Meeting

**Schedule**: 1-hour meeting

**Attendees**:
- Engineering Lead
- Product Manager (or decision maker)
- DevOps/Infrastructure (for deployment)
- Frontend Lead (if changes needed)

**Agenda**:
1. Review research findings (15 min)
2. Discuss each option (20 min)
3. Vote on option (5 min)
4. Decide migration path (10 min)
5. Approve timeline (5 min)
6. Assign owners (5 min)

**Output**:
- [ ] Decision: Option [1/2/3/4]
- [ ] Migration Path: [1/2/3]
- [ ] Timeline: [DATE]
- [ ] Owner assigned
- [ ] Stakeholders informed

---

## Implementation Phase Starts After Decision

Once decision is made:
1. Create detailed implementation plan
2. Break down into tasks
3. Assign team members
4. Set daily stand-ups
5. Begin coding

---

## Research Completion Checklist

### Database Analysis
- [ ] User count documented
- [ ] Domain distribution documented
- [ ] Active/inactive ratio documented
- [ ] Workspace owners identified
- [ ] Content creators identified
- [ ] Suspicious accounts flagged

### Code Audit
- [ ] Auto-provisioning dependencies found
- [ ] Workspace invitation flow tested
- [ ] Error handling assessed
- [ ] Integration tests reviewed
- [ ] Risk assessment completed

### System Verification
- [ ] Email service verified
- [ ] Super-admin token verified
- [ ] Database connectivity confirmed

### Frontend Analysis
- [ ] Error handling reviewed
- [ ] Login flow traced
- [ ] User experience issues identified

### Synthesis
- [ ] Summary document created
- [ ] Risk matrix completed
- [ ] Recommendation made
- [ ] Decision meeting scheduled

---

**✅ Research Phase Complete When All Checkboxes Marked**

**Next**: Schedule decision meeting and make final choice on Option 1-4

