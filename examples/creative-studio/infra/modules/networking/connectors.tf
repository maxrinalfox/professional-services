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

# --- Serverless VPC Connector Configuration ---
# Allows Cloud Run to access private Cloud SQL and other VPC resources.
#
# IMPORTANT: The VPC Connector uses a DEDICATED SUBNET, not an IP CIDR range.
#
# Why use a dedicated subnet (not ip_cidr_range)?
# - The connector needs its own isolated address space
# - Cannot share the CIDR with existing subnetworks
# - If using ip_cidr_range directly, it creates IP conflicts with existing subnets
# - Must use a separate subnet via the "subnet" block (see below)
#
# Configuration:
# - Uses the dedicated connector_subnet (created in subnets.tf)
# - Subnet has its own CIDR range (default: 10.0.1.0/28)
# - Cannot overlap with primary_subnet_cidr or any other subnet
#
# Note: The connector_subnet is automatically created as part of this module.
#       Google Cloud manages the VPC Connector resources within this subnet.
resource "google_vpc_access_connector" "default" {
  name    = "${var.name}-cs"
  region  = var.gcp_region
  project = var.project_id

  # Use dedicated subnet instead of ip_cidr_range (fixes "IP CIDR range conflicts" error)
  subnet {
    name = google_compute_subnetwork.connector.name
  }

  min_instances = 2
  max_instances = 3
}
