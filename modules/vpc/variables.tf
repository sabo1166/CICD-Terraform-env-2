variable "name_prefix" {
  description = "Prefix for resource Name tags, e.g. \"foundation-dev\"."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block of the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 (multi-AZ is the point of this module)."
  }
}

variable "subnet_newbits" {
  description = "Extra prefix bits added to vpc_cidr for every subnet (8 turns a /16 into /24s)."
  type        = number
  default     = 8
}

variable "nat_gateway_mode" {
  description = "\"single\" shares one NAT Gateway (cheap, its AZ is a single point of failure); \"per_az\" creates one per AZ (resilient, roughly 2-3x the cost)."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "per_az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be \"single\" or \"per_az\"."
  }
}

variable "flow_log_group_arn" {
  description = "ARN of the CloudWatch log group that receives VPC flow logs."
  type        = string
}

variable "flow_log_role_arn" {
  description = "ARN of the IAM role that lets VPC flow logs write to flow_log_group_arn."
  type        = string
}

variable "tags" {
  description = "Extra tags applied to every resource in addition to provider default_tags."
  type        = map(string)
  default     = {}
}
