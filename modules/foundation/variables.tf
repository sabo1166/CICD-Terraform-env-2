variable "project_name" {
  description = "Short project name used as a resource-name prefix."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project_name))
    error_message = "project_name must be 2-21 chars: lowercase letters, digits, hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name. Becomes part of every resource name and tag."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be \"dev\" or \"prod\"."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR of the environment's VPC. Must not overlap other environments."
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones (2 or 3)."
  type        = number
  default     = 2
}

variable "nat_gateway_mode" {
  description = "\"single\" (cheaper) or \"per_az\" (resilient)."
  type        = string
  default     = "single"
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention for VPC flow logs. Must be a value CloudWatch accepts."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_log_retention_days)
    error_message = "flow_log_retention_days must be a retention value supported by CloudWatch Logs."
  }
}

variable "web_ingress_cidrs" {
  description = "CIDRs allowed to reach the web tier on 443. Empty = no ingress."
  type        = list(string)
  default     = []
}

variable "allow_public_web_ingress" {
  description = "Explicitly allow 0.0.0.0/0 on 443 to the web tier."
  type        = bool
  default     = false
}

variable "app_port" {
  description = "TCP port of the application tier."
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "TCP port of the database tier."
  type        = number
  default     = 5432
}
