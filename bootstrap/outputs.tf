output "state_bucket_name" {
  description = "Name of the Terraform remote-state bucket (GitHub variable TF_STATE_BUCKET)."
  value       = aws_s3_bucket.state.id
}

output "plan_role_arn" {
  description = "Read-only plan role (GitHub repository variable AWS_PLAN_ROLE_ARN)."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arns" {
  description = "Per-environment apply roles (GitHub environment variable AWS_APPLY_ROLE_ARN in each environment)."
  value       = { for env, role in aws_iam_role.apply : env => role.arn }
}

output "aws_region" {
  description = "Region (GitHub repository variable AWS_REGION)."
  value       = var.aws_region
}
