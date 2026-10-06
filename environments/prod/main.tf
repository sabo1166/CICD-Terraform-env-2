module "foundation" {
  source = "../../modules/foundation"

  project_name = var.project_name
  environment  = "prod"

  vpc_cidr = "10.1.0.0/16"

  # Resilience: one NAT Gateway per AZ so an AZ outage does not cut off egress
  # for the other AZ. Roughly doubles NAT cost versus dev.
  nat_gateway_mode        = "per_az"
  flow_log_retention_days = 90

  web_ingress_cidrs = var.web_ingress_cidrs
}
