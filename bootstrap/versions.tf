terraform {
  # `removed` blocks need 1.7, `import` blocks need 1.5. 1.13 is what this
  # repository was written against — check yours with `terraform version`.
  required_version = "~> 1.13"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.1"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}