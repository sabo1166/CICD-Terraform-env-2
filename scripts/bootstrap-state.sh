#!/usr/bin/env bash
# Creates the Terraform state bucket and the GitHub OIDC roles (see bootstrap/).
# Run once per AWS account, with credentials that can create S3 buckets and IAM
# roles. Safe to re-run: Terraform only changes what drifted.
#
# Usage: scripts/bootstrap-state.sh [extra terraform args, e.g. -var=create_oidc_provider=false]
set -euo pipefail

cd "$(dirname "$0")/../bootstrap"

echo "Calling identity:"
aws sts get-caller-identity --query '[Account,Arn]' --output text

read -r -p "Create/update bootstrap resources in this account? [y/N] " answer
[[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Aborted."; exit 1; }

terraform init -input=false
terraform apply -input=false "$@"

echo
echo "Configure GitHub with these values (Settings > Secrets and variables > Actions > Variables):"
terraform output
