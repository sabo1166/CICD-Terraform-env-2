#!/usr/bin/env bash
# Creates the Terraform state bucket (see bootstrap/). It does NOT create any
# OIDC provider or IAM role: the GitHub-OIDC role already exists and is managed
# outside this repository.
#
# Run once per AWS account with credentials that can create S3 buckets.
# Safe to re-run: Terraform only changes what drifted.
set -euo pipefail

cd "$(dirname "$0")/../bootstrap"

echo "Calling identity:"
aws sts get-caller-identity --query '[Account,Arn]' --output text

read -r -p "Create/update the state bucket in this account? [y/N] " answer
[[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Aborted."; exit 1; }

terraform init -input=false
terraform apply -input=false "$@"

echo
echo "State bucket (must match TF_STATE_BUCKET in .github/workflows/terraform-env.yml):"
terraform output -raw state_bucket_name
echo
