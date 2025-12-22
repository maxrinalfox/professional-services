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

variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
  nullable    = false
}

variable "gcp_region" {
  description = "Default subnetwork region"
  type        = string
  nullable    = false
}

variable "name" {
  description = "VPC network name"
  type        = string
  nullable    = false
  default     = "creative-studio"
}

variable "primary_subnet_cidr" {
  description = "Primary subnetwork IP address range for Cloud Run and general services"
  type        = string
  nullable    = false
  default     = "10.0.0.0/24"
}

variable "connector_subnet_cidr" {
  description = "Subnetwork IP address range for Serverless VPC Connector"
  type        = string
  nullable    = false
  default     = "10.0.1.0/28"
}

variable "private_service_cidr" {
  description = "Private IP address range for Google-managed services (VPC peering)"
  type        = string
  nullable    = false
  default     = "10.1.0.0/16"
}
