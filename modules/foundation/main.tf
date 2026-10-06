# Composition module: one call builds a complete, isolated network foundation.
# Environments differ only in the inputs they pass here, so dev and prod can
# never drift apart in structure.

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# Created here (not in vpc/iam) to break the cycle: the IAM role policy needs
# the log group ARN, and the VPC flow log needs the role ARN.
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/${var.project_name}/${var.environment}/vpc-flow-logs"
  retention_in_days = var.flow_log_retention_days
}

module "iam" {
  source = "../iam"

  name_prefix        = local.name_prefix
  flow_log_group_arn = aws_cloudwatch_log_group.flow_logs.arn
}

module "vpc" {
  source = "../vpc"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  nat_gateway_mode   = var.nat_gateway_mode
  flow_log_group_arn = aws_cloudwatch_log_group.flow_logs.arn
  flow_log_role_arn  = module.iam.flow_log_role_arn
}

module "security_groups" {
  source = "../security-groups"

  name_prefix              = local.name_prefix
  vpc_id                   = module.vpc.vpc_id
  app_port                 = var.app_port
  db_port                  = var.db_port
  web_ingress_cidrs        = var.web_ingress_cidrs
  allow_public_web_ingress = var.allow_public_web_ingress
}
