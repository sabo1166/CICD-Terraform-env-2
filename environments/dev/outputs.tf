output "vpc_id" {
  description = "ID of the dev VPC."
  value       = module.foundation.vpc_id
}

output "vpc_cidr" {
  description = "CIDR of the dev VPC."
  value       = module.foundation.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.foundation.public_subnet_ids
}

output "app_subnet_ids" {
  description = "Private application subnet IDs."
  value       = module.foundation.app_subnet_ids
}

output "db_subnet_ids" {
  description = "Private database subnet IDs."
  value       = module.foundation.db_subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs."
  value       = module.foundation.nat_gateway_ids
}

output "nat_public_ips" {
  description = "NAT Gateway public IPs."
  value       = module.foundation.nat_public_ips
}

output "web_security_group_id" {
  description = "Web tier security group ID."
  value       = module.foundation.web_security_group_id
}

output "app_security_group_id" {
  description = "App tier security group ID."
  value       = module.foundation.app_security_group_id
}

output "db_security_group_id" {
  description = "DB tier security group ID."
  value       = module.foundation.db_security_group_id
}

output "flow_log_group_name" {
  description = "CloudWatch log group holding VPC flow logs."
  value       = module.foundation.flow_log_group_name
}
