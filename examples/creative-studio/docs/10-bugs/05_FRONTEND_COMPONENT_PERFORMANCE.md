# Bug Report: Frontend Component Performance & Memory Leaks

**Bug ID**: BUG-005
**Status**: 🔴 Open
**Severity**: Medium
**Component**: Frontend / Performance
**Reported**: December 17, 2025

---

## Summary

Frontend components may have memory leaks from unsubscribed RxJS observables, unoptimized image loading, and missing virtual scrolling in large galleries.

---

## Detailed Description

### Issues Identified

1. **RxJS Subscription Leaks**
   - Components not unsubscribing on destroy
   - Memory increases over time
   - Each navigation adds subscriptions

2. **Missing Virtual Scrolling**
   - Large galleries load all items
   - Performance degrades with many media items
   - Scrolling becomes laggy
   - Memory usage unbounded

3. **Image Loading Not Optimized**
   - No lazy loading implemented
   - All images loaded upfront
   - High bandwidth usage
   - Slow initial page load
   - Battery drain on mobile

4. **Firestore Listeners**
   - Not cleaned up on component destroy
   - Multiple listeners accumulate
   - Real-time updates cause issues

---

## Root Cause

- No subscription management best practices
- No performance optimization for galleries
- Image optimization not prioritized
- Firestore setup without cleanup

---

## How to Replicate

1. Open gallery component
2. Scroll through many items
3. Navigate away and back multiple times
4. Check DevTools Memory tab
5. **Result**: Memory usage increases

---

## Solution Options

### Option A: RxJS Subscription Management (1 week)
- Use `takeUntil` pattern with destroy subject
- Use async pipe in templates
- Audit all components

### Option B: Virtual Scrolling (1 week)
- Implement `CDK Virtual Scroll`
- Load items on demand
- Fixed viewport

### Option C: Image Optimization (2 weeks)
- Implement lazy loading
- Add image compression
- Progressive JPEG loading

### Option D: Comprehensive Fix (2-3 weeks)
- Implement all three options
- Add performance monitoring
- Test with large datasets

---

## Recommendation

**Implement Option D** - comprehensive approach:
1. Start with RxJS cleanup (quick wins)
2. Add virtual scrolling to galleries
3. Implement image optimization

---

## Technical Details

### Files Affected
- `frontend/src/app/gallery/` components
- `frontend/src/app/admin/media-templates-management/`
- `frontend/src/app/admin/source-assets-management/`
- All components with Firestore listeners

### RxJS Pattern (Fix)
```typescript
// Current (Wrong)
this.service.data$.subscribe(d => this.data = d);

// Fixed
private destroy$ = new Subject<void>();

ngOnInit() {
  this.service.data$
    .pipe(takeUntil(this.destroy$))
    .subscribe(d => this.data = d);
}

ngOnDestroy() {
  this.destroy$.next();
  this.destroy$.complete();
}
```

---

## Testing

- Memory profiling before/after
- Performance metrics collection
- Gallery scrolling with 1000+ items
- Mobile performance testing
- Network throttling tests

---

## Timeline

- **Reported**: December 17, 2025
- **Expected Duration**: 2-3 weeks
- **Status**: Waiting for assignment

---

## Checklist for Resolution

- [ ] RxJS subscriptions audited
- [ ] takeUntil pattern implemented
- [ ] Virtual scrolling added
- [ ] Image lazy loading implemented
- [ ] Performance metrics baseline
- [ ] Tests passing
- [ ] Monitoring added
- [ ] Deployment complete

---
