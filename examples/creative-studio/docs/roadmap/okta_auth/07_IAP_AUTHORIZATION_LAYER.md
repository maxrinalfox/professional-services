# Identity-Aware Proxy (IAP) as Secondary Authorization Layer

**Status**: Alternative Security Pattern for Cloud Run
**Last Updated**: December 17, 2025
**Context**: Complementary to Phase 1 authentication choices

> **Note**: This document describes an alternative authorization approach found in the secondary Creative Studio application at `/vertex-ai-creative-studio/`. This can be used in combination with either Phase 1 choice (Firebase or Pure OIDC).

---

## The Problem This Solves

Creative Studio deployment has three configuration challenges:

### Current Approach Issues

**Option 1: External Application** (Allow all Google users)
- ✅ No manual user provisioning needed
- ❌ ANY Google user can sign in and access backend
- ❌ No built-in access control
- ❌ Security relies entirely on authentication strength

**Option 2: Internal Application** (Restrict to 100 manual users)
- ✅ Limited user access via GCP IAM
- ❌ Must manually add/remove users up to 100 limit
- ❌ No integration with company directory/groups
- ❌ Operational burden on manual user management
- ❌ Doesn't scale if user base grows

**Option 3: IAP-Based Authorization** (This Document)
- ✅ Allow all Google users to authenticate
- ✅ Backend protected via Cloud Run IAP
- ✅ Access control via IAM groups (managed by specialized team)
- ✅ No manual user provisioning at application level
- ✅ Scales to thousands of users
- ✅ Integrates with company identity infrastructure

---

## How Identity-Aware Proxy Works

### Architecture Overview

```
User Browser
    │
    ├─→ (Any Google Account)
    │
    ▼
Frontend Application
    │
    ├─ Signs in with Google OAuth
    ├─ Gets ID token (unrestricted access to frontend)
    │
    ▼
Cloud Run Backend (Protected by IAP)
    │
    ├─→ IAP intercepts request
    ├─→ Checks if user in IAM group
    │
    ├─ If YES: Forward to backend + add auth headers
    │  └─→ Backend processes request normally
    │
    └─ If NO: Reject with 403 Forbidden
       └─→ Request never reaches application code
```

### Three Layer Security Model

```
Layer 1: Frontend Authentication
┌─────────────────────────────────────────┐
│ User signs in with Google               │
│ Gets ID token                           │
│ Frontend runs normally                  │
│ (No backend access check yet)           │
└─────────────────────────────────────────┘
              ↓
Layer 2: IAP Authorization (External Layer)
┌─────────────────────────────────────────┐
│ IAP intercepts Cloud Run requests       │
│ Verifies user is in allowed IAM group   │
│ Adds X-Goog-IAP-JWT-Assertion header    │
└─────────────────────────────────────────┘
              ↓
Layer 3: Backend Authorization (Optional)
┌─────────────────────────────────────────┐
│ Backend verifies IAP header              │
│ Checks user roles/workspace access      │
│ Applies application-level RBAC          │
└─────────────────────────────────────────┘
```

---

## Implementation in Secondary App

The secondary Creative Studio at `/vertex-ai-creative-studio/` implements IAP like this:

### 1. Two Deployment Modes

**Mode A: With Load Balancer + IAP** (Recommended for Production)

```hcl
variable "use_lb" {
  description = "Run load balancer on HTTPS and provision managed certificate"
  type        = bool
  default     = true
}
```

When `use_lb = true`:
- Load balancer fronts Cloud Run
- IAP enabled on load balancer backend
- SSL/TLS managed automatically
- Custom domain supported

**Mode B: Direct Cloud Run + IAP** (Simple for Dev)

```hcl
# When use_lb = false
iap_enabled = !var.use_lb  # IAP on Cloud Run directly
```

When `use_lb = false`:
- Cloud Run exposed directly with IAP
- No load balancer overhead
- Still protected by IAP
- Good for development/testing

### 2. IAP Service Account Setup

```hcl
# Explicit IAP service account provisioning
# (sometimes not auto-created, so terraform ensures it exists)
resource "google_project_service_identity" "iap_sa" {
  provider = google-beta
  project  = var.project_id
  service  = "iap.googleapis.com"
}
```

### 3. Access Control Configuration

**For Initial User** (via terraform variable):

```hcl
variable "initial_user" {
  description = "Email of initial user granted IAP access"
  type        = string
  default     = null
}

# Grant initial user access to IAP
resource "google_iap_web_iam_member" "initial_user_iap_access" {
  count      = var.use_lb ? 1 : 0
  role       = "roles/iap.httpsResourceAccessor"
  member     = "user:${var.initial_user}"
}
```

**For Cloud Run Invocation** (IAP service account):

```hcl
# IAP service account can invoke Cloud Run
resource "google_cloud_run_service_iam_member" "iap_cloudrun_access" {
  location = google_cloud_run_v2_service.creative_studio.location
  service  = google_cloud_run_v2_service.creative_studio.name
  role     = "roles/run.invoker"
  member   = google_project_service_identity.iap_sa.member
}
```

### 4. Load Balancer Configuration

```hcl
module "lb-http" {
  source = "terraform-google-modules/lb-http/google//modules/serverless_negs"

  backends = {
    default = {
      description = "Creative Studio backend"
      iap_config = {
        enable = true  # ← Enable IAP on this backend
      }
    }
  }
}
```

### 5. Cloud Run Configuration

```hcl
resource "google_cloud_run_v2_service" "creative_studio" {
  # Mode 1: With load balancer
  ingress              = var.use_lb ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"
  default_uri_disabled = var.use_lb  # Hide direct URL when using LB

  # Mode 2: Direct with IAP
  iap_enabled          = !var.use_lb
  invoker_iam_disabled = !var.use_lb  # Require IAP for all requests
}
```

---

## How to Deploy Creative Studio with IAP

### Step 1: Deploy with IAP Enabled

```bash
cd infra/environments/dev-infra-example
terraform apply -var="use_lb=true" -var="initial_user=your-email@company.com"
```

### Step 2: Add Additional Users via IAM Binding

After initial deployment, add more users to an IAM group:

```bash
# Create an IAM group (one-time setup by identity team)
gcloud identity groups create creative-studio-users \
  --organization=ORGANIZATION_ID \
  --display-name="Creative Studio Users"

# Add members to group
gcloud identity groups memberships add \
  --group-email=creative-studio-users@company.com \
  --member-email=user@company.com

# Grant group access to IAP
gcloud iap web add-iam-policy-binding \
  --resource-names=projects/PROJECT_ID/global/backendServices/BACKEND_SERVICE_ID \
  --member=group:creative-studio-users@company.com \
  --role=roles/iap.httpsResourceAccessor
```

### Step 3: Backend Verification (Optional)

Backend can verify IAP headers:

```python
from fastapi import Header, HTTPException

@router.get("/api/protected")
async def protected_endpoint(
    x_goog_iap_jwt_assertion: str = Header(None)
):
    """Verify IAP header if present"""
    if not x_goog_iap_jwt_assertion:
        raise HTTPException(status_code=401, detail="Not authenticated via IAP")

    # Backend can verify the JWT if needed
    # Usually not necessary - IAP already filtered requests
    return {"message": "Successfully accessed via IAP"}
```

---

## Comparison: Authentication vs Authorization

### Authentication (Phase 1 Decision)

**This answers: "Who are you?"**

```
User → "I'm alice@company.com"
Backend → Verifies token signature
Backend → Creates/finds user in PostgreSQL or Firebase
Backend → Loads user's roles and workspace permissions
```

**Options**:
- Firebase Authentication (Phase 1 Option A)
- Pure OIDC (Phase 1 Option B)

### Authorization (IAP Layer)

**This answers: "Can you access this service?"**

```
User (authenticated) → Makes request to Cloud Run
IAP → Checks IAM group membership
IAP → If authorized, forwards request + X-Goog-IAP-JWT-Assertion header
Backend → Receives request (guarantees user is authorized at infrastructure level)
```

### They Work Together

```
User signs in (Phase 1 authentication)
        ↓
Frontend has ID token
        ↓
Frontend makes API request to Cloud Run
        ↓
IAP intercepts (checks IAM group)
        ↓
If authorized, forwards to backend with IAP header
        ↓
Backend receives guarantee that user is in allowed group
        ↓
Backend applies application-level RBAC (workspace roles, etc.)
```

---

## Advantages of IAP Approach

### 1. Permission Management

| Aspect | Manual GCP Users | IAP + Groups |
|--------|-----------------|--------------|
| **Add User** | Login to GCP Console | Managed by company identity team |
| **Remove User** | Login to GCP Console | Managed by company identity team |
| **User Limit** | 100 users max (internal project quota) | Unlimited (via groups) |
| **Sync with Directory** | Manual | Automatic (group membership) |
| **Operational Burden** | Your team | Specialized identity team |

### 2. Security

- **No application-level access control needed** (though still recommended)
- **Infrastructure-layer filtering** (more robust than app-level checks)
- **Can't bypass via direct Cloud Run URL** (when using LB)
- **Audit trail in Cloud IAM logs**

### 3. Scalability

- Works with any number of users (via IAM groups)
- Group membership can be synced from company directory
- No application database schema needed for access control

### 4. Compliance

- Centralized access control (easier to audit)
- Integrates with company identity infrastructure
- Supports organization policies
- Can enforce MFA at identity layer

---

## Combining IAP with Phase 1 Choices

### If You Choose Firebase (Phase 1 Option A) + IAP

```
┌─ User signs in with Google/Okta ─┐
│                                    │
├─→ Firebase Authentication          │
│                                    │
├─→ Frontend gets ID token          │
│                                    │
├─→ Frontend requests API            │
│                                    │
├─→ IAP checks IAM group (Authorized)
│                                    │
├─→ Backend receives request         │
│                                    │
├─→ Backend verifies JWT             │
│                                    │
└─→ Backend checks Firestore roles   │
    (workspace permissions)
```

**Benefits**:
- Multi-provider via Firebase federation
- Infrastructure-layer access control via IAP
- Application-level role management in Firestore

### If You Choose Pure OIDC (Phase 1 Option B) + IAP

```
┌─ User signs in with any OIDC provider ─┐
│                                         │
├─→ Direct OIDC flow (no Firebase)       │
│                                         │
├─→ Frontend gets ID token               │
│                                         │
├─→ Frontend requests API                │
│                                         │
├─→ IAP checks IAM group (Authorized)    │
│                                         │
├─→ Backend receives request             │
│                                         │
├─→ Backend verifies JWT                 │
│                                         │
├─→ Backend queries PostgreSQL for user  │
│                                         │
└─→ Backend checks workspace roles       │
    (application-level RBAC)
```

**Benefits**:
- No Firebase dependency (pure OIDC + IAP)
- Infrastructure-layer access control
- Single user directory in PostgreSQL

---

## Limitations & Considerations

### When IAP Alone Is NOT Enough

❌ **IAP Should NOT Be Your Only Access Control**:
- IAP controls access to Cloud Run service
- Doesn't control what users can do INSIDE the app
- You still need application-level RBAC

✅ **IAP + Application RBAC Together**:
- IAP: "Can you access the backend?"
- Application RBAC: "What workspaces can you see?"

### Network Architecture Implications

**With Load Balancer (recommended)**:
- ✅ Direct Cloud Run URL disabled
- ✅ All traffic goes through IAP
- ✅ Custom domain support
- ❌ Additional load balancer cost

**Direct Cloud Run + IAP**:
- ✅ Simpler, no LB
- ✅ Still protected by IAP
- ❌ Direct Cloud Run URL exists (could bypass if exposed)
- ❌ No custom domain

### Cost Implications

- **IAP**: Pricing included in Cloud Run (no extra cost)
- **Load Balancer**: ~$10/month + traffic costs
- **IAM Groups**: No additional cost (uses existing Google Workspace)

---

## Terraform Reference

### Basic IAP Setup

```hcl
# 1. Enable IAP API
module "project-services" {
  activate_apis = [
    "iap.googleapis.com",  # ← Required
    "run.googleapis.com",
  ]
}

# 2. Create IAP service account
resource "google_project_service_identity" "iap_sa" {
  provider = google-beta
  project  = var.project_id
  service  = "iap.googleapis.com"
}

# 3. Grant initial user access
resource "google_iap_web_iam_member" "user_access" {
  role       = "roles/iap.httpsResourceAccessor"
  member     = "user:${var.initial_user}"
  depends_on = [google_project_service_identity.iap_sa]
}

# 4. Enable IAP on Cloud Run
resource "google_cloud_run_v2_service" "app" {
  iap_enabled = true
}
```

### Terraform Variables

```hcl
variable "use_lb" {
  description = "Use load balancer with IAP (vs direct Cloud Run)"
  type        = bool
  default     = true  # Recommended for production
}

variable "initial_user" {
  description = "Email of user to grant IAP access"
  type        = string
  default     = null
}
```

---

## Implementation Decision Tree

```
Should we use IAP?

├─ YES if:
│  ├─ You want centralized access control (IAM groups)
│  ├─ You need to scale beyond 100 users
│  ├─ Your company uses Google Workspace / Cloud Identity
│  ├─ You want infrastructure-layer filtering
│  └─ You prefer delegating user management to identity team
│
└─ MAYBE if:
   ├─ You're running application internally only
   ├─ You want simplest possible auth
   └─ Cost is primary concern (IAP is free, LB adds cost)
```

---

## Next Steps

1. **Decide Phase 1**: Firebase or Pure OIDC? (See `06_PHASE1_TWO_ALTERNATIVES.md`)
2. **Consider IAP**: Do you need infrastructure-layer access control?
3. **Plan Deployment**:
   - Phase 1: Implement frontend + backend authentication
   - Add IAP: Enable IAP configuration in Terraform
   - Manage Access: Use IAM groups for user provisioning
4. **Reference Implementation**: See `/vertex-ai-creative-studio/main.tf` for complete IAP setup

---

## Document Information

- **Last Updated**: December 17, 2025
- **Version**: 1.0
- **Related Documents**:
  - `06_PHASE1_TWO_ALTERNATIVES.md` - Authentication choices
  - `../IMPLEMENTATION_STRATEGY_MASTER_INDEX.md` - Full roadmap
  - Secondary app: `/home/rinal/Desktop/temp/vertex-ai-creative-studio/main.tf`
