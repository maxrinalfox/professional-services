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

output "connection_name" {
  description = "Cloud SQL connection name (for Cloud SQL Connector, use in Python Connector)"
  value       = google_sql_database_instance.default.connection_name
}

output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.default.name
}

output "public_ip_address" {
  description = "Public IP address of the Cloud SQL instance (for local development connections)"
  value       = google_sql_database_instance.default.public_ip_address
}

output "private_ip_address" {
  description = "Private IP address of the Cloud SQL instance (for VPC connections)"
  value       = google_sql_database_instance.default.private_ip_address
}

output "db_name" {
  description = "PostgreSQL database name"
  value       = google_sql_database.default.name
}

output "db_user" {
  description = "PostgreSQL database user"
  value       = google_sql_user.default.name
}

output "postgres_version" {
  description = "PostgreSQL database version"
  value       = google_sql_database_instance.default.database_version
}

output "region" {
  description = "GCP region where the Cloud SQL instance is deployed"
  value       = google_sql_database_instance.default.region
}
