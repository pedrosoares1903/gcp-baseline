variable "project_id" {
  description = "Project the network is created in."
  type        = string
}

variable "environment" {
  description = "Short environment name. Becomes the prefix of every resource name."
  type        = string
}

variable "region" {
  description = "Region for the subnets and, if enabled, the NAT gateway."
  type        = string
}

variable "subnets" {
  description = <<-EOT
    Subnets to create, keyed by name.

    The key becomes part of the Terraform address, so renaming a key destroys
    and recreates the subnet. Add and remove freely; rename with a `moved` block.
  EOT
  type = map(object({
    cidr      = string
    flow_logs = optional(bool, true)
  }))
}

variable "internal_cidrs" {
  description = "Ranges allowed to reach each other inside the VPC."
  type        = list(string)
}

variable "enable_nat" {
  description = <<-EOT
    Whether instances without a public IP can reach the internet.

    Cloud NAT is billed per hour and per GiB with no free allowance, so this
    defaults to off. Turn it on for as long as a lab needs it, then turn it off.
  EOT
  type        = bool
  default     = false
}
