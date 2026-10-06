variable "name_prefix" {
  description = "Prefix for IAM resource names, e.g. \"foundation-dev\"."
  type        = string
}

variable "flow_log_group_arn" {
  description = "ARN of the CloudWatch log group the flow-log role may write to."
  type        = string
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}
