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

output "network_id" {
  description = "VPC network ID"
  value       = google_compute_network.default.id
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.default.name
}

output "network_link" {
  description = "VPC network self link"
  value       = google_compute_network.default.self_link
}

output "primary_subnet_link" {
  description = "Primary subnetwork self link"
  value       = google_compute_subnetwork.primary.self_link
}

output "connector_subnet_name" {
  description = "Connector subnetwork name"
  value       = google_compute_subnetwork.connector.name
}

output "vpc_connector_id" {
  description = "Serverless VPC Connector ID"
  value       = google_vpc_access_connector.default.id
}

output "vpc_connector_name" {
  description = "Serverless VPC Connector name"
  value       = google_vpc_access_connector.default.name
}

output "private_service_connection" {
  description = "Private service networking connection ID"
  value       = google_service_networking_connection.private_vpc_connection.id
}
