# Plan-only tests against a mocked provider: no AWS credentials or cost.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }
}

variables {
  name_prefix        = "test"
  vpc_cidr           = "10.0.0.0/16"
  flow_log_group_arn = "arn:aws:logs:us-east-1:123456789012:log-group:/test"
  flow_log_role_arn  = "arn:aws:iam::123456789012:role/test"
}

run "single_nat_two_azs" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.app) == 2 && length(aws_subnet.db) == 2
    error_message = "Expected 2 subnets per tier."
  }
  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single mode must create exactly one NAT Gateway."
  }
  assert {
    condition     = aws_subnet.public[0].cidr_block == "10.0.0.0/24" && aws_subnet.app[0].cidr_block == "10.0.10.0/24" && aws_subnet.db[0].cidr_block == "10.0.20.0/24"
    error_message = "Subnet CIDR layout changed."
  }
  assert {
    condition     = aws_subnet.public[0].map_public_ip_on_launch == false
    error_message = "Public subnets must not auto-assign public IPs."
  }
}

run "nat_per_az" {
  command = plan

  variables {
    nat_gateway_mode = "per_az"
    az_count         = 3
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 3
    error_message = "per_az mode must create one NAT Gateway per AZ."
  }
}

run "rejects_bad_nat_mode" {
  command = plan

  variables {
    nat_gateway_mode = "none"
  }

  expect_failures = [var.nat_gateway_mode]
}

run "rejects_single_az" {
  command = plan

  variables {
    az_count = 1
  }

  expect_failures = [var.az_count]
}

run "rejects_bad_cidr" {
  command = plan

  variables {
    vpc_cidr = "not-a-cidr"
  }

  expect_failures = [var.vpc_cidr]
}
