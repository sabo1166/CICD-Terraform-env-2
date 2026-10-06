# claude-code-terraform

Terraform project with two isolated environments and a GitHub Actions CI/CD pipeline.

## Layout

- `modules/vpc` – VPC, public subnet, internet gateway, route table
- `modules/ec2` – EC2 instance (Amazon Linux 2023) with an egress-only security group
- `environments/dev` – dev environment, `us-east-1`
- `environments/test` – test environment, `eu-west-1`
- `.github/workflows/terraform.yml` – matrix over dev/test: fmt/validate/plan on PRs and pushes, apply on push to `main`

Each environment has its own provider region and its own state file (`<env>/terraform.tfstate`) in a shared S3 state bucket.

## Setup

GitHub repo variables:

- `TF_STATE_BUCKET` – existing S3 bucket for Terraform state

The workflow authenticates with the repo secrets `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
The IAM user needs access to the state bucket and EC2/VPC permissions in both regions.

Local use:

```sh
cd environments/dev
terraform init -backend-config="bucket=<state-bucket>" -backend-config="key=dev/terraform.tfstate" -backend-config="region=us-east-1"
terraform plan
```
