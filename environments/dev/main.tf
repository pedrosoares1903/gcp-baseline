# Everything this environment is, in one call. The infrastructure itself lives
# in modules/network and is shared with prod.
module "network" {
  source = "../../modules/network"

  project_id     = var.project_id
  environment    = "dev"
  region         = var.region
  internal_cidrs = ["10.10.0.0/16"]

  # Off. Turning this on starts an hourly charge with no free allowance.
  enable_nat = false

  subnets = {
    apps = {
      cidr = "10.10.1.0/24"
    }
    data = {
      cidr = "10.10.2.0/24"
      # Nothing runs here yet, so there is nothing to log.
      flow_logs = false
    }
  }
}

output "network_name" {
  value = module.network.network_name
}

output "subnet_cidrs" {
  value = module.network.subnet_cidrs
}

output "nat_enabled" {
  value = module.network.nat_enabled
}
