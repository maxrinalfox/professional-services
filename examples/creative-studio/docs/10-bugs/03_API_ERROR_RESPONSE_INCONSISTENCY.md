# Bug Report: API Error Response Inconsistency

**Bug ID**: BUG-003
**Status**: 🔴 Open
**Severity**: Medium
**Component**: Backend / API
**Reported**: December 17, 2025
**Assigned**: Unassigned

---

## Summary

API endpoints return inconsistent error responses and HTTP status codes, making client-side error handling difficult and increasing debugging time.

---

## Detailed Description

### The Problem

API endpoints have inconsistent error handling patterns:

1. **Inconsistent Status Codes**
   - Some endpoints return 500 for invalid input (should be 400)
   - Some endpoints return 422 for missing fields (should be 400)
   - Some endpoints return 500 for auth failures (should be 401)

2. **Inconsistent Error Format**
   - Some return: `{ "error": "message" }`
   - Some return: `{ "detail": "message" }`
   - Some return: `{ "message": "message" }`
   - Some return raw exception text

3. **Missing Validation**
   - Some endpoints don't validate required fields
   - Pydantic models not enforcing all constraints
   - Custom validation not documented

4. **Security Issues**
   - Some errors expose internal details
   - Stack traces returned in production
   - Database error messages exposed

### Examples

**Endpoint 1**: GET `/api/workspaces/{id}`
```json
// Invalid ID
Status: 500
{
  "detail": "SQLAlchemy error: Table 'workspaces' not found",
  "traceback": "..."
}
```

**Endpoint 2**: POST `/api/media-templates`
```json
// Missing required field
Status: 422
{
  "detail": [
    {
      "loc": ["body", "name"],
      "msg": "field required"
    }
  ]
}
```

**Endpoint 3**: POST `/api/users`
```json
// Invalid email
Status: 500
{
  "error": "Invalid email format",
  "exception": "ValueError"
}
```

---

## Root Cause

**No standardized error handling**:
- Each endpoint written independently
- Pydantic validation inconsistent
- No global error handler
- Missing pre-request validation layer
- No documented error response contract

---

## How to Replicate

### Test Case 1: Invalid Input
1. POST `/api/workspace` with missing `name` field
2. Observe status code and error format
3. Compare with other POST endpoints
4. **Result**: Different formats and status codes

### Test Case 2: Invalid Auth
1. Make request with invalid JWT token
2. Compare response with missing auth header
3. Compare response with expired token
4. **Result**: Inconsistent handling

### Test Case 3: Resource Not Found
1. GET `/api/workspaces/999999` (doesn't exist)
2. Compare with GET `/api/media-templates/999999`
3. **Result**: Different status codes (404 vs 500)

---

## Impact Assessment

### Affected Users
- Frontend developers building error handling
- API consumers/third-party integrations
- Support team debugging issues

### Business Impact
- Poor developer experience
- Harder to debug issues
- Security concern (exposing internals)
- Harder to maintain consistent client behavior

---

## Solution Options

### Option A: Standardize with Pydantic Validation
**Effort**: 1 week
**Complexity**: Medium

1. Create standard Pydantic model for all error responses
2. Use Pydantic field validators in all models
3. Add pre-request validation middleware
4. Document all valid error codes

**Pros**: Leverages existing Pydantic setup, cleaner code
**Cons**: Requires changes to all models

---

### Option B: Global Exception Handler
**Effort**: 2 weeks
**Complexity**: High

1. Create custom exception classes
2. Implement global exception handler
3. Map exceptions to standard responses
4. Add logging/monitoring

**Pros**: Catches all cases consistently
**Cons**: More infrastructure code

---

### Option C: Hybrid Approach (Recommended)
**Effort**: 2 weeks
**Complexity**: Medium-High

1. Create standard error response model
2. Implement Pydantic field validation
3. Add global exception handler
4. Document error codes per endpoint
5. Add validation helper functions

---

## Recommendation

**Implement Option C** - provides comprehensive error handling without over-engineering.

---

## Technical Details

### Files Affected
- `backend/src/common/exceptions.py` - Custom exceptions
- `backend/src/common/schemas.py` - Error response models
- `backend/src/api/` - All endpoints
- `backend/main.py` - Exception handlers

### Standard Error Response

```python
class ErrorResponse(BaseModel):
    status: int  # HTTP status code
    code: str  # Machine-readable error code
    message: str  # Human-readable message
    details: Optional[List[dict]] = None  # Field-specific errors
    timestamp: datetime = Field(default_factory=datetime.utcnow)
```

### Standard Error Codes

```
400 - BAD_REQUEST: Invalid input
401 - UNAUTHORIZED: Missing/invalid auth
403 - FORBIDDEN: User lacks permission
404 - NOT_FOUND: Resource doesn't exist
422 - UNPROCESSABLE_ENTITY: Validation error
500 - INTERNAL_ERROR: Server error
```

---

## Testing

### Pre-fix
1. Document current error patterns per endpoint
2. Create test matrix of error cases
3. Verify inconsistencies

### Post-fix
1. All endpoints return standard format
2. Status codes match HTTP standards
3. No internal details exposed
4. Field validation errors consistent
5. Unit tests for each error type

---

## Timeline

- **Reported**: December 17, 2025
- **Expected Duration**: 2 weeks
- **Status**: Waiting for assignment

---

## Related Issues

- **BUG-002**: Authentication errors (part of this)
- **Affects**: Frontend error handling consistency

---

## Checklist for Resolution

- [ ] Standard error response model defined
- [ ] Custom exception classes created
- [ ] Global exception handler implemented
- [ ] All endpoints updated
- [ ] Documentation written
- [ ] Tests updated
- [ ] Security review passed
- [ ] Production deployment

---
