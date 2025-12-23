# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Cloud Run Job for Database Bootstrap and Seeding
#
# This job runs the bootstrap.py script which:
# 1. Runs Alembic migrations to set up database schema
# 2. Creates initial admin user
# 3. Seeds templates, assets, and other data
#
# The job has VPC access to reach private Cloud SQL when vpc_enable=true
# It uses the same container image as the backend service

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

resource "google_cloud_run_v2_job" "bootstrap" {
  name         = var.job_name
  location     = var.region
  project      = var.project_id
  launch_stage = "GA"

  template {
    service_account = var.service_account_email
    timeout         = "${var.timeout}s"
    task_count      = 1

    containers {
      image = var.container_image

      # Regular environment variables
      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret environment variables from Secret Manager
      dynamic "env" {
        for_each = var.secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret_id
              version = "latest"
            }
          }
        }
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }
    }

    # VPC Access for private Cloud SQL connectivity
    dynamic "vpc_access" {
      for_each = var.vpc_connector_id != null ? [1] : []
      content {
        connector = var.vpc_connector_id
        egress    = "PRIVATE_RANGES_ONLY"
      }
    }
  }

  depends_on = [
    # Module dependencies are handled by caller
  ]
}

# Optional: Cloud Logging sink for bootstrap job logs
resource "google_logging_project_sink" "bootstrap_logs" {
  name        = "${var.job_name}-logs"
  destination = "logging.googleapis.com/projects/${var.project_id}/logs/${var.job_name}"

  filter = "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"${var.job_name}\""

  unique_writer_identity = true
}
