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

# Allow internal communication within VPC
resource "google_compute_firewall" "allow_internal" {
  name      = "${var.name}-allow-internal"
  network   = google_compute_network.default.id
  project   = var.project_id
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.primary_subnet_cidr, var.connector_subnet_cidr]
}

# Allow Cloud SQL access from VPC Connector
resource "google_compute_firewall" "allow_cloudsql" {
  name      = "${var.name}-allow-cloudsql"
  network   = google_compute_network.default.id
  project   = var.project_id
  direction = "EGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["cloudsql-client"]
}
