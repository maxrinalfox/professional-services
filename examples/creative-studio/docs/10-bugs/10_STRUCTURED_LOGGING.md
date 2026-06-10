# Bug Report: Logging Not Fully Structured

**Bug ID**: BUG-010
**Status**: 🟢 Low Priority
**Severity**: Low
**Component**: Backend / Operations / Logging
**Reported**: December 17, 2025

---

## Summary

Logs are not consistently structured in JSON format, field naming is inconsistent across logs, and it's difficult to filter logs by context/user/workspace.

---

## Detailed Description

### Issues

1. **Not Structured JSON**
   - Mix of JSON and text logs
   - Hard to parse/filter
   - Inconsistent format

2. **Field Naming Inconsistency**
   - Some logs use `user_id`, others use `userId`
   - Some use `request_id`, others use `trace_id`
   - Hard to correlate logs
   - Makes queries complex

3. **No Context Propagation**
   - Can't track request through system
   - Hard to correlate frontend/backend logs
   - Debugging requires manual tracing

4. **Filtering Difficult**
   - Can't easily find all logs for a user
   - Can't easily find all logs for a workspace
   - Search requires complex regex

---

## Root Cause

- Logging implemented ad-hoc without standards
- No structured logging library
- No logging guidelines enforced

---

## Solution Options

### Option A: Add Structured Logging Library (1 week)
- Use `python-json-logger` or `structlog`
- Convert all log statements
- Standardize fields

### Option B: Add Context Propagation (1 week)
- Use request context (context-local)
- Propagate user/workspace/request IDs
- Include in all logs automatically

### Option C: Comprehensive (2 weeks)
- Both approaches
- Add log monitoring/alerting
- Create log filtering guides

---

## Recommendation

**Implement Option C** - comprehensive logging:
1. Add structured logging library
2. Implement context propagation
3. Standardize field names
4. Add monitoring

---

## Technical Details

### Standard Log Fields
```json
{
  "timestamp": "2026-01-02T12:00:00Z",
  "level": "INFO",
  "logger": "module.name",
  "message": "User logged in",
  "request_id": "uuid",
  "user_id": "user123",
  "workspace_id": "workspace456",
  "action": "login",
  "duration_ms": 123,
  "status": "success"
}
```

### Field Naming Standards
- `request_id` (not `trace_id`, `correlation_id`)
- `user_id` (not `userId`, `uid`)
- `workspace_id` (not `workspaceId`)
- `action` (not `operation`, `event_type`)
- `duration_ms` (not `duration`, `elapsed_time`)

---

## Testing

- All logs are valid JSON
- All required fields present
- Logs filterable by user/workspace
- Context propagates correctly
- Monitoring queries work

---

## Timeline

- **Reported**: December 17, 2025
- **Expected Duration**: 2 weeks
- **Status**: Low priority, can wait

---

## Checklist for Resolution

- [ ] Structured logging library chosen
- [ ] Library integrated
- [ ] Field naming standards defined
- [ ] All logs updated
- [ ] Context propagation implemented
- [ ] Monitoring configured
- [ ] Documentation written
- [ ] Testing complete
- [ ] Deployment complete

---
