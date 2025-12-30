# 🚀 Creative Studio Infrastructure - Quick Start Guide

**Complete setup in ~60-90 minutes (one-time only)**

This guide walks you through deploying Creative Studio to Google Cloud Platform step-by-step.

---

## 📋 Prerequisites Checklist

Before starting, ensure you have:

- [ ] **Google Account** - Required for GCP and Firebase
- [ ] **Terraform CLI** v1.13+ - [Install here](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [ ] **Google Cloud SDK (gcloud)** - [Install here](https://cloud.google.com/sdk/docs/install)
- [ ] **jq** - JSON processor (Linux: `sudo apt-get install jq`, macOS: `brew install jq`)
- [ ] **bash** 4.0+ - Usually pre-installed
- [ ] **GitHub account** - To store and deploy source code
- [ ] **GCP billing account** - Required for cloud resources

---

## 🎯 Step-by-Step Setup

### **STEP 1: Accept Firebase Terms & Enable Billing (5 minutes)**

#### 1.1 Accept Firebase Terms of Service ⭐ **CRITICAL**

Firebase won't work without this acceptance:

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Sign in with your Google account
3. Accept the Firebase Terms of Service when prompted
4. ✅ Done - This is a one-time requirement per Google account

#### 1.2 Enable GCP Billing Account

Some Google Cloud services require billing:

1. Open [GCP Console](https://console.cloud.google.com/)
2. Go to **Billing** → **Manage Billing Accounts**
3. Create or select a billing account
4. ✅ Note down your **Billing Account ID** (you'll need it later)

---

### **STEP 2: Create GCP Project (5 minutes)**

A GCP Project is where all your cloud resources will live.

1. Open [GCP Console](https://console.cloud.google.com/)
2. Click on the **Project dropdown** (top bar) → **Select a Project**
3. Click **NEW PROJECT**
4. Enter:
   - **Project Name:** `creative-studio-dev` (or your choice)
   - **Organization:** (optional) Your organization if applicable
   - **Billing Account:** Select the account from STEP 1.2
5. Click **CREATE**
6. ✅ Wait for creation (1-2 minutes) and click the notification to go to your new project
7. ✅ **Copy your Project ID** (e.g., `creative-studio-dev-12345`) - you'll need this soon

**Check:** In the GCP Console top bar, you should see your project selected.

---

### **STEP 3: Authenticate gcloud with Your Account (5 minutes)**

This allows Terraform to access your GCP project.

```bash
# Open browser for authentication
gcloud auth login

# Verify authentication
gcloud auth list
# You should see your account marked with "ACTIVE"

# Set your project as default
gcloud config set project YOUR_PROJECT_ID
# Replace YOUR_PROJECT_ID with the one from STEP 2

# Verify
gcloud config list
```

✅ **Verify:** You should see your project ID listed.

---

### **STEP 4: Create Firebase Project & Web App (10 minutes)**

#### Option A: Terraform Creates Them AUTOMATICALLY (Recommended)

If you want Terraform to create Firebase for you:

```bash
# In your terraform.auto.tfvars (later), set:
firebase_web_app_id = null  # This tells Terraform to create it!
```

Then proceed to STEP 5. Terraform will automatically create:
- Firebase Project
- Firebase Web App
- Auto-discover SDK configuration

#### Option B: Create Manually in Firebase Console (Current Phase)

If you prefer to create them manually first:

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project** → Select your GCP project from STEP 2
3. Click **Continue**
4. Enable Google Analytics (optional) → Click **Create project**
5. ✅ Wait 2-3 minutes for creation

**Now create the Web App:**

1. In Firebase Console, go to **All Products**
2. Click **Hosting** (or Web icon <>)
3. Under "Get started", click **Continue**
4. App name: `cstudio-fe` (or your choice)
5. Click **Register app**
6. You'll see the Firebase SDK config - **don't worry**, Terraform will auto-discover it!
7. Click **Continue to console**

**Get the Firebase Web App ID:**

```bash
# Run this command:
gcloud firebase apps list --project=YOUR_PROJECT_ID

# Output example:
# 1:123456789:web:abc123xyz456def7890abcd

# Copy the value (it's called the "Firebase Web App ID")
```

✅ **Save this value** - you'll need it for `terraform.auto.tfvars`

---

### **STEP 5: Create Cloud Build GitHub Connection (10 minutes)**

Cloud Build needs permission to access your GitHub repository for CI/CD.

1. Open [GCP Cloud Build Connections](https://console.cloud.google.com/cloud-build/connections)
2. Click **Create connection**
3. Choose **GitHub (Cloud Build GitHub App)**
4. Click **Authenticate**
5. You'll be redirected to GitHub - sign in and authorize
6. Select the GitHub repository where your Creative Studio code is
7. Click **Create** to create the connection
8. ✅ **Copy the connection name** shown (e.g., `gh-myaccount-con`)

✅ **Note down:** This connection name will be your `github_conn_name` in terraform.auto.tfvars

---

### **STEP 6: Set Up Terraform State Backend (5 minutes)**

Terraform needs a GCS bucket to store its infrastructure state.

```bash
# Set variables for easy use
export PROJECT_ID=YOUR_PROJECT_ID  # From STEP 2
export ENVIRONMENT=dev             # Or: staging, prod, etc.

# Create a globally unique bucket name
# GCS bucket names must be unique across ALL of Google Cloud!
export BUCKET_NAME="$PROJECT_ID-cstudio-$ENVIRONMENT-tfstate"

# Create the bucket
gsutil mb -p $PROJECT_ID "gs://$BUCKET_NAME"

# Verify
gsutil ls -b "gs://$BUCKET_NAME"
```

✅ **Note down:** Your bucket name (you'll use it in `backend.tf`)

---

### **STEP 7: Duplicate and Configure Environment Directory (10 minutes)**

The `environments` directory contains templates. You'll create your own environment from the template.

#### 7.1 Copy Template Directory

```bash
cd infra/environments

# Copy the template
cp -r dev-infra-example $ENVIRONMENT

# Where $ENVIRONMENT is: dev, staging, prod, sandbox, etc.
cd $ENVIRONMENT
```

#### 7.2 Update `backend.tf`

This file tells Terraform where to store its state.

```bash
# Edit the backend.tf file
nano backend.tf
```

Update these values:

```hcl
terraform {
  backend "gcs" {
    bucket = "YOUR_BUCKET_NAME"     # From STEP 6
    prefix = "infra/$ENVIRONMENT/state"  # e.g., "infra/dev/state"
  }
}
```

Save the file (Ctrl+X, then Y, then Enter).

#### 7.3 Update `terraform.auto.tfvars`

This file contains all your environment-specific configuration.

```bash
nano terraform.auto.tfvars  # Or dev.tfvars or your-env.tfvars
```

Update these **REQUIRED** fields:

```hcl
# GCP Configuration
gcp_project_id = "YOUR_PROJECT_ID"      # From STEP 2
gcp_region     = "us-central1"          # Or your preferred region
environment    = "dev"                  # Your environment name

# Firebase (choose ONE approach from STEP 4)
firebase_web_app_id = null              # Let Terraform create it (recommended)
# OR
firebase_web_app_id = "1:123456789:web:abc123xyz..."  # Your Firebase App ID

# Service Names
backend_service_name  = "cstudio-backend-dev"   # Or your choice
frontend_service_name = "cstudio-frontend-dev"  # Or your choice

# GitHub Configuration (from STEP 5)
github_conn_name   = "gh-myaccount-con"         # Your connection name
github_repo_owner  = "your-github-username"     # Your GitHub username
github_repo_name   = "your-repo-name"           # Your repository name
github_branch_name = "main"                     # Or: develop, master, etc.

# Custom Audiences (JWT validation)
# Leave as empty arrays - GCP Project ID is auto-populated
backend_custom_audiences  = []
frontend_custom_audiences = []

# Backend Configuration
# Flat map of environment variables for the backend service
be_env_vars = {
  LOG_LEVEL                       = "INFO"
  ENVIRONMENT                     = "development"
  FIREBASE_DB                     = "cstudio-development"  # Must match firestore_database_name below
  IDENTITY_PLATFORM_ALLOWED_ORGS  = ""
}

# Firestore Database Configuration
firestore_database_name                = "cstudio-development"  # Firestore database name (optional)
firestore_deletion_protection_enabled  = false                 # Dev: false, Prod: true

# Cloud SQL Database Configuration
cloud_sql_deletion_protection_enabled  = false  # Dev: false, Prod: true
allow_destroy                          = true   # Dev: true (allow cleanup), Prod: false

# NOTE: Secrets are now managed centrally by Terraform's core/secrets module
# No secret configuration needed in tfvars - just populate OAUTH_CLIENT_ID after terraform apply
# (see infra/README.md section 8a for manual secret population)

# Identity Platform (Optional - disabled by default)
identity_platform_allow_anonymous           = true    # Allow guest access
identity_platform_allow_email               = true    # Allow email/password
identity_platform_google_oauth_enabled      = false   # Leave false for now
identity_platform_google_oauth_client_id     = ""     # Leave empty
identity_platform_google_oauth_client_secret = ""     # Leave empty

# Cloud Run Sizing (adjust if needed for performance)
be_cpu    = "2000m"
be_memory = "2048Mi"
fe_cpu    = "2000m"
fe_memory = "2048Mi"

# VPC Configuration (optional - for private database)
vpc_enable                = false           # Set to true if you want private Cloud SQL
vpc_primary_subnet_cidr   = "10.0.0.0/24"
vpc_connector_subnet_cidr = "10.0.1.0/28"

# Enable Cloud Build (required for CI/CD)
enable_cloud_build           = true   # Set to true to deploy services
cloud_sql_public_ip_enabled  = false  # Set to true for public database access
```

Save the file.

✅ **Verify:** All `REQUIRED` fields are filled. Leave optional ones as defaults.

---

### **STEP 8: Deploy Infrastructure with Terraform (20 minutes)**

Now the exciting part - Terraform will create all your cloud infrastructure!

```bash
# Make sure you're in your environment directory
cd infra/environments/$ENVIRONMENT

# Step 1: Initialize Terraform
# This downloads providers and configures the backend
terraform init

# You'll see output like:
# Initializing the backend...
# Successfully configured the backend "gcs"!

# Step 2: Review the plan
# This shows what Terraform will create (don't change anything)
terraform plan

# Review the output carefully. You should see:
# - google_project_service (enabling APIs)
# - google_firebase_project
# - google_firebase_web_app (if firebase_web_app_id = null)
# - google_identity_platform_config
# - google_cloud_run_v2_service (backend & frontend)
# - google_sql_instances (Cloud SQL database)
# ... and more

# Step 3: Apply the configuration
# This creates all the resources in your GCP project
terraform apply

# Terraform will show the plan again and ask:
# "Do you want to perform these actions?"
# Type: yes

# Wait for creation (10-15 minutes)
# You'll see green "created" messages as resources are created
```

✅ **Success!** When done, you'll see:

```
Apply complete! Resources: XX added, 0 changed, 0 destroyed.

Outputs:
backend_service_url = "https://cstudio-backend-xxx.us-central1.run.app"
frontend_service_url = "https://cstudio-frontend-xxx.web.app"
```

---

### **STEP 9: Verify Deployment (5 minutes)**

Verify everything was created successfully:

```bash
# Check that secrets were created
gcloud secrets list --project=YOUR_PROJECT_ID

# You should see:
# OAUTH_CLIENT_ID           (unified secret for frontend & backend - empty version)
# creative-studio-db-password (auto-generated database password)

# Verify the OAUTH_CLIENT_ID secret exists (no version yet since you haven't populated it)
gcloud secrets describe OAUTH_CLIENT_ID --project=YOUR_PROJECT_ID

# Check Cloud Run services
gcloud run services list --region=us-central1

# Check Cloud SQL instance
gcloud sql instances list
```

---

### **STEP 10: (Optional) Enable Google OAuth Authentication (5 minutes)**

If you want users to sign in with their Google accounts:

#### 10.1 Create OAuth 2.0 Client ID

1. Open [GCP APIs & Services](https://console.cloud.google.com/apis/credentials)
2. Click **Create Credentials** → **OAuth 2.0 Client ID**
3. If prompted, click **Configure OAuth Consent Screen** first:
   - Fill in App name: `Creative Studio`
   - Fill in Authorized domains: `YOUR_PROJECT_ID.web.app`
   - Click **Save and Continue**
4. Return to **Create Credentials** → **OAuth 2.0 Client ID**
5. Application type: **Web application**
6. Authorized JavaScript origins:
   - `https://YOUR_PROJECT_ID.firebaseapp.com`
   - `https://YOUR_PROJECT_ID.web.app`
7. Authorized redirect URIs:
   - `https://YOUR_PROJECT_ID.firebaseapp.com/__/auth/handler`
   - `https://YOUR_PROJECT_ID.web.app/__/auth/handler`
8. Click **Create**
9. Copy the **Client ID** (you'll need it next)

#### 10.2 Enable Google OAuth in Terraform

1. Edit `terraform.auto.tfvars` again:

```hcl
identity_platform_google_oauth_enabled      = true
identity_platform_google_oauth_client_id     = "YOUR_CLIENT_ID.apps.googleusercontent.com"
identity_platform_google_oauth_client_secret = "YOUR_CLIENT_SECRET"  # From Step 10.1
```

2. Deploy the changes:

```bash
terraform plan
terraform apply
```

---

## 🔍 Troubleshooting

### **Error: "Failed to open state file"**

**Cause:** GCS bucket permissions issue

**Solution:**
```bash
# Ensure your account has access to the bucket
gsutil acl ch -u $(gcloud config get-value account):O gs://YOUR_BUCKET_NAME

# Then retry
terraform init
```

### **Error: "Cloud Build connection not found"**

**Cause:** Connection doesn't exist or wrong name

**Solution:**
1. Go to [Cloud Build Connections](https://console.cloud.google.com/cloud-build/connections)
2. Verify your connection exists
3. Copy the exact connection name from the console
4. Update `github_conn_name` in `terraform.auto.tfvars`

### **Error: "Firebase project not found"**

**Cause:** Firebase APIs not enabled or project not created

**Solution:**
```bash
# Try creating Firebase manually first
gcloud firebase projects create --project=YOUR_PROJECT_ID

# Or go to Firebase Console and create it
```

### **Terraform plan shows "Error: Resource already exists"**

**Cause:** Resources were partially created

**Solution:**
```bash
# Remove the state file and try again
rm -f terraform.tfstate terraform.tfstate.backup

terraform init
terraform plan
terraform apply
```

---

## ✅ Next Steps After Deployment

1. **Deploy Your Application:**
   - Push code to GitHub
   - Cloud Build will automatically build and deploy

2. **Configure Custom Domain (Optional):**
   - Firebase Hosting → Custom Domain
   - Point your domain to Firebase

3. **Set Up Monitoring (Optional):**
   - Cloud Console → Cloud Run → Services
   - Enable logging and monitoring

4. **Add Team Members (Optional):**
   - GCP Console → IAM & Admin → Manage Access

---

## 📚 Additional Documentation

- **[README.md](./README.md)** - Detailed setup instructions and troubleshooting
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Infrastructure architecture overview
- **[TERRAFORM_OUTPUTS_AND_CICD.md](./TERRAFORM_OUTPUTS_AND_CICD.md)** - CI/CD pipeline details
- **[Phase 2 & 3 Roadmap](./TERRAFORM_OUTPUTS_AND_CICD.md#-future-phases)** - Planned automation

---

## 🆘 Getting Help

If you get stuck:

1. Check the **Troubleshooting** section above
2. Review **[README.md](./README.md)** for detailed explanations
3. Check Terraform logs: `terraform log -json`
4. Review GCP Console for error messages
5. Check Cloud Build logs for deployment errors

---

**🎉 Congratulations! Your Creative Studio infrastructure is now deployed to Google Cloud!**

Next: Push your code to GitHub and watch Cloud Build automatically build and deploy your application.
