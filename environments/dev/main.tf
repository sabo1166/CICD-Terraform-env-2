module "foundation" {
  source = "../../modules/foundation"

  project_name = var.project_name
  environment  = "dev"

  # Different CIDR from prod so the two networks are distinct and could be
  # peered later without renumbering.
  vpc_cidr = "10.0.0.0/16"

  # Cost: one shared NAT Gateway; losing its AZ only affects a dev workload.
  nat_gateway_mode        = "single"
  flow_log_retention_days = 14

  web_ingress_cidrs = var.web_ingress_cidrs
}
