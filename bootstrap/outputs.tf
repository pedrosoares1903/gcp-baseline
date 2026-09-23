output "workload_identity_provider" {
  description = "Paste into the WIF_PROVIDER repository variable on GitHub."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "ci_service_account" {
  description = "Paste into the CI_SERVICE_ACCOUNT repository variable on GitHub."
  value       = google_service_account.terraform_ci.email
}

output "state_bucket" {
  description = "Hardcode into every environments/*/backend.tf."
  value       = google_storage_bucket.state.name
}
