variable "aws_region" {
  description = "Region for the state bucket."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix of the state bucket name: <project_name>-tfstate-<account-id>. The workflow's TF_STATE_BUCKET must match."
  type        = string
  default     = "foundation"
}
