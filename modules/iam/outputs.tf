output "flow_log_role_arn" {
  description = "ARN of the VPC flow logs delivery role."
  value       = aws_iam_role.flow_logs.arn
}
