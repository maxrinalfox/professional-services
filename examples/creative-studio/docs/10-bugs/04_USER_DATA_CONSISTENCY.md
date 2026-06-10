# Bug Report: Data Consistency Across User Storage Systems

**Bug ID**: BUG-004
**Status**: 🔴 Open
**Severity**: High
**Component**: Backend / Database / Architecture
**Reported**: December 17, 2025

---

## Summary

User data is split across PostgreSQL, Firestore, and Firebase Authentication with no single source of truth, causing synchronization issues and potential data integrity problems.

---

## Detailed Description

### Current Data Distribution

```
User Data Stored In THREE Systems:
├─ PostgreSQL (users table)
│  └─ email, roles[], name, picture, created_at
│
├─ Firestore (user collection)
│  └─ workspace permissions, user roles, metadata
│
└─ Firebase Authentication (unused)
   └─ Should be here but isn't
```

### Problems This Causes

1. **No Single Source of Truth**
   - Conflicting updates across systems
   - Different data models per system
   - Hard to track where "real" data lives

2. **Sync Issues**
   - Update PostgreSQL but Firestore out of sync
   - Delete from PostgreSQL, Firestore remains
   - Role changes require multiple updates

3. **Complex Operations**
   - User creation: 2 inserts (PostgreSQL + Firestore)
   - Role update: 2 updates (PostgreSQL + Firestore)
   - User deletion: 2 deletes (PostgreSQL + Firestore)
   - Workspace member removal: 3+ operations

4. **Data Consistency Risk**
   ```
   Scenario: Add user to workspace
   1. Update PostgreSQL workspace_members ✓
   2. Update Firestore user roles → FAILS ✗
   → User can access workspace data but has no permissions
   → Undefined behavior, potential security issue
   ```

---

## Root Cause

**Incremental Development Without Consolidation**:
- Started with PostgreSQL for users
- Later added Firestore for permissions
- Firebase never properly integrated
- No migration to single system

---

## How to Replicate

### Test Case 1: Out-of-Sync Scenario
1. Create user in PostgreSQL
2. Simulate Firestore write failure
3. Query user data
4. **Result**: Inconsistent state between systems

### Test Case 2: Role Update
1. Update user role in PostgreSQL
2. Firestore update fails silently
3. Check user permissions
4. **Result**: User has old permissions (Firestore)

---

## Impact Assessment

### Affected Users
- Users added to workspaces
- Users with role changes
- Workspace membership management

### Business Impact
- Data integrity risk
- Potential security issues
- Maintenance burden
- High bug risk

---

## Solution Options

### Option A: PostgreSQL as Source of Truth (Recommended)
**Effort**: 2 weeks
**Risk**: Low

1. Migrate all user data to PostgreSQL
2. Remove Firestore user collection
3. Query PostgreSQL for all user operations
4. Keep only workspace-specific data in Firestore

**Pros**: Single database, ACID guarantees, simpler code
**Cons**: Larger PostgreSQL queries

---

### Option B: Firestore as Source of Truth
**Effort**: 3 weeks
**Risk**: Medium

1. Migrate all data to Firestore
2. Remove PostgreSQL user table
3. Use Firestore for all operations

**Pros**: NoSQL flexibility
**Cons**: Eventual consistency, higher cost

---

### Option C: Firebase Authentication + PostgreSQL (Recommended with BUG-002 fix)
**Effort**: 4 weeks
**Risk**: Medium

1. Users in Firebase Authentication (official source)
2. Extended data in PostgreSQL
3. Firebase for auth, PostgreSQL for app data

**Pros**: Proper separation of concerns
**Cons**: Dependency on Firebase, more infrastructure

---

## Recommendation

**Implement Option A** - PostgreSQL as single source of truth:
1. Simpler implementation
2. Lower risk
3. ACID guarantees
4. No external dependencies

---

## Technical Details

### Files Affected
- `backend/src/users/` - User service
- `backend/src/workspaces/` - Workspace service
- `backend/alembic/versions/` - Database migrations
- `backend/bootstrap/` - User seeding

### Migration Steps
1. Copy all data from Firestore to PostgreSQL
2. Verify data integrity
3. Update queries to use PostgreSQL only
4. Remove Firestore user operations
5. Delete Firestore user collection

---

## Testing

### Pre-migration
- Document current data in both systems
- Identify conflicts/duplicates
- Plan deduplication strategy

### Post-migration
- Verify all user data in PostgreSQL
- Test user creation/update/delete
- Test workspace member operations
- Test role assignments
- Verify Firestore no longer used for users

---

## Timeline

- **Reported**: December 17, 2025
- **Expected Duration**: 2 weeks (Option A)
- **Status**: Waiting for architecture decision

---

## Related Issues

- **BUG-002**: Authentication system redesign (affects user storage)
- **BUG-005**: Query performance (related to data distribution)

---

## Checklist for Resolution

- [ ] Option chosen (A/B/C)
- [ ] Migration plan created
- [ ] Data audit complete
- [ ] Migration code written
- [ ] Backup created
- [ ] Migration tested
- [ ] All queries updated
- [ ] Tests passing
- [ ] Firestore cleaned up
- [ ] Documentation updated
- [ ] Deployment scheduled

---
