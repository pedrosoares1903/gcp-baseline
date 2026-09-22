locals {
  prefix = "${var.environment}-baseline"

  # Google's IAP TCP forwarding range. Fixed and documented; every SSH session
  # to an instance without a public IP arrives from here.
  iap_range = "35.235.240.0/20"

  # private.googleapis.com — lets instances reach Google APIs without leaving
  # the private network, which is what makes the egress deny below survivable.
  google_apis_range = "199.36.153.8/30"
}

resource "google_compute_network" "this" {
  project = var.project_id
  name    = "${local.prefix}-vpc"

  # Custom mode. An auto-mode network creates a subnet in every region and
  # arrives with firewall rules that allow SSH and RDP from the whole internet.
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  for_each = var.subnets

  project       = var.project_id
  name          = "${local.prefix}-${each.key}"
  network       = google_compute_network.this.id
  region        = var.region
  ip_cidr_range = each.value.cidr

  # Required for instances without a public IP to reach Google APIs.
  private_ip_google_access = true

  # A nested block that has to exist zero or one times cannot be written with
  # an `if`. `dynamic` produces the block once per element of for_each — so an
  # empty list means no block at all.
  dynamic "log_config" {
    for_each = each.value.flow_logs ? [1] : []

    content {
      aggregation_interval = "INTERVAL_10_MIN"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# ---------------------------------------------------------------------------
# Ingress. There is no 0.0.0.0/0 anywhere in this repository, and the security
# scan in the pipeline exists to keep it that way.
# ---------------------------------------------------------------------------

resource "google_compute_firewall" "allow_ssh_from_iap" {
  project     = var.project_id
  name        = "${local.prefix}-allow-ssh-from-iap"
  network     = google_compute_network.this.name
  description = "SSH arrives through IAP, which authenticates the person first."
  direction   = "INGRESS"
  priority    = 1000

  source_ranges = [local.iap_range]
  target_tags   = ["ssh-via-iap"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Logging is off by default on every firewall rule in GCP, and it is not
  # retroactive: a rule without it leaves no record of who connected.
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "internal" {
  project     = var.project_id
  name        = "${local.prefix}-allow-internal"
  network     = google_compute_network.this.name
  description = "Instances inside the VPC can reach each other."
  direction   = "INGRESS"
  priority    = 1100

  source_ranges = var.internal_cidrs

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }
}

# ---------------------------------------------------------------------------
# Egress. GCP allows all outbound traffic by default; these two rules replace
# that with an explicit allow-list.
# ---------------------------------------------------------------------------

resource "google_compute_firewall" "allow_egress_google_apis" {
  project     = var.project_id
  name        = "${local.prefix}-allow-egress-google-apis"
  network     = google_compute_network.this.name
  description = "Reaching Google APIs privately. Higher priority than the deny below."
  direction   = "EGRESS"
  priority    = 1000

  destination_ranges = [local.google_apis_range]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "deny_egress" {
  project     = var.project_id
  name        = "${local.prefix}-deny-all-egress"
  network     = google_compute_network.this.name
  description = "Everything not explicitly allowed above is refused on the way out."
  direction   = "EGRESS"

  # A high number is a LOW priority: this is evaluated after every allow rule.
  priority = 65000

  destination_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# ---------------------------------------------------------------------------
# Outbound internet, behind a switch. Billed per hour with no free allowance.
# ---------------------------------------------------------------------------

resource "google_compute_router" "nat" {
  count = var.enable_nat ? 1 : 0

  project = var.project_id
  name    = "${local.prefix}-router"
  network = google_compute_network.this.id
  region  = var.region
}

resource "google_compute_router_nat" "this" {
  count = var.enable_nat ? 1 : 0

  project = var.project_id
  name    = "${local.prefix}-nat"

  # `count` turns the address into a list, so the router is index 0.
  router = google_compute_router.nat[0].name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}


moved {
  from = google_compute_firewall.allow_internal
  to   = google_compute_firewall.internal
}