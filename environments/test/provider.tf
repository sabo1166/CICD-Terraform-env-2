terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # bucket/key/region supplied at init time via -backend-config
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}
