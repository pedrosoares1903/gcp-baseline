variable "project_id" {
  description = "The GCP project everything in this repository lives in."
  type        = string
}

variable "region" {
  description = "Default region for regional resources."
  type        = string
  default     = "europe-west1"
}

variable "github_owner" {
  description = <<-EOT
    GitHub account or organisation that owns the repository.
    Only tokens issued to this owner are accepted by the identity pool.
  EOT
  type        = string
}

variable "github_repository" {
  description = "Repository in owner/name form, for example pedro/gcp-baseline."
  type        = string
}

variable "state_bucket_name" {
  description = <<-EOT
    Globally unique name for the Terraform state bucket.
    Bucket names are shared across all of Google Cloud, so include the project id.
  EOT
  type        = string
}
