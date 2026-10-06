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
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  # The IAM policy document data source must return valid JSON under the mock.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  project_name = "foundation"
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"
}

run "dev_shape" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.flow_logs.name == "/foundation/dev/vpc-flow-logs"
    error_message = "Flow log group name must embed project and environment."
  }
  assert {
    condition     = length(module.vpc.nat_gateway_ids) == 1
    error_message = "Default NAT mode should be a single gateway."
  }
}

run "prod_ha_nat" {
  command = plan

  variables {
    environment      = "prod"
    vpc_cidr         = "10.1.0.0/16"
    nat_gateway_mode = "per_az"
  }

  assert {
    condition     = length(module.vpc.nat_gateway_ids) == 2
    error_message = "per_az with 2 AZs must create 2 NAT Gateways."
  }
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "staging"
  }

  expect_failures = [var.environment]
}
