variable "aws_region" {
  description = "AWS region for this environment."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Resource-name prefix shared by all environments."
  type        = string
  default     = "foundation"
}

variable "web_ingress_cidrs" {
  description = "CIDRs allowed to reach the web tier on 443 (empty = none)."
  type        = list(string)
  default     = []
}
