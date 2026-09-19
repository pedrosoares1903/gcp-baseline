locals {
  # serviceusage and cloudresourcemanager have to be enabled by hand once,
  # before this ever runs. Everything else is enabled from here.
  services = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
  ]

  # Roles the pipeline needs to manage the network baseline, and nothing more.
  # See the "Known limitations" section: networkAdmin is broader than ideal.
  ci_roles = [
    "roles/compute.networkAdmin",

    # networkAdmin covers networks and subnets but grants only *read* on firewall
    # rules — creating them needs securityAdmin. Found the hard way: dev had been
    # applied by hand, so the pipeline only hit this when it reached prod.
    "roles/compute.securityAdmin",

    "roles/serviceusage.serviceUsageAdmin"
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.services)

  project = var.project_id
  service = each.value

  # Leaving an API enabled costs nothing. Disabling one on destroy can break
  # things that have nothing to do with this configuration, so it is never
  # worth the tidiness.
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# State bucket. Everything else in this repository depends on it existing.
# ---------------------------------------------------------------------------

resource "google_storage_bucket" "state" {
  name     = var.state_bucket_name
  project  = var.project_id
  location = var.region

  # The only backup of a file that cannot be rebuilt from anything else.
  versioning {
    enabled = true
  }
  logging {
    log_bucket = google_storage_bucket.state_access_logs.name
  }

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle {
    # This bucket holds the record of everything this repository manages.
    # Destroying it does not destroy the infrastructure — it destroys the only
    # thing that knows the infrastructure is ours.
    prevent_destroy = true
  }

  depends_on = [google_project_service.required]
}

# ---------------------------------------------------------------------------
# Identity: GitHub Actions authenticates with a short-lived token, no key.
# ---------------------------------------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  description               = "Identities for GitHub Actions workflows."

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  # checkov:skip=CKV_GCP_125: requires pinning assertion.sub to one ref; this pipeline authenticates from pull requests as well as main. Trust is scoped by repository_owner + repository in the condition below, and by the service account binding on attribute.repository.
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.owner"      = "assertion.repository_owner"
  }

  # The single most important line in this repository.
  #
  # Without it, a workflow in ANY repository on GitHub can present a token to
  # this pool. Google refuses to create a GitHub provider that has no attribute
  # condition, which is the only reason this is hard to get wrong.
  attribute_condition = "assertion.repository_owner == \"${var.github_owner}\" && assertion.repository == \"${var.github_repository}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "terraform_ci" {
  project      = var.project_id
  account_id   = "terraform-ci"
  display_name = "Terraform CI"
  description  = "Impersonated by the GitHub Actions pipeline. No key is ever created for it."

  depends_on = [google_project_service.required]
}

# The pool is restricted to the owner; this narrows it further to one repository.
resource "google_service_account_iam_member" "ci_impersonation" {
  service_account_id = google_service_account.terraform_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

resource "google_project_iam_member" "terraform_ci" {
  for_each = toset(local.ci_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform_ci.email}"
}

resource "google_storage_bucket_iam_member" "terraform_ci_state" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform_ci.email}"
}

resource "google_storage_bucket" "state_access_logs" {
  # checkov:skip=CKV_GCP_62: this IS the access-log bucket; pointing it at itself would recurse
  name     = "${var.state_bucket_name}-access-logs"
  project  = var.project_id
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # Live objects: keep 90 days.
  lifecycle_rule {
    condition {
      age        = 90
      with_state = "LIVE"
    }
    action {
      type = "Delete"
    }
  }

  # ⚠️ With versioning on, deleting an object only makes it noncurrent — it
  # stays and it is still billed. Without this rule the cleanup above would
  # reclaim nothing.
  lifecycle_rule {
    condition {
      with_state                 = "ARCHIVED"
      days_since_noncurrent_time = 7
    }
    action {
      type = "Delete"
    }
  }
}