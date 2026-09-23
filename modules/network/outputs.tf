output "network_id" {
  description = "Full resource id of the VPC."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "Short name of the VPC."
  value       = google_compute_network.this.name
}

output "subnet_ids" {
  description = "Subnet ids, keyed by the same key used as input."
  value       = { for name, subnet in google_compute_subnetwork.this : name => subnet.id }
}

output "subnet_cidrs" {
  description = "Ranges actually created, to compare against what was intended."
  value       = { for name, subnet in google_compute_subnetwork.this : name => subnet.ip_cidr_range }
}

output "nat_enabled" {
  description = "Whether outbound internet access is currently provisioned and billed."
  value       = var.enable_nat
}
