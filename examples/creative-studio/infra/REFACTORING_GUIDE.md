# Infrastructure Refactoring Guide - Option B: Comprehensive Reorganization

## Current Status
✅ New directory structure created
✅ Files copied to new locations:
  - `/modules/data/postgresql/` - Database module
  - `/modules/networking/` - VPC module (from vpc_network/)
  - `/modules/services/backend/` - Backend service (from cloud-run-service/)
  - `/modules/services/frontend/` - Frontend service (from firebase-hosting-service/)
  - `/modules/core/secrets/` - Secret manager module
  - `/modules/core/project-setup/` - New project setup module (partially created)
  - `/modules/core/storage/` - New storage module (partially created)

## Next Steps (Phase 1: Core Module Skeleton)

### 1. Complete Core Modules
```
core/
├── project-setup/ ✅ (started)
│   ├── main.tf (APIs, project config)
│   ├── variables.tf ✅
│   └── outputs.tf
├── storage/ ✅ (started)
│   ├── main.tf ✅
│   ├── variables.tf ✅
│   └── outputs.tf
├── firebase/ (NEW)
│   ├── main.tf (Firebase project, web app, Identity Platform)
│   ├── variables.tf
│   └── outputs.tf
└── secrets/ ✅ (copied)
    └── (use existing secret-manager module files)
```

### 2. Create Firebase Core Module
Extract from current platform/main.tf (lines 115-196):
- google_firebase_project
- google_firebase_web_app
- google_identity_platform_config
- data "google_firebase_web_app_config"
- Local variables for Firebase SDK config
- Secret creation and IAM for Firebase secrets

### 3. Split Services to Be Autonomous

#### Backend Service (`services/backend/`)
Add new files:
- `secrets.tf` - Create backend secrets + IAM bindings
- `iam.tf` - Runtime service account IAM for secrets
- `variables.tf` - Update with secret management variables
- Keep existing: `main.tf`, `outputs.tf`

Extract from platform/main.tf:
- Backend-specific secret creation
- Backend runtime secret IAM bindings

#### Frontend Service (`services/frontend/`)
Add new files:
- `secrets.tf` - Create frontend secrets + IAM bindings
- `variables.tf` - Update with secret management variables
- Keep existing: `main.tf`, `outputs.tf`

Extract from platform/main.tf:
- Frontend secret creation logic
- Frontend trigger SA secret access IAM

### 4. Create Bootstrap Module
Extract from platform/main.tf (lines 483-517):
- `bootstrap/main.tf` containing:
  - Cloud Build repository connection
  - Bootstrap service account
  - Artifact registry for bootstrap
  - Cloud Run Job Cloud Build trigger
  - All related IAM bindings

Files needed:
```
bootstrap/
├── main.tf
├── cloud_build_trigger.tf
├── variables.tf
└── outputs.tf
```

### 5. Refactor Platform Module
New simplified `platform/main.tf` that only calls modules:
```hcl
module "project_setup" {
  source = "../core/project-setup"
  gcp_project_id = var.gcp_project_id
}

module "storage" {
  source = "../core/storage"
  ...
}

module "firebase" {
  source = "../core/firebase"
  ...
}

module "networking" {
  source = "../networking"
  ...
}

module "postgresql" {
  source = "../data/postgresql"
  ...
}

module "backend_service" {
  source = "../services/backend"
  ...
}

module "frontend_service" {
  source = "../services/frontend"
  ...
}

module "bootstrap" {
  source = "../bootstrap"
  ...
}
```

## Phase 2: Update Source Paths

### Update environment modules
Files: `environments/dev-infra-example/main.tf` and `environments/prod_ops_sandbox/main.tf`

Change module sources:
```
# OLD paths
module "creative_studio_platform" {
  source = "../../modules/platform"
}

# NEW paths (if using nested structure)
module "creative_studio_platform" {
  source = "../../modules/platform"  # Platform becomes orchestrator
}
```

### Update service references if standalone
If using services independently:
```
# Backend service source path
source = "../../modules/services/backend"

# Frontend service source path
source = "../../modules/services/frontend"
```

## Phase 3: Cleanup
After testing and validation:
1. Delete old directories (with caution):
   - `modules/cloud-run-service/` (copied to services/backend/)
   - `modules/firebase-hosting-service/` (copied to services/frontend/)
   - `modules/vpc_network/` (copied to networking/)
   - `modules/postgresql/` (copied to data/postgresql/)
   - `modules/secret-manager/` (copied to core/secrets/)
   - `modules/cloud-run-job/` (empty, never used)

2. Update documentation in `.md` files to reflect new structure

## Key Architectural Improvements

### Before (Monolithic):
- Platform module: 634 lines doing everything
- Services can't be used independently
- Secret management inconsistent
- Bootstrap tightly coupled

### After (Autonomous):
- Core modules: Infrastructure foundations
- Service modules: Self-contained, create their own secrets
- Bootstrap: Optional, separate module
- Platform: Clean orchestrator calling other modules
- Clearer separation of concerns
- Better testability and reusability

## Validation Checklist

After refactoring:
- [ ] `terraform validate` passes in each environment
- [ ] `terraform plan` shows no unexpected changes
- [ ] All module source paths resolve correctly
- [ ] No circular dependencies
- [ ] All variables flow correctly through module hierarchy
- [ ] All outputs properly propagated
- [ ] Secret creation happens in correct modules
- [ ] IAM bindings are complete and correct
- [ ] Documentation reflects new structure

## Estimated Impact
- ~40-50 file edits/creates
- ~300-400 lines of code moved/split
- All existing infrastructure continues to work
- No service downtime if applied correctly

## Questions/Decisions Needed

1. **Bootstrap Optional?** Should bootstrap module be conditionally called based on `enable_cloud_run_job`?
2. **Service Secret Pattern:** Should each service module manage all its secrets, or should they be passed from platform?
3. **Core/Services Boundaries:** Is there a clean cut, or are there cross-cutting concerns?
4. **Environment Reuse:** Do we want each environment to be able to mix-and-match services?

## Next Action
Once you confirm the approach above, provide specific guidance on:
1. Which modules to prioritize (Core > Services > Bootstrap > Cleanup)
2. Whether to do this in one commit or multiple commits
3. Testing/validation requirements before cleanup phase
