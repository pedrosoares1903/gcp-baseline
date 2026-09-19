variable "project_id" {
  description = "Project this environment is created in."
  type        = string
}

variable "region" {
  description = "Region for regional resources."
  type        = string
  default     = "europe-west1"
}