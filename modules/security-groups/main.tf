# Three tiers, each reachable only from the tier in front of it:
#   internet -> web (443) -> app (app_port) -> db (db_port)
# Rules reference security groups rather than CIDRs so they survive subnet changes.

resource "aws_security_group" "web" {
  name        = "${var.name_prefix}-web"
  description = "Web tier: HTTPS in from approved sources"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-web", Tier = "web" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app"
  description = "App tier: traffic from the web tier only"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-app", Tier = "app" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db"
  description = "DB tier: traffic from the app tier only, no egress"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-db", Tier = "db" })

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------- web

resource "aws_vpc_security_group_ingress_rule" "web_https_cidr" {
  for_each = toset(var.web_ingress_cidrs)

  security_group_id = aws_security_group.web.id
  description       = "HTTPS from approved CIDR"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "web_https_public" {
  count = var.allow_public_web_ingress ? 1 : 0

  security_group_id = aws_security_group.web.id
  description       = "HTTPS from the internet (explicit opt-in)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "web_to_app" {
  security_group_id            = aws_security_group.web.id
  description                  = "Forward to app tier"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

# ------------------------------------------------------------------- app

resource "aws_vpc_security_group_ingress_rule" "app_from_web" {
  security_group_id            = aws_security_group.app.id
  description                  = "From web tier"
  referenced_security_group_id = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "To database tier"
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
}

# Why 0.0.0.0/0 here: the destinations (OS mirrors, AWS APIs) have no stable
# CIDRs. It is limited to 443 and leaves through the NAT Gateway only; there is
# no inbound path. Replace with VPC endpoints + prefix lists to tighten further.
resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to internet via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# -------------------------------------------------------------------- db

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "From app tier"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
}
