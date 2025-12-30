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

# OPTIONAL: Remote Terraform State Backend
# ============================================================================
# Uncomment to store Terraform state in Google Cloud Storage (GCS) instead
# of local state. This is recommended for team deployments.
#
# SETUP:
# 1. Create GCS bucket: gsutil mb -p YOUR_PROJECT gs://YOUR_BUCKET_NAME
# 2. Replace bucket name and prefix below with your values
# 3. Uncomment the backend block
# 4. Run: terraform init (Terraform will migrate state to GCS)
#
# For local development only, you can skip this and use local state.
# ============================================================================

# terraform {
#   backend "gcs" {
#     bucket = "YOUR_PROJECT-cstudio-dev-tfstate"  # Replace with your bucket name
#     prefix = "infra/dev/state"                   # State file path in bucket
#   }
# }
