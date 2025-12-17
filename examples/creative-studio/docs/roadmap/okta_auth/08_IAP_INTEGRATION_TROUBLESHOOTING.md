# IAP Integration Troubleshooting: JWT Audience Mismatch

**Status**: Issue Resolution Guide
**Last Updated**: December 17, 2025
**Problem**: `Invalid bearer token. Invalid jwt audience.` error when IAP enabled

---

## The Error

When IAP is enabled on Cloud Run backend and frontend makes API requests:

```
Error: invalid iap credentials: Invalid bearer token. Invalid jwt audience.
```

This appears to be an IAP error, but it's actually a **token validation failure** in the application code, not IAP itself.

---

## Root Cause Analysis

### Three JWT Tokens Involved

When IAP is enabled, three different JWT tokens are in play:

```
1. Frontend Gets: Google Identity Platform Token
   ├─ Audience: Firebase Project ID (e.g., "my-project-123")
   ├─ Issuer: https://securetoken.google.com/my-project-123
   └─ Source: google.accounts.id API or Firebase SDK

2. Frontend Sends: Authorization: Bearer [Above Token]
   └─ Backend receives this and validates

3. IAP Adds: X-Goog-IAP-JWT-Assertion: [IAP-specific JWT]
   ├─ Audience: IAP service
   ├─ Issued by: IAP service
   └─ Backend IGNORES this (doesn't look for it)
```

### Where the Failure Happens

```
┌─ Frontend gets Google token ─┐
│ Audience: "my-project-123"   │
│                              │
├─→ Frontend sends to backend  │
│                              │
├─→ IAP intercepts request     │
│   (checks group membership)  │
│   (adds X-Goog-IAP header)  │
│                              │
├─→ Request reaches backend    │
│                              │
├─→ Backend receives token     │
│                              │
├─→ Backend validates token    │
│   ❌ Expects audience = GOOGLE_TOKEN_AUDIENCE (OAuth Client ID)
│   ✓ But token has audience = Firebase Project ID
│   │
│   ▼
│   VALIDATION FAILS
│   "Invalid jwt audience."
│
└─ Error returned to frontend ─┘
```

### Why It Works Without IAP

Without IAP:
- Frontend sends token to backend directly
- Backend validates with Firebase Admin SDK
- Firebase Admin SDK uses **internal validation** (doesn't check audience strictly)
- Request succeeds

With IAP:
- Request goes through IAP layer first
- IAP adds headers and forwards to backend
- Backend still validates the original token
- **Audience mismatch now matters** (IAP passes through, but backend fails)

---

## The Configuration Problem

### Backend Token Audience Setup

**File**: `backend/src/config/config_service.py`

```python
GOOGLE_TOKEN_AUDIENCE: str = ""  # OAuth 2.0 Client ID from Google Cloud Console
```

**File**: `backend/src/auth/auth_guard.py` (lines 63-72)

```python
if config_service.ENVIRONMENT == "local":
    # Local: Firebase Admin SDK (lenient audience check)
    decoded_token = await asyncio.to_thread(auth.verify_id_token, token)
else:
    # Production: Google Identity Platform (strict audience check)
    GOOGLE_TOKEN_AUDIENCE = config_service.GOOGLE_TOKEN_AUDIENCE
    decoded_token = await asyncio.to_thread(
        id_token.verify_oauth2_token,
        token,
        google_auth_requests.Request(),
        audience=GOOGLE_TOKEN_AUDIENCE,  # ← STRICT AUDIENCE CHECK
    )
```

### Frontend Token Audience

**File**: `frontend/src/app/common/services/auth.service.ts`

The frontend gets tokens from:
1. **Firebase SDK** (`signInWithPopup`) → Audience = Firebase Project ID
2. **Google Identity Platform** (`google.accounts.id.prompt`) → Audience = Google Client ID

But the frontend **doesn't control the audience** - it's determined by how the token was created.

### The Mismatch

```
Scenario 1: Local Dev (Works)
├─ Frontend: Uses Firebase SDK
├─ Token audience: Firebase Project ID
├─ Backend: Uses Firebase Admin SDK (doesn't check audience)
└─ Result: ✅ WORKS

Scenario 2: Production Without IAP (Might Work)
├─ Frontend: Uses google.accounts.id
├─ Token audience: Google OAuth Client ID
├─ Backend: Expects GOOGLE_TOKEN_AUDIENCE (Client ID)
├─ GOOGLE_TOKEN_AUDIENCE: Set to Client ID in .env
└─ Result: ✅ WORKS

Scenario 3: Production With IAP (FAILS)
├─ Frontend: Uses google.accounts.id
├─ Token audience: Google OAuth Client ID
├─ IAP: Intercepts, checks group, forwards
├─ Backend: Expects GOOGLE_TOKEN_AUDIENCE (Client ID)
├─ GOOGLE_TOKEN_AUDIENCE: Empty string "" in .env
│  (Not set because IAP was supposed to handle auth)
└─ Result: ❌ FAILS - Invalid audience
```

---

## The Solution

### Three Options

#### Option 1: Configure GOOGLE_TOKEN_AUDIENCE (Recommended)

Set the OAuth Client ID in backend environment:

**Backend `.env` or Cloud Run environment variable**:

```bash
GOOGLE_TOKEN_AUDIENCE=YOUR_GOOGLE_OAUTH_CLIENT_ID.apps.googleusercontent.com
```

**Where to find YOUR_GOOGLE_OAUTH_CLIENT_ID**:
1. Go to Google Cloud Console
2. APIs & Services → Credentials
3. Find "OAuth 2.0 Client IDs" of type "Web application"
4. Copy the "Client ID" field
5. It looks like: `12345678-abcd-1234-abcd-1234567890.apps.googleusercontent.com`

**Why this works**:
- Frontend sends Google Identity Platform token (audience = Client ID)
- Backend validates with Google Identity Platform (expects Client ID)
- Audience matches ✅

**Updated auth_guard.py behavior**:

```python
# Production environment
GOOGLE_TOKEN_AUDIENCE = config_service.GOOGLE_TOKEN_AUDIENCE  # "12345...apps.googleusercontent.com"

decoded_token = await asyncio.to_thread(
    id_token.verify_oauth2_token,
    token,
    google_auth_requests.Request(),
    audience=GOOGLE_TOKEN_AUDIENCE,  # ✅ Now matches frontend token audience
)
```

---

#### Option 2: Use Firebase Admin SDK (If Firebase Auth Chosen)

If Phase 1 decision was **Firebase Authentication**, use Firebase Admin SDK validation:

**Backend auth_guard.py**:

```python
# Use Firebase Admin SDK everywhere
decoded_token = await asyncio.to_thread(
    auth.verify_id_token,
    token  # Firebase SDK doesn't require audience parameter
)
```

**Pros**:
- Firebase Admin SDK handles audience internally
- Works with Firebase tokens
- Simpler validation

**Cons**:
- Requires Phase 1 decision to be Firebase
- Won't work if switching to pure OIDC later

---

#### Option 3: Disable Strict Audience Check (Not Recommended)

Don't enforce audience validation:

```python
# INSECURE - Only for debugging
decoded_token = await asyncio.to_thread(
    id_token.verify_oauth2_token,
    token,
    google_auth_requests.Request(),
    # audience=None  # Don't check audience (INSECURE)
)
```

**⚠️ Security Risk**:
- Accepts tokens from ANY Google application
- Token could be issued for different audience
- Opens to token reuse attacks

**Only use for temporary debugging, never in production.**

---

## Step-by-Step Fix

### Step 1: Find Your OAuth Client ID

```bash
# Google Cloud Console
gcloud iam service-accounts list --filter="displayName:Creative Studio"
gcloud oauth-config list  # May not work on all gcloud versions

# Alternative: Use Google Cloud Console UI
# APIs & Services → Credentials → OAuth 2.0 Client IDs → Web application
```

### Step 2: Update Backend Environment

**For Local Development**:

Edit `backend/.env`:

```bash
GOOGLE_TOKEN_AUDIENCE=YOUR_CLIENT_ID.apps.googleusercontent.com
ENVIRONMENT=development  # or "production"
```

**For Cloud Run**:

```bash
gcloud run deploy creative-studio \
  --update-env-vars GOOGLE_TOKEN_AUDIENCE=YOUR_CLIENT_ID.apps.googleusercontent.com
```

Or update via Terraform:

```hcl
# infra/main.tf or similar
resource "google_cloud_run_v2_service" "creative_studio" {
  template {
    containers {
      env {
        name  = "GOOGLE_TOKEN_AUDIENCE"
        value = var.google_oauth_client_id  # "12345...apps.googleusercontent.com"
      }
    }
  }
}
```

### Step 3: Verify Frontend Configuration

**Ensure frontend is using Google Identity Platform**:

File: `frontend/src/app/common/services/auth.service.ts`

Should call `promptForIdentityPlatformToken$()` in production:

```typescript
signInForGoogleIdentityPlatform(): Observable<string> {
  return this.promptForIdentityPlatformToken$().pipe(
    // Uses google.accounts.id API
    // Issues Google OAuth 2.0 token
    // Audience = Google Client ID
  );
}
```

**Verify frontend environment has GOOGLE_CLIENT_ID**:

File: `frontend/src/environments/environment.prod.ts`

```typescript
export const environment = {
  // ...
  GOOGLE_CLIENT_ID: 'YOUR_CLIENT_ID.apps.googleusercontent.com',
  backendURL: 'https://YOUR_DOMAIN/api',  // Via IAP
};
```

### Step 4: Test

**Test without IAP first**:

```bash
# Deploy without IAP
terraform apply -var="use_lb=false" -var="iap_enabled=false"

# Try API call
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/workspaces
# Should work ✅
```

**Test with IAP**:

```bash
# Deploy with IAP
terraform apply -var="use_lb=true"

# Try API call through load balancer
curl -H "Authorization: Bearer $TOKEN" \
  https://YOUR_DOMAIN/api/workspaces
# Should work ✅
```

---

## Debugging Checklist

### Frontend Side

- [ ] Check browser console for token details
- [ ] Verify `GOOGLE_CLIENT_ID` in environment
- [ ] Confirm using `google.accounts.id` API (not Firebase SDK in production)
- [ ] Check token payload: `jwt.io` paste the token
  - Look for `"aud": "CLIENT_ID.apps.googleusercontent.com"`

**Debug JavaScript**:

```typescript
// In auth.service.ts or console
const token = 'your_jwt_token';
const payload = JSON.parse(atob(token.split('.')[1]));
console.log('Token audience:', payload.aud);
console.log('Token issuer:', payload.iss);
console.log('Token expiry:', new Date(payload.exp * 1000));
```

### Backend Side

- [ ] Check `GOOGLE_TOKEN_AUDIENCE` environment variable
  - `echo $GOOGLE_TOKEN_AUDIENCE`
- [ ] Verify it matches frontend's Client ID
- [ ] Enable debug logging in auth_guard.py
- [ ] Check Cloud Run logs for error details

**Debug Python**:

```python
# In auth_guard.py, add after token reception
logger.info(f"Token audience: {decoded_token.get('aud')}")
logger.info(f"Expected audience: {config_service.GOOGLE_TOKEN_AUDIENCE}")
logger.info(f"Token issuer: {decoded_token.get('iss')}")
```

**View Cloud Run Logs**:

```bash
gcloud run logs read creative-studio --limit=50
```

---

## Common Error Messages and Solutions

### Error: "Invalid jwt audience."

**Cause**: `GOOGLE_TOKEN_AUDIENCE` not set or wrong value

**Solution**:
1. Get correct Client ID from Google Cloud Console
2. Set `GOOGLE_TOKEN_AUDIENCE=YOUR_CLIENT_ID.apps.googleusercontent.com`
3. Redeploy backend

---

### Error: "Invalid bearer token."

**Cause**: Token format wrong or already expired

**Solution**:
1. Frontend: Check if token is being sent correctly in Authorization header
2. Backend: Verify token is not expired
3. Check logs for specific error

---

### Error: "Forbidden: User identity could not be confirmed from token."

**Cause**: Token doesn't have email claim

**Solution**:
1. Verify email scope is requested in frontend
2. Check token payload includes `"email"` claim
3. May need to reauthenticate user

---

### Error: "Invalid signature."

**Cause**: Token signature doesn't match issuer's public key

**Solution**:
1. Verify token is from correct issuer (check `iss` claim)
2. Ensure backend has access to issuer's public keys
3. Check system clock synchronization (time skew)

---

## How IAP Fits In

### IAP Does NOT Validate Bearer Token

Key understanding:

```
IAP's Job:
├─ Check if user in IAM group ✅
├─ Add X-Goog-IAP-JWT-Assertion header ✅
└─ Forward request to backend ✅

IAP's NOT Job:
├─ Validate Bearer token ❌
├─ Check Bearer token audience ❌
└─ Handle bearer token errors ❌
```

**Bearer token validation is ALWAYS backend responsibility.**

### Token Flow With IAP

```
Frontend
  ├─ Gets Google token (audience = Client ID)
  └─ Adds: Authorization: Bearer [token]

IAP
  ├─ Intercepts request
  ├─ Checks X-Goog-IAP-JWT-Assertion (from user login)
  ├─ Verifies user in IAM group
  ├─ Adds its own X-Goog-IAP-JWT-Assertion header
  └─ Forwards Authorization header UNCHANGED

Backend
  ├─ Receives both headers
  ├─ **VALIDATES Bearer token audience** ← This is where it can fail
  └─ Creates response
```

---

## IAP Headers in Backend (Optional Verification)

Backend CAN optionally verify IAP header to double-check:

```python
from fastapi import Header, HTTPException

@router.get("/api/workspaces")
async def list_workspaces(
    current_user: UserModel = Depends(get_current_user),
    # Optional: Verify IAP assertion (if extra paranoid)
    iap_jwt: str = Header(None, alias="X-Goog-IAP-JWT-Assertion")
):
    if not iap_jwt:
        logger.warning("Request missing IAP header (not protected by IAP?)")
        # Could reject here if you want ONLY IAP-protected access
        # raise HTTPException(status_code=403, detail="Not protected by IAP")

    return await workspace_service.list_workspaces_for_user(current_user)
```

But this is **optional** - the Bearer token validation is sufficient.

---

## Prevention: Configuration Checklist

### Before Enabling IAP

- [ ] GOOGLE_TOKEN_AUDIENCE is set in backend
- [ ] GOOGLE_TOKEN_AUDIENCE = OAuth 2.0 Client ID
- [ ] Frontend environment.ts has GOOGLE_CLIENT_ID (same value)
- [ ] Frontend uses google.accounts.id API (production)
- [ ] Test API call WITHOUT IAP works
- [ ] Then enable IAP

### When Enabling IAP

- [ ] Understand IAP doesn't validate Bearer token
- [ ] Understand Bearer token validation is backend responsibility
- [ ] Set GOOGLE_TOKEN_AUDIENCE correctly before IAP deployment

---

## Summary

| Component | Responsibility | When It Fails |
|-----------|----------------|----|
| Frontend | Get Google token with correct Client ID | Token has wrong audience |
| IAP | Check group membership | User not in group (different error) |
| Backend | Validate Bearer token audience | GOOGLE_TOKEN_AUDIENCE not set or wrong |

**Fix**: Set `GOOGLE_TOKEN_AUDIENCE` to your OAuth Client ID in backend environment.

---

## Related Documentation

- **Parent**: `07_IAP_AUTHORIZATION_LAYER.md` - IAP architecture overview
- **Parent**: `06_PHASE1_TWO_ALTERNATIVES.md` - Authentication choices
- **Related**: `../../../03-backend/03_AUTHENTICATION_FLOW.md` - Backend auth details
- **Related**: Terraform: `/vertex-ai-creative-studio/main.tf` - Working IAP setup

---

## Document Information

- **Last Updated**: December 17, 2025
- **Applies To**: Creative Studio with IAP enabled + Google Identity Platform
- **Version**: 1.0
