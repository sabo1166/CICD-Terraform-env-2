terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Deliberately local state: this root creates the remote-state bucket, so it
  # cannot store its own state there (circular dependency). It is small, run
  # rarely, and rebuildable with `terraform import` if the local file is lost.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      Component = "bootstrap"
      ManagedBy = "terraform"
    }
  }
}
