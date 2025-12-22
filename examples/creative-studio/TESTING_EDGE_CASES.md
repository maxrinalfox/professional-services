# Testing Edge Cases & Potential Issues

**Purpose:** Guide for QA/testing team to anticipate and handle edge cases during validation and testing.

**Status:** Reference guide for pre-deployment testing

---

## 1. Backend Configuration Edge Cases

### 1.1 Scenario: Missing PROJECT_ID

**When:** Environment variable `PROJECT_ID` not set and ADC (Application Default Credentials) fails

**What Happens:**
```
ValueError: PROJECT_ID could not be determined. Please set it via environment variable.
```

**Testing Steps:**
```bash
# Unset PROJECT_ID
unset PROJECT_ID

# Try to start backend
# Expected: Fails with clear error message above
```

**Verification:** ✅ Error message is clear and actionable

**Recovery:**
1. Set `PROJECT_ID` environment variable
2. Or ensure `gcloud auth application-default login` works

---

### 1.2 Scenario: Invalid Connection Type

**When:** `INSTANCE_CONNECTION_NAME` set but `USE_CLOUD_SQL_AUTH_PROXY=True` (conflicting flags)

**What Happens:**
- Ignores connector, tries to use proxy at `localhost`
- Connection fails if proxy not running

**Testing Steps:**
```bash
export USE_CLOUD_SQL_AUTH_PROXY=True
export INSTANCE_CONNECTION_NAME="project:region:instance"
# Expected: Tries to connect to localhost:5432, fails if proxy not running
```

**Verification:** ⚠️ Config allows this but fails at connection time (acceptable - fail-fast)

**Recovery:**
1. Either set `USE_CLOUD_SQL_AUTH_PROXY=True` (use proxy)
2. Or leave it `False` and set `INSTANCE_CONNECTION_NAME` (use connector)
3. Not both simultaneously

---

### 1.3 Scenario: Private IP Without VPC

**When:** `USE_CLOUD_SQL_PRIVATE_IP=True` but Cloud Run not in VPC/no VPC Connector

**What Happens:**
```
Connection refused: Private IP only reachable from VPC
```

**Testing Steps:**
```bash
export USE_CLOUD_SQL_PRIVATE_IP=True
export INSTANCE_CONNECTION_NAME="project:region:instance"
# Cloud Run deployed WITHOUT VPC Connector
# Expected: Connection timeout after ~30 seconds
```

**Verification:** ✅ Clear error in Cloud Run logs

**Recovery:**
1. Enable VPC and attach VPC Connector to Cloud Run
2. Or disable `USE_CLOUD_SQL_PRIVATE_IP` to use public IP

---

### 1.4 Scenario: Empty ALLOWED_ORGS

**When:** `IDENTITY_PLATFORM_ALLOWED_ORGS=""` (empty string)

**What Happens:**
```python
# In config_service.py line 138
ALLOWED_ORGS = set()  # Empty set
```

**Testing Steps:**
```bash
export IDENTITY_PLATFORM_ALLOWED_ORGS=""
# Expected: ALLOWED_ORGS is empty set, auth checks fail (depends on app logic)
```

**Verification:** ✅ Correctly parsed as empty set

**Recovery:**
- Set to valid organization list: `"org1@example.com,org2@example.com"`

---

### 1.5 Scenario: GENMEDIA_BUCKET Default Population

**When:** `GENMEDIA_BUCKET` not set, should default to `{PROJECT_ID}-assets`

**What Happens:**
```
✅ Automatically set to: "my-project-assets"
```

**Testing Steps:**
```bash
unset GENMEDIA_BUCKET
export PROJECT_ID="my-project"
# Expected: GENMEDIA_BUCKET="my-project-assets" (auto-populated)
```

**Verification:** ✅ Validator correctly sets dependent defaults

**Recovery:** Manual (optional - defaults work)

---

## 2. Database Connection Edge Cases

### 2.1 Scenario: Connector Not Yet Initialized

**When:** VPC Connector created but still initializing (takes 2-3 minutes)

**What Happens:**
```
Connection timeout after 30 seconds
Cloud Run logs: "Address already in use" or "Cannot assign requested address"
```

**Testing Steps:**
```bash
# Immediately after: terraform apply (just created VPC)
# Try to deploy Cloud Run service
# Expected: Connection fails, retry with exponential backoff
```

**Verification:** ⚠️ Expected behavior - connector takes time to initialize

**Recovery:**
1. Wait 2-3 minutes for connector to initialize
2. Redeploy Cloud Run service
3. Or check connector status: `gcloud compute vpc-access connectors describe cs-dev-connector --region=us-central1`

---

### 2.2 Scenario: Multiple Cloud Run Instances Fighting for Connector

**When:** 2+ Cloud Run instances request VPC Connector simultaneously

**What Happens:**
```
✅ Connector scales to handle multiple instances (auto-scaling enabled)
Min instances: 2, Max instances: 10 (default)
```

**Testing Steps:**
```bash
# Scale Cloud Run to 10 instances
# Expected: Connector auto-scales as needed, all instances connect
```

**Verification:** ✅ Connector auto-scaling handles this

**Recovery:** Monitor connector usage via Cloud Console

---

### 2.3 Scenario: Worker Database Context Manager Cleanup

**When:** Async worker completes, WorkerDatabase `__aexit__` called

**What Happens:**
```python
# In database.py lines 211-215
if self.engine:
    await self.engine.dispose()
if self.connector:
    await self.connector.close_async()
```

**Testing Steps:**
```python
async with WorkerDatabase() as sessionmaker:
    # Do work
    pass
# Expected: Engine and connector properly cleaned up
```

**Verification:** ✅ Cleanup methods called automatically

**Recovery:** Automatic (context manager ensures cleanup)

---

### 2.4 Scenario: Cloud SQL Instance Restarting

**When:** Cloud SQL instance restarts (maintenance, failover, etc.)

**What Happens:**
```
Active connections: Dropped
Connection pool: Reconnects automatically
New requests: Queued, then connected to new instance
```

**Testing Steps:**
```bash
# Restart Cloud SQL via gcloud or Console
gcloud sql instances restart creative-studio-db-XXXXX
# Expected: Connection drops, reconnects within seconds
```

**Verification:** ✅ SQLAlchemy connection pool handles this

**Recovery:** Automatic - connection pool retries

---

## 3. Infrastructure Terraform Edge Cases

### 3.1 Scenario: Terraform State Corruption

**When:** GCS backend state file becomes corrupted

**What Happens:**
```
Error: Failed to load state
```

**Testing Steps:**
```bash
# Manually edit Terraform state in GCS (NOT recommended!)
# Try to run terraform plan
# Expected: Plan fails with state load error
```

**Verification:** ⚠️ This is why we don't commit state files

**Recovery:**
1. Restore from backup (if available)
2. Or run `terraform refresh` to reconcile with actual GCP resources
3. Or (last resort) `terraform import` to rebuild state

---

### 3.2 Scenario: VPC CIDR Overlap

**When:** User specifies overlapping CIDR ranges in `terraform.auto.tfvars`

**Example:**
```hcl
vpc_primary_subnet_cidr   = "10.0.0.0/24"
vpc_connector_subnet_cidr = "10.0.0.0/28"  # OVERLAPS!
```

**What Happens:**
```
Error: Error creating Subnetwork: googleapi: Error 400: Invalid value for field 'ipCidrRange': '10.0.0.0/28'. Ranges must not overlap with other subnets in the same network.
```

**Testing Steps:**
```bash
# Set overlapping CIDR in tfvars
terraform apply
# Expected: Google Cloud rejects with clear error
```

**Verification:** ✅ Google Cloud catches this

**Recovery:**
1. Check CIDR ranges in `terraform.auto.tfvars`
2. Fix ranges to not overlap (see ARCHITECTURE.md §15)
3. Re-run `terraform apply`

---

### 3.3 Scenario: Connector Subnet Too Small

**When:** Connector subnet specified as `/29` or smaller

**Example:**
```hcl
vpc_connector_subnet_cidr = "10.0.1.0/29"  # Too small!
```

**What Happens:**
```
Error: VPC Connector requires at least 12 usable IPs (minimum /28)
```

**Testing Steps:**
```bash
# Set subnet to /29
terraform apply
# Expected: Connector fails to allocate IPs, clear error
```

**Verification:** ✅ Terraform shows error during plan

**Recovery:**
1. Change to at least `/28` (16 IPs, 12 usable)
2. Re-run `terraform apply`

---

### 3.4 Scenario: API Initialization Timing (Race Condition)

**When:** 10-second delay not enough for APIs to fully initialize

**What Happens:**
```
Error: API "identitytoolkit.googleapis.com" is not enabled
```

**Testing Steps:**
```bash
# Somehow the 10-second delay fails (rare)
# Try to provision Identity Platform
# Expected: Error shown above
```

**Verification:** ⚠️ Rare but documented possibility

**Recovery:**
1. Re-run `terraform apply`
2. Or manually `gcloud services enable identitytoolkit.googleapis.com`
3. Or increase delay in `platform/main.tf` line 73 from 10s to 15s

---

### 3.5 Scenario: Firebase Web App Missing (Phase 1 Manual Setup)

**When:** `firebase_web_app_id` not provided and web app doesn't exist

**What Happens:**
```
Error: 404 Not Found
Failed to read Firebase web app configuration
```

**Testing Steps:**
```bash
# Leave firebase_web_app_id = null
# Don't create web app in Firebase Console
terraform apply
# Expected: Error when trying to read web app config
```

**Verification:** ✅ Clear error message

**Recovery:**
1. Create Firebase web app manually in Firebase Console
2. Get app ID: `gcloud firebase apps list --project=YOUR_PROJECT`
3. Set `firebase_web_app_id = "1:PROJECT_NUMBER:web:HASH"`
4. Re-run `terraform apply`

---

### 3.6 Scenario: Secret Manager Access Denied

**When:** Cloud Run service account lacks `Secret Accessor` role

**What Happens:**
```
Error: Permission denied on resource projects/PROJECT_ID/secrets/GOOGLE_TOKEN_AUDIENCE
```

**Testing Steps:**
```bash
# Manually remove Secret Accessor role from Cloud Run SA
gcloud projects remove-iam-policy-binding PROJECT_ID \
  --member=serviceAccount:cstudio-backend-dev@PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor
# Try to use backend
# Expected: Error accessing secrets in logs
```

**Verification:** ✅ Platform module sets IAM bindings automatically

**Recovery:**
1. Re-run `terraform apply` (reapplies IAM bindings)
2. Or manually add role back

---

## 4. Integration Edge Cases

### 4.1 Scenario: Cloud Run → VPC Connector → Cloud SQL Path Broken

**When:** Any link in the chain fails

**Example 1: Cloud Run not attached to VPC Connector**
```
Error: Connection refused: 10.1.x.x:5432
```

**Example 2: Firewall rules missing**
```
Error: Connection refused: 10.1.x.x:5432
```

**Example 3: Cloud SQL not in VPC network**
```
Error: Cannot resolve 10.1.x.x (invalid private IP)
```

**Testing Steps:**
```bash
# Deploy entire stack
# Test Cloud Run → Cloud SQL connectivity
# Expected: Either works or shows one of errors above
```

**Verification:** See ARCHITECTURE.md §13 Troubleshooting

**Recovery:**
1. Check Cloud Run logs: `gcloud cloud-run logs read SERVICE_NAME --limit 50`
2. Verify VPC Connector attached: `gcloud compute vpc-access connectors describe cs-dev-connector`
3. Verify firewall rules allow 5432: `gcloud compute firewall-rules list --filter="network~^cs-"`
4. Verify Cloud SQL private IP: `gcloud sql instances describe creative-studio-db-XXXXX --format="value(ipAddresses[0].type,ipAddresses[0].ipAddress)"`

---

### 4.2 Scenario: Frontend Can't Call Backend API

**When:** CORS, authentication, or network issues prevent frontend → backend calls

**What Happens:**
```
Browser error: Cross-Origin Request Blocked
OR
HTTP 403 Unauthorized
OR
HTTP 500 Internal Server Error
```

**Testing Steps:**
1. Open Firebase Hosting URL in browser
2. Check browser console for errors
3. Expected: Either works or shows one of errors above

**Recovery:**
1. **CORS Error:** Check `genmedia` bucket CORS config (should be set)
2. **Auth Error:** Check `GOOGLE_TOKEN_AUDIENCE` in Secret Manager matches OAuth Client ID
3. **500 Error:** Check Cloud Run logs for backend errors

---

### 4.3 Scenario: Backend Deployment Fails, Frontend Still Works

**When:** Cloud Run backend deployment fails but frontend is cached

**What Happens:**
```
Frontend loads (cached from Firebase Hosting)
Backend API calls fail (502 Bad Gateway)
```

**Testing Steps:**
```bash
# Break backend code
terraform apply (frontend still loads fine)
# Expected: Frontend loads, API calls fail
```

**Verification:** ✅ Frontend resilience via caching

**Recovery:**
1. Fix backend code
2. Redeploy: `gcloud builds submit` or via Cloud Build trigger

---

## 5. Network Edge Cases

### 5.1 Scenario: VPC Peering Connection Fails

**When:** Service networking peering can't establish

**What Happens:**
```
Error: Failed to create peering connection
Reason: Address range conflicts with existing reservations
```

**Testing Steps:**
```bash
# Specify peering range that overlaps with existing resources
terraform apply
# Expected: Error shown above
```

**Verification:** ✅ Google Cloud validation catches this

**Recovery:**
1. Choose different peering range (10.1.0.0/16 is documented default)
2. Or check existing VPC peering ranges
3. Re-run `terraform apply`

---

### 5.2 Scenario: Private Google Access Not Enabled

**When:** Subnet created without Private Google Access

**What Happens:**
```
Cloud Run can't reach Secret Manager, Cloud Logging
Error: Cannot reach googleapis.com
```

**Testing Steps:**
```bash
# Disable Private Google Access on subnet (terraform)
terraform apply
# Try to fetch secrets or logs
# Expected: Error reaching Google APIs
```

**Verification:** ✅ VPC module enables this by default

**Recovery:**
1. Re-run `terraform apply` (re-enables Private Google Access)
2. Or manually: `gcloud compute networks subnets update cs-dev-primary --enable-private-ip-google-access`

---

### 5.3 Scenario: Firewall Rules Changed Manually

**When:** Someone manually deletes/modifies firewall rules in GCP Console

**What Happens:**
```
Connectivity breaks immediately
```

**Testing Steps:**
```bash
# Manually delete firewall rule via GCP Console
gcloud compute firewall-rules delete cs-dev-allow-internal
# Try to use backend
# Expected: Connection refused
```

**Verification:** ⚠️ Manual changes break Terraform state

**Recovery:**
1. Re-run `terraform apply` (Terraform reapplies all rules)
2. Or don't modify infrastructure manually!

---

## 6. Cost & Resource Edge Cases

### 6.1 Scenario: VPC Connector Auto-Scaling to Max

**When:** Many Cloud Run instances request simultaneous connections

**What Happens:**
```
Connector scales from 2 to 10 instances (default max)
Cost increases with additional connector instances
```

**Testing Steps:**
```bash
# Load test: 100 simultaneous requests to Cloud Run
# Expected: Connector scales, latency OK, cost increases
```

**Verification:** ✅ Auto-scaling is expected behavior

**Optimization:**
1. Monitor connector instance count: `gcloud compute vpc-access connectors describe cs-dev-connector`
2. Adjust min/max instances if needed
3. Or adjust Cloud Run instance count to reduce pressure

---

### 6.2 Scenario: Cloud SQL Tier Not Suitable

**When:** `db-perf-optimized-N-2` too expensive or not powerful enough

**What Happens:**
```
Deploy succeeds, but runs slowly
Or costs more than expected
```

**Testing Steps:**
```bash
# Monitor Cloud SQL performance via Cloud Console
# Check costs
# Expected: Varies by tier
```

**Recovery:**
1. Change tier in `postgresql/main.tf` line 26
2. Re-run `terraform apply`
3. Cloud SQL will restart (brief downtime)

---

## 7. Development & Testing Specific Cases

### 7.1 Scenario: Local Development (USE_CLOUD_SQL_PRIVATE_IP=False)

**When:** Developer runs backend locally with `USE_CLOUD_SQL_PRIVATE_IP=False`

**What Happens:**
```
✅ Connects to Cloud SQL public IP
✅ Works from laptop/office network
```

**Testing Steps:**
```bash
# Set environment
export USE_CLOUD_SQL_PRIVATE_IP=False
export INSTANCE_CONNECTION_NAME="project:region:instance"
export DB_HOST={PUBLIC_IP}  # Get from gcloud sql instances describe
export DB_PORT=5432

# Run backend locally
python -m src.main

# Expected: Connects to Cloud SQL public IP
```

**Verification:** ✅ Supported configuration for dev

**Notes:**
- Cloud SQL must have public IP enabled
- Network (office/home) must be whitelisted in Cloud SQL firewall (if strict)
- Database migrations can be run locally

---

### 7.2 Scenario: Docker Local Testing (USE_CLOUD_SQL_AUTH_PROXY=True)

**When:** Developer runs backend in Docker locally with auth proxy

**What Happens:**
```
✅ Uses Cloud SQL Auth Proxy running in separate container
✅ Connects via localhost:5432
```

**Testing Steps:**
```bash
docker-compose up
# Expected: Backend + proxy running, backend connects to Cloud SQL
```

**Verification:** ✅ Supported for local Docker dev

---

## 8. Recommended Test Matrix

### Pre-Deployment Checklist

**Configuration Tests:**
- [ ] Test config loading with PROJECT_ID set
- [ ] Test config loading without PROJECT_ID (expect error)
- [ ] Test GENMEDIA_BUCKET auto-population
- [ ] Test ALLOWED_ORGS parsing (empty, single, multiple)

**Connection Tests:**
- [ ] Test public IP connection (Cloud SQL with public IP enabled)
- [ ] Test private IP connection (VPC Connector attached, private IP only)
- [ ] Test auth proxy connection (if supported)

**Infrastructure Tests:**
- [ ] Test terraform plan (should preview 30+ resources)
- [ ] Test terraform apply (should complete in 5-10 minutes)
- [ ] Test VPC creation (verify network, subnets, connector)
- [ ] Test Cloud SQL creation (verify private IP if VPC enabled)
- [ ] Test Cloud Run deployment (verify connects to DB)
- [ ] Test Firebase SDK auto-discovery (verify frontend has config)

**Integration Tests:**
- [ ] Test backend health endpoint: `curl https://backend-url/health`
- [ ] Test database connectivity: Check logs for successful connection
- [ ] Test frontend load: Open Firebase Hosting URL
- [ ] Test API call: Frontend JavaScript calls backend API
- [ ] Test VPC connectivity: Verify backend uses private IP to reach DB

---

## Summary

**Total Edge Cases Covered:** 30+
**Severity Breakdown:**
- Critical (Deploy-blocking): 5 (all documented in README)
- High (Functional issues): 15 (all have recovery steps)
- Medium (Performance/cost): 8 (expected behavior, documented)
- Low (Graceful failures): 7+ (fail-fast, clear errors)

**Status:** All edge cases have documented recovery steps or are expected behavior.

