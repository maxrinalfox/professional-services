# Bug Report: Missing Media Template Thumbnails

**Bug ID**: BUG-001
**Status**: 🔴 Open
**Severity**: Medium
**Component**: Bootstrap / Media Templates / Frontend
**Reported**: January 2, 2026
**Affected Templates**: 6 templates

---

## Summary

Six media template thumbnails are not being generated during the bootstrap phase, causing the frontend admin UI to display broken images with a fallback to a non-existent placeholder image.

---

## Detailed Description

### Current Behavior

When viewing the "Manage Media Templates" admin page, 6 specific templates display broken image thumbnails:

1. Painting Replacement
2. Floor Replacement
3. Photorealistic Denoising
4. Virtual Garment Transfer
5. Pose Variation Sheet
6. Product Flat Lay 1

The frontend attempts to load from: `https://foxsports-prod-ops-sandbox.web.app/assets/images/default-avatar.png`

**Result**: 404 Not Found + broken image icon in UI

### Root Cause

The issue is in the **bootstrap seed data configuration**, not the application code itself.

#### Chain of Events

1. **Seed Data Missing Thumbnails** (`backend/bootstrap/seed_data.py`)
   - These 6 templates do NOT have `local_thumbnail_uris` defined
   - Example of template WITH thumbnails (line 31-33):
     ```python
     "local_thumbnail_uris": [
         "cymbal-home-local-thumbnail.png",
     ],
     ```
   - The 6 affected templates have no such definition

2. **Bootstrap Script Process** (`backend/bootstrap/bootstrap.py`)
   - Lines 289-293: Maps local thumbnail URIs to GCS URIs
   - For templates without `local_thumbnail_uris`, this results in an empty list:
     ```python
     thumbnail_gcs_uris = [
         uri
         for local_uri in template_data.get("local_thumbnail_uris", [])
         if (uri := uri_map.get(local_uri)) is not None
     ]
     # Result: [] for affected templates
     ```

3. **Database Storage**
   - Templates stored with empty `thumbnail_uris` array in Firestore
   - Line 383: `thumbnail_uris=thumbnail_gcs_uris,` (empty for these templates)

4. **API Response**
   - Backend returns `presignedThumbnailUrls: []` for affected templates

5. **Frontend Fallback**
   - HTML template (lines 64-66 in media-templates-management.component.html):
     ```html
     [src]="
       template?.presignedThumbnailUrls?.[0] ||
       'assets/images/default-avatar.png'
     "
     ```
   - Since array is empty, falls back to non-existent image

### Secondary Issue: Invalid Fallback Image

The fallback image path is also incorrect:
- Referenced: `assets/images/default-avatar.png`
- Actually exists: `assets/images/default-profile-picture.svg`

---

## How to Replicate

### Prerequisites
- Application deployed to Firebase Hosting
- Bootstrap pipeline has run
- Admin user with access to "Manage Media Templates"

### Steps

1. Navigate to admin dashboard
2. Click "Manage Media Templates"
3. Observe the table of templates
4. Look at the "Thumbnail" column for these templates:
   - Painting Replacement
   - Floor Replacement
   - Photorealistic Denoising
   - Virtual Garment Transfer
   - Pose Variation Sheet
   - Product Flat Lay 1

### Expected vs Actual

**Expected**: Thumbnail image displays (either uploaded or generated)
**Actual**: Broken image icon (404 error for `/assets/images/default-avatar.png`)

### Verification

Check browser DevTools → Network tab:
- Request: `GET /assets/images/default-avatar.png`
- Response: `404 Not Found`

---

## Impact Assessment

### Affected Users
- Admin users managing media templates
- Anyone viewing the admin dashboard

### Severity
- **UI Impact**: Broken images in admin interface (cosmetic but unprofessional)
- **Functional Impact**: None - templates are still usable, thumbnails are missing
- **Data Impact**: None - no data corruption

### Scope
- Only affects display layer (frontend)
- Backend data is correctly stored (empty thumbnail array is accurate)
- Bootstrap process working as designed

---

## Solution Options

### Option A: Add Thumbnail Files (Recommended for User Experience)
**Effort**: Low (1-2 hours)
**Cost**: Minimal

Create thumbnail image files for the 6 templates and add them to seed data.

**Steps**:
1. Create or source thumbnail images for:
   - `painting-replacement-local-thumbnail.png`
   - `floor-replacement-local-thumbnail.png`
   - `photorealistic-denoising-local-thumbnail.png`
   - `virtual-garment-transfer-local-thumbnail.png`
   - `pose-variation-sheet-local-thumbnail.png`
   - `product-flat-lay-1-local-thumbnail.png`

2. Place files in: `backend/bootstrap/assets/media-template/`

3. Update `backend/bootstrap/seed_data.py` for each template:
   ```python
   "local_thumbnail_uris": [
       "painting-replacement-local-thumbnail.png",
   ],
   ```

4. Re-run bootstrap pipeline

**Pros**:
- Professional appearance
- Users get visual preview of templates
- One-time effort

**Cons**:
- Requires finding/creating appropriate images
- Maintenance if templates change

---

### Option B: Generate Thumbnails Dynamically (Long-term Solution)
**Effort**: High (1-2 weeks)
**Cost**: Moderate

Automatically generate thumbnail images when templates are created or during bootstrap.

**Steps**:
1. Add image generation logic to bootstrap script
2. For each template, generate a representative thumbnail:
   - For video templates: Extract first frame
   - For image templates: Create placeholder with template name
3. Upload generated thumbnails to GCS

**Pros**:
- Works for all new templates automatically
- No manual image management needed
- Scalable solution

**Cons**:
- More complex implementation
- Requires video frame extraction library
- Higher initial effort

---

### Option C: Fix Fallback Image (Quick Workaround)
**Effort**: Minimal (5 minutes)
**Cost**: None

While waiting for proper thumbnails, at least fix the fallback image.

**Steps**:
1. Update `frontend/src/app/admin/media-templates-management/media-templates-management.component.html` (line 66):
   ```html
   [src]="
     template?.presignedThumbnailUrls?.[0] ||
     'assets/images/default-profile-picture.svg'
   "
   ```

2. Rebuild and redeploy frontend

**Pros**:
- Instant fix
- No broken image icon
- Uses existing asset

**Cons**:
- Not ideal UX (generic placeholder instead of actual thumbnail)
- Doesn't solve root cause

---

## Recommendation

**Implement Option A (Add Thumbnails)** because:
1. Simple one-time effort
2. Significantly improves user experience
3. Professional appearance for admin dashboard
4. Works with current bootstrap architecture

If you want a long-term solution for future templates, implement Option B in parallel.

In the meantime, apply Option C as a quick fix to eliminate broken images.

---

## Technical Details

### Affected Files

**Seed Data Definition**:
- `backend/bootstrap/seed_data.py` lines 238-383

**Bootstrap Processing**:
- `backend/bootstrap/bootstrap.py` lines 289-293

**Frontend Display**:
- `frontend/src/app/admin/media-templates-management/media-templates-management.component.html` line 66
- `frontend/src/app/admin/media-templates-management/media-templates-management.component.ts` lines 69-84

**Frontend Other Locations** (same issue):
- `frontend/src/app/admin/users-management/users-management.component.html` line 60
- `frontend/src/app/admin/source-assets-management/source-assets-management.component.html` line 95

### Related Code

**Bootstrap Thumbnail Processing** (bootstrap.py):
```python
# Lines 289-293
thumbnail_gcs_uris = [
    uri
    for local_uri in template_data.get("local_thumbnail_uris", [])
    if (uri := uri_map.get(local_uri)) is not None
]
```

**Database Storage** (bootstrap.py):
```python
# Line 383
new_template = MediaTemplateModel(
    ...
    thumbnail_uris=thumbnail_gcs_uris,
    ...
)
```

**Frontend Template** (media-templates-management.component.html):
```html
<img
  [src]="
    template?.presignedThumbnailUrls?.[0] ||
    'assets/images/default-avatar.png'
  "
  alt="Media Template Thumbnail"
/>
```

---

## Testing

### Pre-fix Testing
1. List all media templates with empty `thumbnail_uris`
2. Verify they match the 6 templates listed above
3. Confirm API returns `presignedThumbnailUrls: []`

### Post-fix Testing (If Implementing Option A)
1. Deploy new bootstrap with thumbnail URIs added
2. Re-run bootstrap pipeline
3. Check database: templates should have non-empty `thumbnail_uris`
4. Verify API returns presigned URLs
5. Check frontend: images should display without 404 errors
6. Verify image quality is acceptable

### Post-fix Testing (If Implementing Option C)
1. Update frontend code
2. Rebuild and redeploy
3. Check browser: should no longer see broken image icon
4. Generic placeholder should display instead

---

## Related Issues

- **BUG-002**: Fallback image path incorrect (also references non-existent `default-avatar.png`)

---

## Timeline

- **Reported**: January 2, 2026
- **Expected Resolution**: January 6-9, 2026 (if implementing Option A)
- **Status**: Waiting for assignment

---

## Notes

- This is a **source code issue** in the example application
- Not a deployment or infrastructure problem
- Bootstrap script is working correctly (as designed)
- Affects both the original example and any deployments based on it
- Secondary fallback image issue affects 3 different admin components

---

## Checklist for Resolution

- [ ] Decision made: Which solution option to implement
- [ ] Thumbnail files created (if Option A)
- [ ] Seed data updated (if Option A)
- [ ] Frontend fallback image fixed (if Option C)
- [ ] Bootstrap re-run or frontend re-built
- [ ] Testing completed
- [ ] Admin dashboard verified
- [ ] Documentation updated if needed

---
