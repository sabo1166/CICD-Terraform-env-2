output "state_bucket_name" {
  description = "Name of the Terraform remote-state bucket (must equal TF_STATE_BUCKET in .github/workflows/terraform-env.yml)."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the state bucket, for the GitHub-OIDC role's permission policy."
  value       = aws_s3_bucket.state.arn
}
