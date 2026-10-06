mock_provider "aws" {}

variables {
  name_prefix = "test"
  vpc_id      = "vpc-12345678"
}

run "closed_by_default" {
  command = plan

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.web_https_cidr) == 0 && length(aws_vpc_security_group_ingress_rule.web_https_public) == 0
    error_message = "Web tier must have no ingress unless configured."
  }
}

run "restricted_cidr" {
  command = plan

  variables {
    web_ingress_cidrs = ["203.0.113.0/24"]
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.web_https_cidr) == 1
    error_message = "Expected one CIDR ingress rule."
  }
}

run "world_cidr_rejected_in_list" {
  command = plan

  variables {
    web_ingress_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.web_ingress_cidrs]
}

run "explicit_public_optin" {
  command = plan

  variables {
    allow_public_web_ingress = true
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.web_https_public) == 1
    error_message = "Opt-in should create the public 443 rule."
  }
}
