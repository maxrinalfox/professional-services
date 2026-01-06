# Firebase Hosting Proxy for CORS Resolution

## Problem Summary

Frontend was making **direct API calls to Cloud Run backend**, causing CORS preflight failures:

- Browser sends unauthenticated OPTIONS preflight request
- Cloud Run returns 403 Forbidden (authentication required)
- Browser blocks all subsequent API requests
- Application cannot communicate with backend

## Root Cause

The frontend configuration was set to use the **direct Cloud Run backend URL**:
```
https://cstudio-backend-development-PROJECT_NUMBER.us-central1.run.app
```

Instead of the **Firebase Hosting proxy URL**:
```
https://YOUR_PROJECT_ID.web.app
```

This caused cross-origin requests that triggered CORS preflight failures.

## Solution

Changed the `_BACKEND_URL` substitution in Terraform from the Cloud Run backend URL to the Firebase Hosting frontend URL. This enables the Firebase Hosting proxy/rewrite mechanism to route requests to the actual backend.

**Commit:** `014297313`

**File Modified:** `infra/modules/platform/main.tf` (line 366)

```hcl
# BEFORE
_BACKEND_URL = local.backend_url

# AFTER
_BACKEND_URL = local.frontend_url
```

## How It Works

### Architecture

```
Browser Request Flow:

BEFORE (Direct - CORS Issue):
  Browser → Cloud Run (cross-origin request)
          → Browser blocks with CORS error

AFTER (Via Proxy - No CORS):
  Browser → Firebase Hosting (same-origin)
         → Firebase routes to Cloud Run (via firebase.json rewrite)
         → No CORS preflight needed
```

### Component Interaction

1. **Frontend Application** (`environment.prod.ts`)
   - Configured via `_BACKEND_URL` substitution
   - Calls: `https://YOUR_PROJECT_ID.web.app/api/*`
   - From browser perspective: same-origin request

2. **Firebase Hosting** (`firebase.json`)
   - Rewrite rule configured in source code
   - Pattern: `/api/**` → Cloud Run service
   - Service ID via `_BACKEND_SERVICE_ID` substitution
   - Transparently routes to actual backend

3. **Cloud Run Backend**
   - Receives requests from Firebase proxy
   - No CORS preflight needed
   - Token validation and authorization still applied

### Request Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Browser                              │
│                                                               │
│  GET /api/users/me (same-origin to Firebase Hosting)       │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│              Firebase Hosting (YOUR_PROJECT_ID)               │
│                                                               │
│  1. Receives request to /api/**                             │
│  2. Matches rewrite rule in firebase.json                   │
│  3. Rewrites to Cloud Run service:                          │
│     serviceId: cstudio-backend-development                  │
│  4. Forwards request to backend                             │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│              Cloud Run Backend Service                       │
│                                                               │
│  1. Receives rewritten request                              │
│  2. Validates authorization headers                         │
│  3. Processes request                                        │
│  4. Returns response                                         │
└────────────────────────────┬────────────────────────────────┘
                             │
                    ◄────────┴───────────►
                Response returned to browser
```

## Implementation Details

### Terraform Variables

**Before:**
```hcl
build_substitutions = {
  _BACKEND_URL         = local.backend_url                    # Cloud Run URL
  _BACKEND_SERVICE_ID  = local.backend_service_name           # Service name
  # ... other substitutions
}
```

**After:**
```hcl
build_substitutions = {
  _BACKEND_URL         = local.frontend_url                   # Firebase URL
  _BACKEND_SERVICE_ID  = local.backend_service_name           # Service name (unchanged)
  # ... other substitutions
}
```

### Cloud Build Injection

Cloud Build injects variables into two separate files:

1. **environment.prod.ts** (Angular frontend configuration)
   ```bash
   sed -i "s|BACKEND_URL_PLACEHOLDER|${BACKEND_URL}/api|g" src/environments/environment.prod.ts
   ```
   Result: `backendURL: 'https://YOUR_PROJECT_ID.web.app/api'`

2. **firebase.json** (Firebase Hosting configuration)
   ```bash
   sed -i "s|BACKEND_SERVICE_ID_PLACEHOLDER|${BACKEND_SERVICE_ID}|g" firebase.json
   ```
   Result: `"serviceId": "cstudio-backend-development"`

### No Conflicts

The two variables use separate placeholders and target different files:
- `_BACKEND_URL` → `BACKEND_URL_PLACEHOLDER` → `environment.prod.ts`
- `_BACKEND_SERVICE_ID` → `BACKEND_SERVICE_ID_PLACEHOLDER` → `firebase.json`

No overwriting or conflicts occur.

## Deployment

### 1. Apply Terraform

```bash
cd infra/environments/<your-environment>
unset GOOGLE_APPLICATION_CREDENTIALS
terraform apply
```

### 2. Trigger Frontend Cloud Build

```bash
git push origin features_docs
```

The push triggers Cloud Build automatically, which:
- Fetches substitution variables from Terraform
- Injects `_BACKEND_URL` into Angular environment file
- Injects `_BACKEND_SERVICE_ID` into firebase.json
- Builds and deploys frontend to Firebase Hosting

### 3. Verification

**In Browser DevTools:**

1. Open https://YOUR_PROJECT_ID.web.app
2. Press F12 → Network tab
3. Make an API call (login, fetch data, etc.)
4. Check Request URL in Network tab:
   - ✅ Should show: `https://YOUR_PROJECT_ID.web.app/api/...`
   - ❌ Should NOT show: Cloud Run direct URL

5. Verify no CORS errors:
   - No OPTIONS preflight requests with 403 errors
   - All requests return 200 or expected status codes
   - No CORS errors in browser console

## Benefits

1. **Eliminates CORS Issues**
   - No cross-origin requests from browser
   - No CORS preflight failures
   - Browser sees same-origin requests

2. **Cleaner Architecture**
   - Frontend doesn't know about backend URL
   - Frontend knows about proxy endpoint only
   - Backend location is decoupled from frontend

3. **Improved Maintainability**
   - Single point of routing configuration (firebase.json)
   - Firebase Hosting handles proxy logic
   - No complex CORS header configuration needed

4. **Better Security**
   - Hides actual backend URL from browser
   - All requests go through Firebase proxy
   - Custom audiences token validation still applied

## Best Practices

### ✅ DO: Use Firebase Hosting Proxy

When using Firebase Hosting with Cloud Run backends:
- Configure API endpoint in frontend to use Firebase Hosting URL
- Configure firebase.json rewrite rules to route to actual backend
- Let Firebase handle the proxy layer

### ❌ DON'T: Call Backend Directly

Don't configure frontend to call Cloud Run directly:
- Creates cross-origin requests
- Requires CORS preflight handling
- Exposes backend URL to browser
- More complex security configuration

### Configuration Guidelines

**Frontend should use:**
```typescript
backendURL: 'https://[firebase-project-id].web.app/api'
```

**firebase.json should have:**
```json
{
  "rewrites": [
    {
      "source": "/api/**",
      "run": {
        "serviceId": "[cloud-run-service-name]",
        "region": "[region]"
      }
    }
  ]
}
```

**Backend can continue using:**
- Custom audiences for token validation
- CORS headers for legitimate cross-origin scenarios
- Any other security measures

## References

- **Commit:** `014297313`
- **File Changed:** `infra/modules/platform/main.tf`
- **Related Files:**
  - `frontend/src/environments/environment.prod.ts` (where _BACKEND_URL is injected)
  - `frontend/firebase.json` (where _BACKEND_SERVICE_ID is injected)
  - `frontend/cloudbuild-deploy.yaml` (how variables are injected)

## Related Topics

- **Custom Audiences:** Still configured for token validation (separate concern)
- **CORS Configuration:** Can remain in backend for other cross-origin clients
- **Firebase Hosting:** See [Firebase Hosting Documentation](https://firebase.google.com/docs/hosting)
- **Cloud Run:** See [Cloud Run Documentation](https://cloud.google.com/run/docs)
