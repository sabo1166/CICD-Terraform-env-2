variable "name_prefix" {
  description = "Prefix for security group names, e.g. \"foundation-dev\"."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the security groups belong to."
  type        = string
}

variable "app_port" {
  description = "TCP port the application tier listens on."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port >= 1 && var.app_port <= 65535
    error_message = "app_port must be a valid TCP port."
  }
}

variable "db_port" {
  description = "TCP port the database tier listens on (5432 PostgreSQL, 3306 MySQL)."
  type        = number
  default     = 5432

  validation {
    condition     = var.db_port >= 1 && var.db_port <= 65535
    error_message = "db_port must be a valid TCP port."
  }
}

variable "web_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the web tier on 443. Empty by default: nothing is exposed until you say so."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.web_ingress_cidrs : can(cidrhost(c, 0))])
    error_message = "Every web_ingress_cidrs entry must be a valid CIDR block."
  }

  validation {
    condition     = !contains(var.web_ingress_cidrs, "0.0.0.0/0")
    error_message = "Use allow_public_web_ingress = true to open the web tier to the internet; 0.0.0.0/0 must be an explicit decision."
  }
}

variable "allow_public_web_ingress" {
  description = "Explicit opt-in to allow 0.0.0.0/0 on port 443 to the web tier."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}
