# Quick Reference Card

**Print this or bookmark it!** - Quick answers to common questions during deployment & testing.

---

## 📋 Configuration Flags

### Backend Python Environment Variables

| Variable | Options | Default | Use Case |
|----------|---------|---------|----------|
| `USE_CLOUD_SQL_PRIVATE_IP` | `True` / `False` | `False` | Use VPC for DB connection |
| `USE_CLOUD_SQL_AUTH_PROXY` | `True` / `False` | `False` | Use Cloud SQL Auth Proxy |
| `INSTANCE_CONNECTION_NAME` | String | Empty | Cloud SQL instance name |
| `DB_HOST` | String | `localhost` | Database host |
| `DB_PORT` | String | `5432` | Database port |
| `PROJECT_ID` | String | Auto-detect | GCP project ID |
| `GENMEDIA_BUCKET` | String | Auto-set | Cloud Storage bucket name |

**Decision Tree:**
```
Local Docker with proxy?
  → USE_CLOUD_SQL_AUTH_PROXY=True, DB_HOST=localhost

Cloud Run without VPC?
  → USE_CLOUD_SQL_PRIVATE_IP=False, INSTANCE_CONNECTION_NAME set

Cloud Run with VPC?
  → USE_CLOUD_SQL_PRIVATE_IP=True, INSTANCE_CONNECTION_NAME set

Development locally against cloud DB?
  → USE_CLOUD_SQL_PRIVATE_IP=False, INSTANCE_CONNECTION_NAME set
```

---

## 🌐 Network Connectivity

### Public IP (No VPC)
```
Internet
   ↓
Cloud Run (public IP) ← Can be reached from anywhere
   ↓
Cloud SQL (public IP) ← Can be reached from anywhere (if firewall allows)
```
✅ Pros: Simple, cheap, works locally
❌ Cons: Less secure, database exposed

### Private IP (With VPC)
```
Internet
   ↓
Cloud Run (in VPC, private subnet)
   ↓
VPC Connector
   ↓
Cloud SQL (private IP only, 10.1.x.x)
```
✅ Pros: Secure, database hidden, professional
❌ Cons: Requires VPC setup, slightly more complex

---

## 🔧 Terraform Commands Quick Guide

### Before Deploying
```bash
# 1. Navigate to environment directory
cd infra/environments/dev-infra-example

# 2. Initialize (first time only)
terraform init

# 3. Validate syntax
terraform validate

# 4. Preview what will be created
terraform plan

# 5. Review output carefully!
# Check for:
# - Resource count (expect 30+)
# - VPC network being created (if vpc_enable=true)
# - Cloud SQL with private IP (if vpc_enable=true)
```

### Deploying
```bash
# Apply changes (creates infrastructure)
terraform apply

# Wait for completion (5-10 minutes typical)
# Watch for:
# - "google_compute_vpc_access_connector" (if VPC enabled)
#   Takes 2-3 minutes to initialize
# - "google_sql_database_instance" creation
# - "google_cloud_run_service" deployment
```

### After Deploying
```bash
# View all outputs
terraform output

# View specific output
terraform output -raw backend_service_url

# Check infrastructure in GCP Console
# Go to:
# - Compute Engine → VPC Networks (if VPC enabled)
# - Cloud SQL → Instances
# - Cloud Run → Services
```

### Troubleshooting
```bash
# Show detailed logs
terraform plan -var-file="dev.tfvars" -json | jq

# Refresh state
terraform refresh

# Destroy infrastructure (use carefully!)
terraform destroy
```

---

## 🗄️ Database Connection Modes

### Mode 1: Public IP (Development)
```
Config:
  USE_CLOUD_SQL_PRIVATE_IP=False
  INSTANCE_CONNECTION_NAME="project:region:instance"

Connection:
  Cloud SQL Python Connector
  Fetches public IP: 1.2.3.4
  Connects to: 1.2.3.4:5432

When to use:
  ✅ Local development
  ✅ Testing with public Cloud SQL
  ✅ No VPC available yet
```

### Mode 2: Private IP (Production)
```
Config:
  USE_CLOUD_SQL_PRIVATE_IP=True
  INSTANCE_CONNECTION_NAME="project:region:instance"
  (VPC Connector must be attached to Cloud Run)

Connection:
  Cloud SQL Python Connector
  Fetches private IP: 10.1.x.x
  Routes through VPC Connector
  Connects to: 10.1.x.x:5432

When to use:
  ✅ Production deployment
  ✅ Secure database (no public access)
  ✅ VPC network available
```

### Mode 3: Auth Proxy (Localhost)
```
Config:
  USE_CLOUD_SQL_AUTH_PROXY=True
  DB_HOST="localhost"
  DB_PORT="5432"
  (Auth proxy running separately)

Connection:
  Direct asyncpg connection
  Connects to: localhost:5432
  Auth proxy forwards to Cloud SQL

When to use:
  ✅ Local Docker development
  ✅ Local testing with docker-compose
  ✅ CI/CD pipelines with proxy
```

---

## 🚨 Common Error Messages & Solutions

### Error: "PROJECT_ID could not be determined"
```
Cause: Environment variable not set, ADC failed
Fix:   export PROJECT_ID="your-project-id"
```

### Error: "Permission denied on Cloud SQL private IP"
```
Cause: Firewall rule missing, 5432 blocked
Fix:   Verify firewall rule allows internal traffic
       gcloud compute firewall-rules list --filter="network~^cs-"
```

### Error: "Address already in use" (VPC Connector)
```
Cause: Connector still initializing (2-3 minutes)
Fix:   Wait 2-3 minutes, then redeploy
       gcloud compute vpc-access connectors describe cs-dev-connector
```

### Error: "Connection refused: 10.1.x.x:5432"
```
Cause: Private IP but VPC Connector not attached
Fix:   Verify Cloud Run has vpc_connector_id set
       Or disable USE_CLOUD_SQL_PRIVATE_IP=False
```

### Error: "GENMEDIA_BUCKET not set"
```
Cause: Should not happen (auto-set)
Fix:   Re-run backend with PROJECT_ID set
       Should auto-populate to {PROJECT_ID}-assets
```

### Error: "Cannot reach Secret Manager"
```
Cause: Private Google Access disabled
Fix:   Re-run terraform apply (enables it)
       Or: gcloud compute networks subnets update cs-dev-primary --enable-private-ip-google-access
```

---

## 📊 Resource Naming Patterns

### VPC Resources
| Resource | Name Pattern | Example |
|----------|--------------|---------|
| VPC Network | `cs-{environment}` | `cs-development` |
| Primary Subnet | `cs-{env}-primary` | `cs-dev-primary` |
| Connector Subnet | `cs-{env}-connector` | `cs-dev-connector` |
| VPC Connector | `cs-{env}-connector` | `cs-dev-connector` |
| Firewall Rule | `cs-{env}-allow-*` | `cs-dev-allow-internal` |

### Database Resources
| Resource | Name Pattern | Example |
|----------|--------------|---------|
| Cloud SQL Instance | `creative-studio-db-{hash}` | `creative-studio-db-a1b2c3d4` |
| Database | `creative_studio` | (fixed) |
| Database User | `postgres` | (fixed) |

### Compute Resources
| Resource | Name Pattern | Example |
|----------|--------------|---------|
| Cloud Run Backend | `{backend_service_name}-{env}-*` | `cstudio-backend-dev-*` |
| Cloud Run Frontend | `{frontend_service_name}-{env}-*` | `cstudio-frontend-dev-*` |
| Service Account | `cs-{env}-*` | `cs-dev-read` |

---

## 🔐 Security Checklist

Before deploying to production:

- [ ] Cloud SQL has `deletion_protection = true`
- [ ] Cloud SQL private IP enabled (no public IP)
- [ ] VPC Connector attached to Cloud Run
- [ ] Firewall rules restrict to internal traffic only
- [ ] Service accounts have least-privilege roles
- [ ] Secrets in Secret Manager (not in .tfvars)
- [ ] Backup strategy documented
- [ ] Monitoring/alerting configured
- [ ] Database credentials rotated
- [ ] Network logs enabled (VPC Flow Logs)

---

## ✅ Deployment Validation

### Step 1: Verify Backend Health
```bash
curl https://cstudio-backend-{hash}.run.app/health
# Expected: 200 OK
```

### Step 2: Check Database Connection
```bash
gcloud cloud-run logs read cstudio-backend-{name} --limit=20
# Look for: "Connected to database" or similar
# NOT: "Connection refused" or "timeout"
```

### Step 3: Load Frontend
```
Open https://cstudio-frontend-{hash}.run.app in browser
# Expected: Page loads, no console errors
```

### Step 4: Test API Call
```javascript
// In browser console:
fetch('https://cstudio-backend-{hash}.run.app/api/health')
  .then(r => r.json())
  .then(d => console.log(d))
  .catch(e => console.error(e))
# Expected: Successful response from backend
# NOT: CORS error or 502
```

### Step 5: Check VPC (if enabled)
```bash
# Verify VPC created
gcloud compute networks describe cs-development

# Verify VPC Connector status
gcloud compute vpc-access connectors describe cs-dev-connector \
  --region us-central1

# Verify Cloud SQL private IP
gcloud sql instances describe creative-studio-db-* \
  --format="value(ipAddresses[0].type,ipAddresses[0].ipAddress)"
# Expected: Private IP in 10.1.0.0/16 range
```

---

## 📞 Support Decision Tree

**Question:** Connection works locally but fails in Cloud Run?
→ Check `INSTANCE_CONNECTION_NAME` is set in Cloud Run env vars

**Question:** VPC Connector not showing up?
→ Check `vpc_enable=true` in terraform.tfvars

**Question:** Cloud SQL still has public IP?
→ Set `cloud_sql_public_ip_enabled=false` and re-run terraform apply

**Question:** Firewall rules not working?
→ Terraform overwrites manual changes, re-run terraform apply

**Question:** Frontend can't call backend API?
→ Check CORS config in genmedia bucket
→ Check backend GOOGLE_TOKEN_AUDIENCE in Secret Manager

**Question:** Backend takes long time to start?
→ Check Cloud Run logs: `gcloud cloud-run logs read ...`

**Question:** How do I know if it's using private IP?
→ Check Cloud SQL: `gcloud sql instances describe` should show 10.1.x.x

**Question:** Can I switch from public to private IP later?
→ Yes! Set `USE_CLOUD_SQL_PRIVATE_IP=True` and redeploy

---

## 🎯 Success Criteria

Your deployment is successful when:

1. ✅ `terraform apply` completes without errors
2. ✅ Backend health endpoint responds (curl test)
3. ✅ Frontend page loads in browser
4. ✅ Frontend can call backend API (no CORS errors)
5. ✅ Backend can write to database (check logs)
6. ✅ Cloud SQL shows correct IP type:
   - If VPC enabled: Private IP (10.1.x.x)
   - If VPC disabled: Public IP
7. ✅ No timeout errors in logs
8. ✅ No permission denied errors

---

## 📚 When to Check Which Document

| Situation | Document |
|-----------|----------|
| Setting up for first time | QUICK_START.md |
| Understanding the design | ARCHITECTURE.md |
| Something doesn't work | ARCHITECTURE.md §13 (Troubleshooting) |
| Testing edge cases | TESTING_EDGE_CASES.md |
| Reviewing all changes | COMPREHENSIVE_REVIEW.md |
| Quick lookup | This document (QUICK_REFERENCE.md) |
| Understanding variables | TERRAFORM_OUTPUTS_AND_CICD.md |
| Big picture overview | REVIEW_SUMMARY.md |

---

**Last Updated:** 2025-12-22
**Applies To:** Version with VPC support + private Cloud SQL
