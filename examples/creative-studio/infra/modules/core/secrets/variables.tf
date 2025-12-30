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

variable "gcp_project_id" {
  type        = string
  description = "The GCP Project ID where the secrets will be created."
}

variable "secrets_config" {
  type = map(object({
    description = optional(string, "")
    accessors   = list(string)
  }))
  description = <<-EOT
    Configuration for secrets to create and who should have access to them.

    Structure:
    {
      "SECRET_NAME" = {
        description = "Optional description"
        accessors   = [
          "serviceAccount:sa1@project.iam.gserviceaccount.com",  # Full member format
          "user:email@example.com"                                # Can use any IAM member format
        ]
      }
    }

    Each secret is created with the specified accessors granted the Secret Manager Accessor role.
    Multiple accessors can be specified for a single secret.

    Accessor format: Pass the .member attribute of service account resources.
    Example: google_service_account.my_sa.member
  EOT

  validation {
    condition = alltrue([
      for secret_name, config in var.secrets_config :
      length(config.accessors) > 0
    ])
    error_message = "Each secret must have at least one accessor."
  }
}
