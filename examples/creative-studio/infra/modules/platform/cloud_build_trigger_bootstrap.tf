
# Cloud Build trigger for bootstrap job
# Manages the complete lifecycle of the Cloud Run Job:
# - Creates the job on first run with all configuration (env vars, VPC, resources)
# - Updates the job with new image and refreshed environment variables on subsequent runs
# - Executes the job after creation/update
# Triggers on push to configured branch when backend/bootstrap/** files change
resource "google_cloudbuild_trigger" "bootstrap" {
  # count           = (var.enable_cloud_build && var.enable_cloud_run_job) ? 1 : 0
  count           = 1 
  name            = "cstudio-bootstrap-trigger"
  location        = var.gcp_region
  service_account = google_service_account.bootstrap_trigger_sa[0].id
  filename        = "examples/creative-studio/backend/cloudbuild-bootstrap.yaml"
  project         = var.gcp_project_id

  repository_event_config {
    repository = local.source_repository_id
    push {
      branch = "^${var.github_branch_name}$"
    }
  }

  # Only trigger when bootstrap files or configuration changes (not on every push)
  included_files = [
    "**/creative-studio/backend/bootstrap/**",
    "**/creative-studio/backend/Dockerfile.bootstrap",
    "**/creative-studio/backend/cloudbuild-bootstrap.yaml"
  ]

  substitutions = {
    _BOOTSTRAP_JOB_NAME   = var.bootstrap_job_name != null ? var.bootstrap_job_name : "cstudio-bootstrap-${var.environment}"
    _BOOTSTRAP_IMAGE_NAME = var.bootstrap_image_name
    _REPO_NAME            = google_artifact_registry_repository.bootstrap_repo[0].repository_id
    _REGION               = var.gcp_region
  }

  depends_on = [
    google_service_account.bootstrap_trigger_sa,
    google_artifact_registry_repository.bootstrap_repo
  ]
}
