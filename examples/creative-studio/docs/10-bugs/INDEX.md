# Bug Reports & Known Issues

**Status**: Comprehensive issue tracking system
**Last Updated**: January 2, 2026
**Purpose**: Central hub for all known bugs, issues, and their detailed reports

---

## 📋 Quick Index

| ID | Title | Status | Severity | Component | Fix Effort |
|---|---|---|---|---|---|
| [BUG-001](#bug-001-missing-media-template-thumbnails) | Missing Media Template Thumbnails | 🔴 Open | Medium | Bootstrap/Frontend | 1-2 hours |

---

## 🔴 Active Bug Reports

### BUG-001: Missing Media Template Thumbnails

**Status**: 🔴 Open
**Severity**: Medium
**Component**: Bootstrap / Media Templates / Frontend
**Reported**: January 2, 2026

#### Summary
Six media template thumbnails are not being generated during bootstrap, causing 404 errors and broken images in the admin UI.

#### Affected Templates
- Painting Replacement
- Floor Replacement
- Photorealistic Denoising
- Virtual Garment Transfer
- Pose Variation Sheet
- Product Flat Lay 1

#### Root Cause
The seed data configuration (`backend/bootstrap/seed_data.py`) is missing `local_thumbnail_uris` for these 6 templates. The bootstrap script correctly processes only what's defined, resulting in empty `thumbnail_uris` arrays in the database.

#### Solution Options
1. **Add Thumbnail Files** (Recommended - 1-2 hours)
   - Create/source thumbnail images
   - Add `local_thumbnail_uris` to seed data
   - Re-run bootstrap

2. **Generate Thumbnails Dynamically** (Long-term - 1-2 weeks)
   - Implement auto-generation during bootstrap
   - Extract frames from videos, generate placeholders for images
   - Scalable for future templates

3. **Fix Fallback Image** (Quick workaround - 5 minutes)
   - Change fallback from `default-avatar.png` (doesn't exist) to `default-profile-picture.svg`
   - Eliminates broken image icons immediately

#### Technical Details
- **Seed Data**: `backend/bootstrap/seed_data.py` lines 238-383
- **Bootstrap Process**: `backend/bootstrap/bootstrap.py` lines 289-293
- **Frontend Display**: `frontend/src/app/admin/media-templates-management/media-templates-management.component.html` line 66
- **Secondary Issue**: Fallback image referenced in 3 admin components

#### How to Replicate
1. Navigate to admin dashboard
2. Click "Manage Media Templates"
3. Observe the 6 templates listed above
4. Check Network tab in DevTools → Request to `/assets/images/default-avatar.png` returns 404

#### Full Report
For complete technical analysis, reproduction steps, code snippets, testing procedures, and more details, see: **[BUG-001 Full Report](./01_MISSING_MEDIA_TEMPLATE_THUMBNAILS.md)**

---

## ✅ Reporting New Bugs

### Requirements

Every bug report must include:

1. **Identification**
   - Bug ID (sequential: BUG-001, BUG-002, etc.)
   - Clear, specific title

2. **Context**
   - Status (🔴 Open, 🟡 In Progress, 🟢 Fixed, etc.)
   - Severity (Critical/High/Medium/Low)
   - Component affected
   - Date reported

3. **Analysis**
   - Summary (1-2 sentences)
   - Detailed description with context
   - Root cause analysis
   - Step-by-step reproduction

4. **Impact**
   - Who is affected
   - Business impact
   - Scope (isolated, widespread, etc.)

5. **Solutions**
   - 2-3 solution options with pros/cons
   - Recommended approach with justification
   - Effort/cost estimates

6. **Technical Details**
   - Affected files with line numbers
   - Code snippets showing the issue
   - Related code that might be impacted

7. **Verification**
   - How to test the bug exists
   - How to test the fix works

### Creating a New Bug Report

1. **Create file**: `docs/10-bugs/NN_SNAKE_CASE_BUG_TITLE.md`
   - Example: `02_API_NULL_POINTER_EXCEPTION.md`
   - Use zero-padded numbers: `01`, `02`, ... `10`, `11`, etc.

2. **Use structure from BUG-001**: Copy format and expand with your details

3. **Update this INDEX.md**: Add row to the Quick Index table

4. **Don't duplicate**: Keep summary here, full details in separate file

### File Naming Convention

```
NN_COMPONENT_SPECIFIC_ISSUE.md

Examples:
01_BOOTSTRAP_MISSING_THUMBNAILS.md
02_BACKEND_NULL_POINTER_AUTH.md
03_FRONTEND_MEMORY_LEAK_GALLERY.md
04_INFRA_FIRESTORE_QUOTA.md
```

---

## Status Indicators

| Icon | Status | Meaning | Action |
|------|--------|---------|--------|
| 🔴 | Open | New, not assigned | Needs triage |
| 🟡 | In Progress | Someone working on it | Link to PR/branch |
| 🟢 | Fixed | Fix implemented | Link to commit |
| ⚫ | Closed | Released | Link to version |
| 🟠 | Won't Fix | Intentional | Explain reasoning |
| ⚪ | Duplicate | Already reported | Link to original |

---

## Severity Levels

| Level | Impact | Examples |
|-------|--------|----------|
| 🔴 Critical | Complete blocker, data loss, security | Auth broken, data corruption |
| 🟠 High | Major feature broken | API down, core feature fails |
| 🟡 Medium | Feature partially broken | UI missing, performance issue |
| 🟢 Low | Cosmetic issue | Typo, alignment, styling |
| ⚪ Trivial | Polish only | Color preference |

---

## Statistics

### Summary
- **Total Bugs**: 1
- **Open**: 1
- **In Progress**: 0
- **Fixed**: 0
- **Closed**: 0

### By Severity
- Critical: 0
- High: 0
- Medium: 1
- Low: 0

### By Component
- Bootstrap: 1
- Backend: 0
- Frontend: 0
- Infrastructure: 0

---

## Best Practices

### ✅ Do

- Be specific and detailed
- Include reproduction steps with exact clicks/commands
- Provide code examples and file paths
- Explain the real-world impact
- Suggest multiple solutions with tradeoffs
- Keep summaries here, details in separate files
- Cross-reference related bugs
- Update this INDEX when adding new bugs
- Include timestamps and reporter info

### ❌ Don't

- Create vague generic reports
- Forget reproduction steps
- Mix multiple bugs in one report
- Leave severity/status blank
- Duplicate existing bug reports
- Forget to update INDEX.md
- Add entire detailed reports to INDEX
- Use overly long filenames

---

## Navigation

### By Component
- **Bootstrap Issues**: BUG-001
- **Backend Issues**: (none reported yet)
- **Frontend Issues**: BUG-001 (secondary)
- **Infrastructure Issues**: (none reported yet)

### By Severity
- **Critical**: (none reported)
- **High**: (none reported)
- **Medium**: BUG-001
- **Low**: (none reported)

### By Status
- **Open**: BUG-001
- **In Progress**: (none)
- **Fixed**: (none)
- **Closed**: (none)

---

## Related Documentation

### Overview Documents
- **[KNOWN_ISSUES_ARCHIVE.md](./KNOWN_ISSUES_ARCHIVE.md)** - Historical known issues list (for reference/migration)

### Feature Documentation
- **[Getting Started](../01-getting-started/)** - Setup guides
- **[Architecture](../02-architecture/)** - System design
- **[Backend](../03-backend/)** - API documentation
- **[Frontend](../04-frontend/)** - UI component guide
- **[Operations](../07-operations/)** - Troubleshooting guide

### How to Get Help
- **Troubleshooting**: See `../07-operations/03_TROUBLESHOOTING_GUIDE.md`
- **API Issues**: See `../03-backend/02_API_ENDPOINTS_REFERENCE.md`
- **Performance**: See `../07-operations/02_MONITORING_AND_ALERTS.md`

---

## Historical Reference

### Migration from Old System
The previous `00-KNOWN_ISSUES.md` file has been archived to `KNOWN_ISSUES_ARCHIVE.md` for reference. The new system provides:

- ✅ Detailed per-bug reports
- ✅ Better organization and navigation
- ✅ Clearer reproduction steps
- ✅ Multiple solution options per bug
- ✅ Consistent format across reports
- ✅ Single index (no duplication)

---

## Template for New Bug Reports

See the [BUG-001 Full Report](./01_MISSING_MEDIA_TEMPLATE_THUMBNAILS.md) for the complete template structure.

Key sections:
1. Summary
2. Detailed Description
3. Root Cause
4. How to Replicate
5. Impact Assessment
6. Solution Options
7. Recommendation
8. Technical Details
9. Testing
10. Timeline
11. Checklist

---

## Contributing

### Guidelines

1. **One bug per file** - Don't mix issues
2. **Complete information** - Don't skip sections
3. **Clear examples** - Use code snippets
4. **Update INDEX** - Keep this file current
5. **Be professional** - This is documentation

### Process

1. Check existing bugs first
2. Create new `.md` file following naming convention
3. Copy structure from BUG-001
4. Fill in all sections thoroughly
5. Update INDEX.md table
6. Commit with clear message

---

## Questions?

- **About a bug?** Check the full report (linked in INDEX)
- **How to report?** See "Reporting New Bugs" section above
- **File naming?** See "File Naming Convention" section above
- **Something unclear?** Check the [BUG-001 Full Report](./01_MISSING_MEDIA_TEMPLATE_THUMBNAILS.md) for complete example

---

**Last Updated**: January 2, 2026
**Maintainer**: Development Team
**Review Cycle**: Weekly (or as new bugs are reported)
