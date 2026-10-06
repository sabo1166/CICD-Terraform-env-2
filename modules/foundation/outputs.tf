output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr
}

output "availability_zones" {
  description = "Availability Zones in use."
  value       = module.vpc.availability_zones
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "app_subnet_ids" {
  description = "Private application subnet IDs."
  value       = module.vpc.app_subnet_ids
}

output "db_subnet_ids" {
  description = "Private database subnet IDs."
  value       = module.vpc.db_subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs."
  value       = module.vpc.nat_gateway_ids
}

output "nat_public_ips" {
  description = "NAT Gateway public IPs."
  value       = module.vpc.nat_public_ips
}

output "web_security_group_id" {
  description = "Web tier security group ID."
  value       = module.security_groups.web_security_group_id
}

output "app_security_group_id" {
  description = "App tier security group ID."
  value       = module.security_groups.app_security_group_id
}

output "db_security_group_id" {
  description = "DB tier security group ID."
  value       = module.security_groups.db_security_group_id
}

output "flow_log_group_name" {
  description = "CloudWatch log group holding VPC flow logs."
  value       = aws_cloudwatch_log_group.flow_logs.name
}
