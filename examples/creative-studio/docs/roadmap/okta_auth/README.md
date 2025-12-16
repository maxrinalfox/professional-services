# Okta Integration - Phase 1: Architecture Prerequisite

**Status**: Critical (Blocking Issue) - Refactoring Required
**Last Updated**: December 17, 2025
**Part of**: 3-Phase Authentication Evolution

> ⚠️ **START HERE**: See `../IMPLEMENTATION_STRATEGY_MASTER_INDEX.md` for full context and how all 3 phases connect.

---

## What's in This Folder

Phase 1 addresses the **blocking architectural issue** preventing OIDC support.

### Critical Documents (Read These First)

| File | Time | Purpose |
|------|------|---------|
| `03_CURRENT_AUTHENTICATION_ISSUES.md` ⭐ | 45 min | **WHY** current auth blocks OIDC |
| `04_DEMO_APP_COMPARISON.md` ⭐ | 60 min | **HOW** to fix it (proven pattern) |

### Reference Documents (Optional Deep Dives)

| File | Time | Purpose |
|------|------|---------|
| `01_INTEGRATION_OVERVIEW.md` | 60+ min | Comprehensive Okta integration roadmap |
| `02_QUICK_REFERENCE_GUIDE.md` | 15 min | Quick ref for Okta setup |
| `05_ROLE_SYSTEM_AUDIT.md` | 30 min | Current role system analysis |

---

## The Problem (1 minute)

- ❌ Frontend uses deprecated `google.accounts.id` API
- ❌ Bypasses Firebase's provider federation
- ❌ Cannot add Okta or other OIDC providers
- ❌ Blocks Phase 2 (group/role support)

**Solution**: Refactor to Firebase's native `signInWithPopup()` method (1-2 weeks)

---

## Why This Matters

**Without Phase 1, you cannot:**
- ✗ Add Okta
- ✗ Add any OIDC provider
- ✗ Support user groups/directories
- ✗ Implement enterprise SSO

**With Phase 1 complete, you can:**
- ✅ Add unlimited OIDC providers (Firebase config only)
- ✅ Support user groups/directories
- ✅ Move to Phase 2 (automatic group-to-role mapping)

---

## Reading Path

1. **Must Read**: `03_CURRENT_AUTHENTICATION_ISSUES.md`
   - Understand why current implementation blocks OIDC
   - See specific code files that need changes

2. **Must Read**: `04_DEMO_APP_COMPARISON.md` (Section "Option B")
   - See how to fix it
   - See working code examples from Demo App
   - Understand the pattern

3. **Optional**: `01_INTEGRATION_OVERVIEW.md`
   - Full Okta integration roadmap
   - Comprehensive planning document

---

## Timeline

- **Phase 1 (This folder)**: 1-2 weeks to refactor architecture
- **Phase 2 (authentication_options/)**: 1-2 weeks to add OIDC + groups
- **Total**: 4 weeks to enterprise-ready auth

---

## Next Steps

1. Read `03_CURRENT_AUTHENTICATION_ISSUES.md` (understand problem)
2. Read `04_DEMO_APP_COMPARISON.md` (see solution + code)
3. Plan Phase 1 refactoring tickets
4. Then proceed to Phase 2: `../authentication_options/`

---

**For full context**: See `../IMPLEMENTATION_STRATEGY_MASTER_INDEX.md`
