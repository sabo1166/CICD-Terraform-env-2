variable "aws_region" {
  description = "Region for the state bucket and where the deploy roles may operate."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Must match project_name in environments/*; IAM permissions are scoped to this prefix."
  type        = string
  default     = "foundation"
}

variable "github_owner" {
  description = "GitHub user/org that owns the repository allowed to assume the roles."
  type        = string
  default     = "sabo1166"
}

variable "github_repo" {
  description = "GitHub repository (name only) allowed to assume the roles."
  type        = string
  default     = "CICD-terraform-project-2-env"
}

variable "environments" {
  description = "Environments that get their own deploy role and state prefix."
  type        = set(string)
  default     = ["dev", "prod"]
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. An account can only have one; set false if it already exists."
  type        = bool
  default     = true
}
