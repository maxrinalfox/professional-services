# Creative Studio Infrastructure

This repository contains the Terraform configuration for deploying the Creative Studio application platform (frontend and backend) to Google Cloud.

## 🚀 Quick Links

- **[QUICK_START.md](./QUICK_START.md)** ⭐ **START HERE** - Step-by-step setup guide (60-90 minutes)
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Infrastructure architecture overview
- **[TERRAFORM_OUTPUTS_AND_CICD.md](./TERRAFORM_OUTPUTS_AND_CICD.md)** - CI/CD pipeline and Phase roadmap

## 🚀 Overview

This infrastructure is managed using a modular, environment-based approach with Terraform. The key principles are:
* **Don't Repeat Yourself (DRY):** All the logic for creating a service is defined once in a reusable **module**.
* **Strong Isolation:** Each environment (`dev`, `prod`, etc.) is managed in its own directory, with its own state file, to prevent accidental changes to production.
* **Phase-Based Automation:** Infrastructure deployment happens in phases:
  - **Phase 1** (Now): Manual Firebase setup + Terraform deployment
  - **Phase 2** (Planned): Terraform auto-creates Firebase project & web app
  - **Phase 3** (Planned): Terraform auto-creates OAuth credentials

## 📁 Directory Structure

The project is organized into `modules` and `environments`.

```
infrastructure/
│
├── modules/                # Reusable "Blueprints"
│   ├── cloud-run-service/  # Defines how to build ONE service
│   └── platform/           # Defines the ENTIRE application platform
│
└── environments/
    ├── dev/                # Configuration for the 'dev' environment
    │   ├── main.tf         # Calls the platform module with dev values
    │   ├── backend.tf      # Defines where to store the dev state file
    │   └── dev.tfvars      # Contains all variables for dev
    │
    └── prod/               # Configuration for the 'prod' environment
        └── ...
```
* **`/modules`**: Contains reusable building blocks. The `platform` module is the main entry point, which in turn uses the `cloud-run-service` module.
* **`/environments`**: Contains a directory for each distinct deployment environment. These directories call the `platform` module with the correct set of variables.

---
## ⚠️ Pre-Deployment Guide

### 🔄 Complete Deployment Flow (Current + Future Phases)

The deployment process has multiple phases:

**Phase 1A: GCP, Firebase & Identity Platform Setup** (Currently: Manual Firebase, Terraform-Automated Identity Platform)
| Step | Current Approach | Future (Phase 2) | Status |
|------|------------------|------------------|--------|
| 1. Create GCP Project | GCP Console | `terraform apply` | Manual |
| 2. Create Firebase Project | Firebase Console | `google_firebase_project` | Manual |
| 3. Create Firebase Web App | Firebase Console | `google_firebase_web_app` | Manual |
| 4. Get Firebase App ID | `gcloud firebase apps list` | Auto-output | Manual |
| 5. Create Cloud Build Connection | GCP Console | Still manual (GCP limitation) | Manual |
| 6. Setup Identity Platform | ✅ **NOW IN TERRAFORM** | `google_identity_platform_config` | **✅ Implemented** |
| 7. Setup OAuth (Optional) | ✅ **NOW IN TERRAFORM** | `google_identity_platform_oauth_idp_config` | **✅ Implemented** |

**Phase 1B: Configure Terraform** (5 minutes)
- Edit `terraform.auto.tfvars` with values from Phase 1A
- Set `firebase_web_app_id` (from Step 4 above)
- Set GitHub configuration

**Phase 1C: Deploy Infrastructure** (15 minutes)
- `terraform init && terraform plan && terraform apply`
- Terraform auto-discovers Firebase SDK config
- Creates all cloud resources

**Phase 1D: Verify** (5 minutes)
- Check secrets created in Secret Manager
- Test deployed services

⏸️ **FOR NOW: Follow the "Manual Setup Steps" below** (Steps 1-6 above, manual column)

ℹ️ **FUTURE (Phase 2):** Steps 1-4 will be fully Terraform-automated. See `TERRAFORM_OUTPUTS_AND_CICD.md` for roadmap.

---

## 📋 Terraform Prerequisites & System Requirements

Before starting the manual setup steps, ensure your environment meets these prerequisites:

### System Requirements
- **Terraform CLI** v1.13+ installed and in PATH
- **Google Cloud SDK (gcloud CLI)** installed
- **jq** (JSON processor) for script operations
- **bash** 4.0+ for running deployment scripts

### Google Cloud Project Requirements
- ✅ GCP Project must already exist (created via [GCP Console](https://console.cloud.google.com/))
- ✅ **IMPORTANT:** User account must have accepted [Firebase Terms of Service](https://firebase.google.com/) before proceeding
- ✅ **IMPORTANT:** Billing account must be enabled on the project (required for Blaze plan features)
  - Without billing, some Google Cloud services will not be available
  - Go to: GCP Console → Billing → Link a billing account to this project
- ✅ Service account with sufficient IAM permissions (recommended: Editor or custom role with specific permissions)
- ✅ **IMPORTANT:** Project label `firebase = "enabled"` may be required for some Firebase features
  - Check: GCP Console → Project → Labels → Add label if missing

### Terraform & Provider Requirements
- **google provider** v5.0+ (for standard Google Cloud resources)
- **google-beta provider** v5.0+ (for Firebase resources and beta features)
- **hashicorp/random provider** (for password generation)
- **Backend:** GCS bucket for remote state storage (created manually in Step 3b)

### API Requirements
The platform module automatically enables **17 required Google Cloud APIs**:
- Core APIs: Cloud Billing, Cloud Resource Manager, Service Usage, IAM, IAM Credentials
- Firebase APIs: Firebase, Firebase Hosting, Identity Toolkit, Firestore
- Compute: Compute Engine, Cloud Run, VPC Access
- Database: Cloud SQL Admin
- CI/CD: Cloud Build, Artifact Registry
- Logging & Security: Cloud Logging, Secret Manager
- Optional: Cloud Functions, Vertex AI, Text-to-Speech

**Note:** You don't need to enable these manually - the platform module does it automatically during `terraform apply`.

### GitHub & Cloud Build Requirements
- ✅ GitHub repository (public or private) with the Creative Studio source code
- ✅ Cloud Build connection to GitHub created and authorized
  - This cannot be fully automated (GCP limitation) and must be done manually in GCP Console
  - See: Manual Setup Step #5 below

---

## ⚠️ Manual Setup Steps (Current Phase 1)

Before you can use Terraform, you must perform these one-time manual steps in this order:

### 1. Install Prerequisite Software
You must install the following command-line tools on your local machine:
* **Terraform CLI:** [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
```bash
# After you download the terraform binary
$ sudo cp ./terraform /usr/local/bin
$ sudo chmod +x /usr/local/bin/terraform

$ terraform version
Terraform v1.13.0
on linux_amd64
```
* **Google Cloud SDK:** [Install gcloud](https://cloud.google.com/sdk/docs/install)

### 2. Accept Firebase Terms of Service ⭐ CRITICAL

Before you can use Firebase, your Google account must accept the Firebase Terms of Service:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Sign in with the Google account you'll use for deployment
3. Accept the Firebase Terms of Service when prompted
4. This is a one-time requirement per Google account

**Why this matters:** Firebase APIs won't work without this acceptance, and `terraform apply` will fail.

### 3. Enable Billing Account ⭐ CRITICAL

Google Cloud services (including Firebase) require a billing account:

1. Go to [GCP Console](https://console.cloud.google.com/) → **Billing**
2. Click **Link a billing account**
3. Create or select an existing billing account
4. Link it to your GCP project
5. Verify billing is enabled: GCP Console → Project Settings → Billing Account should show your account

**Why this matters:** Without billing enabled, some Google Cloud APIs will not work, and deployment will fail.

### 4. Authenticate with Google Cloud
You need to authenticate your local machine with Google Cloud. This command will open a browser for you to log in.
```bash
gcloud auth login
gcloud auth list
gcloud config set project <your project id>
```

### 5. Create Firebase Project & Web App ⭐ CRITICAL

**⚠️ IMPORTANT: These can now be fully automated with Terraform (Phase 2)!**

**Option A: Let Terraform Create Them (RECOMMENDED - Phase 2 Automation)**
- Firebase Project will be created by: `google_firebase_project` resource
- Firebase Web App will be created by: `google_firebase_web_app` resource
- Web App ID will be auto-discovered by: `data "google_firebase_web_app_config"` data source
- **Result:** No manual Firebase Console steps needed!
- **Status:** Phase 2 ready to implement (~2 hours)
- See: [Phase 2 Implementation Plan in TERRAFORM_OUTPUTS_AND_CICD.md](./TERRAFORM_OUTPUTS_AND_CICD.md#⏳-phase-2-next---ready-to-implement-firebase-project--web-app-automation)

**Option B: Create Manually in Firebase Console (Current Phase 1 - if Phase 2 not yet implemented)**
This approach requires manual creation in the Firebase Console:

**5a. Create Firebase Project (Manual)**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project**
3. Select your GCP project (the one with billing enabled)
4. Enable Google Analytics (optional)
5. Wait for creation to complete (2-3 minutes)

**5b. Create Firebase Web App (Manual)**
1. In Firebase Console, go to **Project Settings** → **Your apps**
2. Click **Add app** → Choose **Web** (</> icon)
3. Register app with name: `cstudio-fe` (or your choice)
4. Copy the Firebase SDK config shown (but you don't need it - Terraform will auto-discover!)
5. **Get the Firebase Web App ID for Terraform:**
   ```bash
   gcloud firebase apps list --project=YOUR_GCP_PROJECT_ID
   # Output example:
   # 1:123456789:web:abc123xyz456def
   # Copy this value → Use as firebase_web_app_id in terraform.auto.tfvars
   ```

📖 **Reference:** Based on [Firebase Terraform Getting Started Guide](https://firebase.google.com/docs/projects/terraform/get-started)

### 6. Create a GCS Bucket for Terraform State
Terraform needs a GCS bucket to store its state file for each environment. This must be done manually because the backend configuration is read before Terraform can create any resources.

**Run this command for each environment (dev, prod, etc.), making sure to use a globally unique bucket name:**
```bash
# Example for the 'dev' environment
export PROJECT_ID=your-gcp-project && \
gsutil mb -p $PROJECT_ID gs://$PROJECT_ID-cstudio-dev-tfstate
```

### 7. Connect GitHub to Cloud Build (Manual - Phase 2 Still Needed)
You must authorize Google Cloud Build to access your GitHub repository. This cannot be automated and must be done manually.

1.  Go to the Google Cloud Console: **Cloud Build > Manage connections**.
2.  Click **Create connection**.
3.  Choose **GitHub (Cloud Build GitHub App)** as the source.
4.  Follow the prompts to authenticate and install the GitHub App on your account.
5.  Grant access to your GitHub repository.
6.  Note the **Connection Name** (e.g., `github-conn`) as you will need it for `terraform.auto.tfvars`.

**Why it's manual:** GCP doesn't provide a Terraform resource to create Cloud Build connections (this is a GCP limitation, not a Terraform limitation). You must create the connection in the GCP Console, then reference it in Terraform.

### 8. Setup OAuth Client ID (if using authentication)
This step creates the OAuth Client ID that will be used for authentication. Currently, this must be done manually.

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **APIs & Services** → **Credentials**
3. Click **Create Credentials** → **OAuth 2.0 Client ID**
4. Choose **Web application** as the application type
5. Add authorized redirect URIs (you can add these later):
   - `https://{your-domain}/auth/callback`
   - `http://localhost:3000/auth/callback` (for local testing)
6. Click **Create**
7. Copy the **Client ID** (not the Client Secret)
8. Use this value in `terraform.auto.tfvars` for:
   - `backend_custom_audiences` - Add Client ID to this list
   - `frontend_custom_audiences` - Add Client ID to this list
   - `identity_platform_google_oauth_client_id` - Set to your OAuth Client ID
   - `backend_runtime_secrets` mapping - Will fetch GOOGLE_TOKEN_AUDIENCE from Secret Manager

### 8a. OAuth Credential Management (Unified)

**Single OAuth 2.0 Client ID for Both Services**

The system uses a **unified OAuth credential** (`OAUTH_CLIENT_ID`) for both frontend and backend:

- **Frontend:** Cloud Build injects it into the application as `GOOGLE_CLIENT_ID`
- **Backend:** Cloud Run mounts it as `GOOGLE_TOKEN_AUDIENCE` environment variable
- **Same value:** Both services use the identical OAuth Client ID

#### Setup Steps

1. **Create OAuth Client ID in GCP Console** (one-time)
   - Navigate to: [APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials)
   - Create new "OAuth 2.0 Client ID" of type "Web application"
   - Add authorized redirect URIs:
     - `https://{PROJECT_ID}.firebaseapp.com/__/auth/handler`
     - `https://{PROJECT_ID}.web.app/__/auth/handler`

2. **Populate the Secret** (one-time, used by both services)
   ```bash
   gcloud secrets versions add OAUTH_CLIENT_ID \
     --data-file=- \
     --project={GCP_PROJECT_ID} \
     <<< "YOUR_CLIENT_ID.apps.googleusercontent.com"
   ```

#### How It Works

Terraform's `core/secrets` module automatically:
1. **Creates** the unified `OAUTH_CLIENT_ID` secret in Secret Manager
2. **Grants permissions** to three service accounts:
   - Frontend Cloud Build trigger (for build-time injection)
   - Backend Cloud Build trigger (for validation)
   - Backend Cloud Run runtime (for token validation)
3. **Maps** the secret to environment variable names:
   - Frontend receives: `OAUTH_CLIENT_ID` → injected as `GOOGLE_CLIENT_ID`
   - Backend receives: `OAUTH_CLIENT_ID` → mounted as `GOOGLE_TOKEN_AUDIENCE`

**No Terraform configuration needed** - secrets are managed entirely within the platform module's `app_secrets` configuration.

**Important Security Notes:**
- Secrets are NEVER stored in `.tfvars` or version control
- `GOOGLE_TOKEN_AUDIENCE` is NOT in `be_env_vars` (it's always a secret)
- Secret-to-environment-variable mapping is transparent via `secret_key_ref`
- Database password is auto-generated and stored separately in Secret Manager

### 8b. Build-Time Secret Validation

Both frontend and backend Cloud Build pipelines validate that secrets are properly configured:

**Frontend Validation** (`frontend/cloudbuild-deploy.yaml`):
- ✅ Checks if `OAUTH_CLIENT_ID` is populated (not empty)
- ✅ Fails with clear error message if missing or contains placeholder value
- ✅ Provides exact command to fix the issue

**Backend Validation** (`backend/cloudbuild.yaml`):
- ✅ Checks if `GOOGLE_TOKEN_AUDIENCE` is populated (not empty)
- ✅ Fails with clear error message if missing or contains placeholder value
- ✅ Explains the relationship to `OAUTH_CLIENT_ID` secret
- ✅ Shows exact command to populate the secret

**Why Build-Time Validation?**
- Fast-fail: Errors caught during build, not at runtime
- Clear feedback: Users know exactly what to fix
- No wasted resources: Prevents failed Cloud Run deployments

### 9. Configure Terraform & Deploy Infra
#### 🛠️ Managing Environments

All commands should be run from within a specific environment's directory.

#### Creating a New Environment (e.g., `staging`)

**One Environment Per Directory:** Each directory deploys to ONE environment only. Configuration is flat and simple.

1.  **Perform Manual Setup:** Create a new GCS bucket for the staging state (see Manual Step #3 above).
2.  **Create the Directory:** Copy the template: `cp -r environments/dev-infra-example environments/staging`
3.  **Configure `backend.tf`:** Edit `environments/staging/backend.tf` to point to your new staging GCS bucket.
4.  **Configure `terraform.auto.tfvars`:** Update the file with:
    - `gcp_project_id`, `gcp_region`, and `environment = "staging"`
    - Update `be_env_vars` (simple flat map):
      ```hcl
      be_env_vars = {
        LOG_LEVEL                       = "INFO"
        ENVIRONMENT                     = "staging"
        FIREBASE_DB                     = "cstudio-staging"
        IDENTITY_PLATFORM_ALLOWED_ORGS  = ""
      }
      ```
    - Update service names and other values for staging
5.  **Deploy:**
    ```bash
    cd environments/staging
    terraform init
    terraform apply
    ```


#### Deploying an Existing Environment (e.g., `dev`)

1.  **Navigate to the `dev` directory:**
    ```bash
    cd environments/dev
    ```
2.  **Initialize Terraform:**
    This downloads the necessary providers and configures the remote state backend.
    ```bash
    terraform init
    ```
3.  **Plan the changes:**
    Always review the plan carefully before applying.
    ```bash
    terraform plan -var-file="dev.tfvars"
    ```
4.  **Apply the changes:**
    This will build and deploy the infrastructure.
    ```bash
    terraform apply -var-file="dev.tfvars"
    ```

---

## ✅ Pre-Deployment Verification Checklist

Before running `terraform apply`, verify all prerequisites are complete:

### Prerequisites Completion (Done Once Per Google Account/Project)

**System Requirements:**
- [ ] Terraform v1.13+ installed: `terraform version`
- [ ] Google Cloud SDK installed: `gcloud version`
- [ ] jq installed (JSON processor): `jq --version`
- [ ] bash 4.0+ available: `bash --version`

**Google Cloud Account & Project Setup:**
- [ ] Google account has accepted [Firebase Terms of Service](https://firebase.google.com/)
- [ ] GCP Project created: Go to [GCP Console](https://console.cloud.google.com/)
- [ ] Billing account linked to project: GCP Console → Billing → Verify account is linked
- [ ] Authenticated with gcloud: `gcloud auth login && gcloud config set project YOUR_PROJECT_ID`
- [ ] Service account permissions verified (Editor role or custom permissions)
- [ ] (Optional) Project labeled with `firebase="enabled"` in GCP Console → Labels

**Firebase Setup:**
- [ ] Firebase Project created: [Firebase Console](https://console.firebase.google.com/) → Add Project
- [ ] Firebase Web App created (name: `cstudio-fe`)
- [ ] Firebase Web App ID obtained: `gcloud firebase apps list --project=YOUR_PROJECT`
  - Format: `1:PROJECT_NUMBER:web:HASH` (e.g., `1:123456789:web:abc123xyz456def`)

**GitHub & Cloud Build:**
- [ ] GitHub repository created and accessible
- [ ] Cloud Build connection to GitHub created: GCP Console → Cloud Build → Manage connections
  - Connection name noted (e.g., `github-conn`)
- [ ] GitHub App authorized in Cloud Build

**OAuth Configuration (if using authentication):**
- [ ] OAuth 2.0 Client ID created: GCP Console → APIs & Services → Credentials
  - Application type: Web application
  - Redirect URIs added
  - Client ID copied (not the secret)

**Terraform State Backend:**
- [ ] GCS bucket created for Terraform state: `gsutil mb -p $PROJECT_ID gs://$PROJECT_ID-cstudio-ENV-tfstate`
- [ ] Bucket name ready to use in `backend.tf`

### Configuration Files Setup (Done Per Environment)

**Terraform Files:**
- [ ] `terraform.auto.tfvars` (or `ENV.tfvars`) created and filled:
  - [ ] `gcp_project_id` = YOUR_GCP_PROJECT_ID
  - [ ] `gcp_region` = YOUR_REGION (e.g., `us-central1`)
  - [ ] `environment` = dev|staging|prod
  - [ ] `firebase_web_app_id` = 1:PROJECT_NUMBER:web:HASH
  - [ ] `github_repo_owner` = YOUR_GITHUB_USERNAME
  - [ ] `github_repo_name` = creative-studio (or your repo name)
  - [ ] `github_branch_name` = main (or your deployment branch)
  - [ ] `github_conn_name` = github-conn (or your connection name)
  - [ ] `be_env_vars` configured with your environment values

**Secrets Management:**
- [ ] No additional configuration needed - Terraform manages all secrets
- [ ] Secrets are created and permissions granted automatically via `core/secrets` module
- [ ] After `terraform apply`, manually populate `OAUTH_CLIENT_ID` secret (see section 8a above)

**Backend Configuration:**
- [ ] `backend.tf` exists and points to correct GCS bucket

### Ready to Deploy

Once all items above are checked:
```bash
cd environments/YOUR_ENVIRONMENT
terraform init
terraform validate  # Should succeed with no errors
terraform plan      # Review the plan carefully
terraform apply     # Deploy infrastructure
```

---

## 📚 Documentation Index

For comprehensive guides on specific topics, refer to:

| Document | Purpose | When to Use |
|----------|---------|------------|
| **[ARCHITECTURE.md](./ARCHITECTURE.md)** | Network design, VPC setup, data flow diagrams, security architecture | Understanding how the infrastructure is organized and connected |
| **[TERRAFORM_OUTPUTS_AND_CICD.md](./TERRAFORM_OUTPUTS_AND_CICD.md)** | Accessing terraform outputs, CI/CD integration, bash script patterns, GitHub Actions examples | Using outputs in scripts, migrating to GitHub Actions, CI/CD automation |

### Quick CI/CD Reference

#### For Bash Scripts

Extract outputs in your bash scripts using these patterns:

**Single Value (simple):**
```bash
PROJECT_ID=$(terraform output -raw gcp_project_id 2>/dev/null)
```

**Multiple Values (one call):**
```bash
OUTPUTS=$(terraform output -json)
PROJECT_ID=$(echo "$OUTPUTS" | jq -r .gcp_project_id.value)
FRONTEND_SECRETS=$(echo "$OUTPUTS" | jq -r .frontend_secrets.value[])
```

**Optional Outputs (with fallback):**
```bash
BACKEND_URL=$(terraform output -raw backend_service_url 2>/dev/null || echo "")
```

For detailed patterns, examples, and error handling → See [TERRAFORM_OUTPUTS_AND_CICD.md - Section 3.5](./TERRAFORM_OUTPUTS_AND_CICD.md#35-real-world-bash-script-patterns)

#### For GitHub Actions Workflows

Extract and use outputs in your GitHub Actions pipelines:

```yaml
- name: Get Infrastructure Outputs
  id: infra
  run: |
    cd infra/environments/${{ env.ENV_NAME }}
    terraform init
    TF_OUT=$(terraform output -json)
    echo "project=$(echo $TF_OUT | jq -r .gcp_project_id.value)" >> $GITHUB_OUTPUT
    echo "sql_conn=$(echo $TF_OUT | jq -r .cloud_sql_connection_name.value)" >> $GITHUB_OUTPUT

- name: Use Outputs
  run: |
    echo "Project: ${{ steps.infra.outputs.project }}"
    echo "SQL: ${{ steps.infra.outputs.sql_conn }}"
```

For complete workflow examples → See [TERRAFORM_OUTPUTS_AND_CICD.md - Section 5-6](./TERRAFORM_OUTPUTS_AND_CICD.md#5-modern-github-actions-approach)

