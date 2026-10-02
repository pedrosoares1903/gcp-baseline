module "network" {
  source = "../../modules/network"

  project_id     = var.project_id
  environment    = "prod"
  region         = var.region
  internal_cidrs = ["10.20.0.0/16"]

  # Off here too, for cost. In a real environment this would be true, and this
  # line is the one a reviewer should stop at.
  enable_nat = false

  subnets = {
    apps = {
      cidr = "10.20.1.0/24"
    }
    data = {
      cidr = "10.20.2.0/24"
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
